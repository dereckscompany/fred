# File: R/FredSeries.R
# The FRED / ALFRED client. FRED is a single-host API with one small family of
# read endpoints, so a single R6 class -- inheriting the generic transport
# (sync/async funnel, retry, throttle) from connectcore::RestClient and plugging
# in the two FRED-specific seams (query-parameter key signing, JSON error
# envelope) -- covers the whole surface. There is no separate abstract base: with
# one concrete class, a base would be an empty abstraction.

#' FredSeries: the FRED / ALFRED economic-data client
#'
#' @description
#' Retrieves St. Louis Fed economic data: series observations at any real-time
#' window ([get_series][FredSeries]), the ALFRED as-known-then vintage history
#' ([get_series_vintages][FredSeries]), series metadata
#' ([get_series_info][FredSeries]), full-text search
#' ([search_series][FredSeries]), and the release calendar
#' ([get_releases][FredSeries] / [get_release_dates][FredSeries]). Every method
#' returns a tidy [data.table::data.table].
#'
#' @details
#' Inherits the transport plumbing (the single sync/async request funnel, retry,
#' throttle) from [connectcore::RestClient] and customises only the two seams
#' specific to FRED:
#' - `.sign()` — FRED authentication is a single query-parameter `api_key`, so this
#'   appends `&api_key=<FRED_API_KEY>&file_type=json` to every request (there is no
#'   HMAC or JWT).
#' - `.parse_envelope()` — FRED answers every failure with a real non-2xx HTTP
#'   status and a JSON `{error_code, error_message}` body, which this raises as a
#'   typed [fred_conditions] error.
#'
#' ### Vintages vs latest — the revision trap
#' FRED and ALFRED are the same host, split only by the `realtime_start` /
#' `realtime_end` window and the `output_type`. The **latest** value of an
#' observation is simply the value at today's real-time window; it is not a
#' separate endpoint or code path. `get_series()` exposes the window directly:
#' omit it for the latest values, or pass a past `realtime_start` to see what was
#' known *then*. `get_series_vintages()` returns the whole as-known-then matrix
#' (every value of every observation as it stood in each real-time window) — the
#' honest surface for a point-in-time backtest. See `get_series_vintages()` for why
#' this matters.
#'
#' ### Sync vs async
#' The `async` argument selects the execution mode for every method:
#' - `async = FALSE` (default): methods return a [data.table::data.table].
#' - `async = TRUE`: methods return a [promises::promise] that resolves to the same
#'   `data.table`.
#'
#' The mode is stored once as `private$.is_async` and threaded through every
#' method's `connectcore::then_or_now()` tail (and through the vintage pager);
#' nothing hardcodes it. Consume promises with [coro::async()] and `await()`;
#' drive the loop in a script with `while (!later::loop_empty()) later::run_now()`.
#'
#' ### The API key
#' Every FRED endpoint requires a key (unlike some connectors, there is no keyless
#' surface). The key is read from `FRED_API_KEY` (the `api_key` argument
#' overrides). An empty key **warns** at construction rather than aborting; a
#' request with an empty or invalid key aborts with a typed [fred_conditions] error
#' at request time.
#'
#' @examples
#' \dontrun{
#' fred <- FredSeries$new()
#'
#' # Latest values (today's real-time window):
#' tips <- fred$get_series("DFII10")
#'
#' # As-known-then vintages of a heavily-revised series:
#' m2 <- fred$get_series_vintages("M2SL")
#'
#' # Metadata and search:
#' info <- fred$get_series_info("UNRATE")
#' hits <- fred$search_series("real gross domestic product")
#'
#' # Asynchronous:
#' fred_async <- FredSeries$new(async = TRUE)
#' main <- coro::async(function() {
#'   nfci <- await(fred_async$get_series("NFCI"))
#'   print(nfci)
#' })
#' main()
#' while (!later::loop_empty()) later::run_now()
#' }
#'
#' @import data.table
#' @importFrom R6 R6Class
#' @importFrom rlang warn
#' @export
FredSeries <- R6::R6Class(
  "FredSeries",
  inherit = connectcore::RestClient,
  public = list(
    #' @description Initialise a FredSeries client.
    #' @param api_key (scalar<character>) the FRED API key. Defaults to the
    #'   `FRED_API_KEY` environment variable (empty when unset).
    #' @param base_url (scalar<character>) the FRED API base URL. Defaults to
    #'   [fred_base_url()].
    #' @param async (scalar<logical>) if `TRUE`, methods return promises. Default
    #'   `FALSE`.
    #' @param max_tries (scalar<count in [1, Inf[>) retry an idempotent GET up to
    #'   this many times on a transient failure (408, 429, any 5xx, or a connection
    #'   failure). FRED reads are all GETs, so retry is always safe. Default `3`.
    #' @param throttle_rate (scalar<numeric in ]0, Inf[> | NULL) client-side rate
    #'   cap in requests/second. FRED's budget is 120/minute (2/second); pass `2`
    #'   to stay under it during rapid loops. Default `NULL` (no throttle).
    #' @return (class<FredSeries>) invisibly, self.
    initialize = function(
      api_key = fred_api_key(),
      base_url = fred_base_url(),
      async = FALSE,
      max_tries = 3L,
      throttle_rate = NULL
    ) {
      assert_args_FredSeries__initialize(api_key, base_url, async, max_tries, throttle_rate)
      if (!nzchar(api_key)) {
        rlang::warn(paste0(
          "FRED_API_KEY is empty. Every FRED endpoint requires a key; requests will abort with a ",
          "fred_api_error until a valid key is set. Get a free key at ",
          "https://fred.stlouisfed.org/docs/api/api_key.html."
        ))
      }
      super$initialize(
        keys = list(api_key = api_key),
        base_url = base_url,
        async = async,
        body_format = "none",
        user_agent = "dereckscompany/fred",
        max_tries = max_tries,
        throttle_rate = throttle_rate
      )
      return(invisible(assert_return_FredSeries__initialize(self)))
    },

    #' @description Retrieve a series' observations at a real-time window. Omit the
    #'   real-time window for the **latest** values (today's window); pass a past
    #'   `realtime_start` (and matching `realtime_end`) for the values as they were
    #'   known then. This is a single request: a single real-time window rarely
    #'   exceeds FRED's 100,000-row response cap, but if it does, page with
    #'   `limit` / `offset`. For the full as-known-then matrix across every
    #'   real-time window, use `get_series_vintages()`.
    #' @param series_id (scalar<character>) the FRED series id, e.g. `"DFII10"`.
    #' @param observation_start (scalar<character> | NULL) earliest observation date
    #'   to return, ISO `"YYYY-MM-DD"`. `NULL` uses FRED's floor. Default `NULL`.
    #' @param observation_end (scalar<character> | NULL) latest observation date,
    #'   ISO `"YYYY-MM-DD"`. `NULL` uses FRED's ceiling. Default `NULL`.
    #' @param realtime_start (scalar<character> | NULL) start of the real-time
    #'   period (the as-of window), ISO `"YYYY-MM-DD"`. `NULL` is today (the latest
    #'   values). Default `NULL`.
    #' @param realtime_end (scalar<character> | NULL) end of the real-time period,
    #'   ISO `"YYYY-MM-DD"`. `NULL` is today. Default `NULL`.
    #' @param units (scalar<character> | NULL) a server-side value transform
    #'   (`"lin"`, `"chg"`, `"pch"`, `"pc1"`, `"log"`, ...). `NULL` is levels
    #'   (`"lin"`). Default `NULL`.
    #' @param frequency (scalar<character> | NULL) a server-side frequency
    #'   aggregation (`"d"`, `"w"`, `"m"`, `"q"`, `"a"`, ...). `NULL` is the series'
    #'   native frequency. Default `NULL`.
    #' @param aggregation_method (scalar<character> | NULL) how to aggregate when
    #'   `frequency` is coarser than native (`"avg"`, `"sum"`, `"eop"`). Default
    #'   `NULL`.
    #' @param sort_order (scalar<character in c("asc", "desc")>) observation date
    #'   order. Default `"asc"`.
    #' @param limit (scalar<count in [1, Inf[> | NULL) maximum rows (FRED caps a
    #'   single response at 100,000). `NULL` uses FRED's default. Default `NULL`.
    #' @param offset (scalar<count in [0, Inf[> | NULL) row offset for paging.
    #'   Default `NULL`.
    #' @return (FredObservations | promise<FredObservations>) the observations, or a
    #'   promise thereof.
    get_series = function(
      series_id,
      observation_start = NULL,
      observation_end = NULL,
      realtime_start = NULL,
      realtime_end = NULL,
      units = NULL,
      frequency = NULL,
      aggregation_method = NULL,
      sort_order = SORT_ORDER$asc,
      limit = NULL,
      offset = NULL
    ) {
      assert_args_FredSeries__get_series(
        series_id,
        observation_start,
        observation_end,
        realtime_start,
        realtime_end,
        units,
        frequency,
        aggregation_method,
        sort_order,
        limit,
        offset
      )
      private$.require_series_id(series_id)
      res <- private$.request(
        endpoint = "/fred/series/observations",
        query = list(
          series_id = series_id,
          observation_start = observation_start,
          observation_end = observation_end,
          realtime_start = realtime_start,
          realtime_end = realtime_end,
          units = units,
          frequency = frequency,
          aggregation_method = aggregation_method,
          sort_order = sort_order,
          limit = limit,
          offset = offset
        ),
        auth = TRUE,
        .parser = function(body) parse_fred_observations(body, series_id)
      )
      return(connectcore::then_or_now(res, assert_return_FredSeries__get_series, is_async = private$.is_async))
    },

    #' @description Retrieve a series' ALFRED as-known-then vintage history — the
    #'   headline surface.
    #' @details
    #' FRED serves the **latest revised** value of every observation. Most macro
    #' series are revised after first release — money supply, unemployment, and
    #' jobless claims restate their history when seasonal factors or population
    #' controls are re-estimated; a financial-conditions index revises its *entire*
    #' history every week. So the history FRED shows today is not the history anyone
    #' had in the past: it embeds numbers that did not exist then. Backtesting a
    #' strategy on it is look-ahead by construction — the model "knows" revisions
    #' that had not happened.
    #'
    #' ALFRED (ArchivaL FRED) fixes this. This method requests the `output_type = 1`
    #' as-known-then **long form** over the whole real-time window: one row per
    #' (observation date, contiguous real-time window), each carrying the value that
    #' was current during that window. A row whose `realtime_end` is the
    #' [FRED_REALTIME_MAX] sentinel (`"9999-12-31"`) is still current. To reconstruct
    #' what was knowable on a given date `d`, keep the row for each observation whose
    #' `[realtime_start, realtime_end]` window contains `d`.
    #'
    #' The whole-history matrix of a heavily-revised series exceeds FRED's
    #' 100,000-row response cap, so it is pulled in disjoint offset pages that stitch
    #' back to the un-paged whole with no seam clip, skip, or duplicate (the logic is
    #' proven live — see the seam-stitching test). The pages are streamed internally
    #' and returned as one table; the request runs with a generous timeout because
    #' the first page of a deeply-revised series makes FRED build the whole matrix
    #' server-side.
    #' @param series_id (scalar<character>) the FRED series id, e.g. `"NFCI"`.
    #' @param realtime_start (scalar<character>) start of the vintage window, ISO
    #'   `"YYYY-MM-DD"`. Default [FRED_REALTIME_MIN] (every vintage from the start).
    #' @param realtime_end (scalar<character>) end of the vintage window, ISO
    #'   `"YYYY-MM-DD"`. Default [FRED_REALTIME_MAX] (through the latest vintage).
    #' @param page_limit (scalar<count in [1, Inf[>) rows per offset page. Default
    #'   [FRED_MAX_ROWS_PER_PAGE] (FRED's per-response maximum).
    #' @return (FredVintages | promise<FredVintages>) the as-known-then long form, or
    #'   a promise thereof.
    get_series_vintages = function(
      series_id,
      realtime_start = FRED_REALTIME_MIN,
      realtime_end = FRED_REALTIME_MAX,
      page_limit = FRED_MAX_ROWS_PER_PAGE
    ) {
      assert_args_FredSeries__get_series_vintages(series_id, realtime_start, realtime_end, page_limit)
      private$.require_series_id(series_id)
      private$.require_realtime_order(realtime_start, realtime_end)
      limit <- as.integer(page_limit)
      # One offset page of the output_type=1 vintage long form. sort_order is pinned
      # to asc so the total row order is deterministic and the disjoint offset pages
      # stitch back to the one-giant-pull matrix (see fred_stream_pages). The 90s
      # timeout is generous: the first page of a deeply-revised series makes FRED
      # build the whole as-known-then matrix server-side (~30s cold).
      fetch_page <- function(offset) {
        return(private$.request(
          endpoint = "/fred/series/observations",
          query = list(
            series_id = series_id,
            realtime_start = realtime_start,
            realtime_end = realtime_end,
            output_type = FRED_OUTPUT_TYPE$by_realtime_period,
            sort_order = SORT_ORDER$asc,
            limit = limit,
            offset = offset
          ),
          auth = TRUE,
          timeout = 90,
          .parser = function(body) parse_fred_observations(body, series_id)
        ))
      }
      acc <- new.env(parent = emptyenv())
      acc$pages <- list()
      sink_fn <- function(page) {
        acc$pages[[length(acc$pages) + 1L]] <- page
        return(invisible(NULL))
      }
      streamed <- fred_stream_pages(fetch_page, limit, sink_fn, is_async = private$.is_async)
      finalize <- function(.) {
        combined <- empty_dt_fred_vintages()
        if (length(acc$pages) > 0L) {
          combined <- data.table::rbindlist(acc$pages)
        }
        return(assert_return_FredSeries__get_series_vintages(combined))
      }
      return(connectcore::then_or_now(streamed, finalize, is_async = private$.is_async))
    },

    #' @description Retrieve a series' metadata (title, frequency, units, seasonal
    #'   adjustment, observation span, last-updated timestamp, popularity, and the
    #'   free-text notes that often describe the revision cadence).
    #' @param series_id (scalar<character>) the FRED series id, e.g. `"UNRATE"`.
    #' @param realtime_start (scalar<character> | NULL) start of the real-time
    #'   period, ISO `"YYYY-MM-DD"`. `NULL` is today. Default `NULL`.
    #' @param realtime_end (scalar<character> | NULL) end of the real-time period,
    #'   ISO `"YYYY-MM-DD"`. `NULL` is today. Default `NULL`.
    #' @return (FredSeriesInfo | promise<FredSeriesInfo>) the one-row metadata, or a
    #'   promise thereof.
    get_series_info = function(series_id, realtime_start = NULL, realtime_end = NULL) {
      assert_args_FredSeries__get_series_info(series_id, realtime_start, realtime_end)
      private$.require_series_id(series_id)
      res <- private$.request(
        endpoint = "/fred/series",
        query = list(
          series_id = series_id,
          realtime_start = realtime_start,
          realtime_end = realtime_end
        ),
        auth = TRUE,
        .parser = parse_fred_series_info
      )
      return(connectcore::then_or_now(res, assert_return_FredSeries__get_series_info, is_async = private$.is_async))
    },

    #' @description Search the FRED series catalogue by full text or series id.
    #' @param search_text (scalar<character>) the query, e.g. `"real gdp"`.
    #' @param search_type (scalar<character>) match the text against series
    #'   attributes (`"full_text"`, ranked by relevance) or against the series id
    #'   only (`"series_id"`), one of `names(SEARCH_TYPE)`. Validated against that
    #'   vocabulary with a typed [fred_conditions] error. Default `"full_text"`.
    #' @param limit (scalar<count in [1, Inf[>) maximum results (FRED caps search at
    #'   1,000). Default `1000`.
    #' @param order_by (scalar<character> | NULL) the result ordering, e.g.
    #'   `"search_rank"`, `"popularity"`, `"last_updated"`. `NULL` uses FRED's
    #'   default. Default `NULL`.
    #' @param sort_order (scalar<character in c("asc", "desc")> | NULL) the sort
    #'   direction. `NULL` uses FRED's default. Default `NULL`.
    #' @param realtime_start (scalar<character> | NULL) start of the real-time
    #'   period, ISO `"YYYY-MM-DD"`. Default `NULL`.
    #' @param realtime_end (scalar<character> | NULL) end of the real-time period,
    #'   ISO `"YYYY-MM-DD"`. Default `NULL`.
    #' @return (FredSeriesInfo | promise<FredSeriesInfo>) one row per matched series,
    #'   or a promise thereof.
    search_series = function(
      search_text,
      search_type = SEARCH_TYPE$full_text,
      limit = 1000L,
      order_by = NULL,
      sort_order = NULL,
      realtime_start = NULL,
      realtime_end = NULL
    ) {
      assert_args_FredSeries__search_series(
        search_text,
        search_type,
        limit,
        order_by,
        sort_order,
        realtime_start,
        realtime_end
      )
      private$.require_search_text(search_text)
      private$.validate_search_type(search_type)
      res <- private$.request(
        endpoint = "/fred/series/search",
        query = list(
          search_text = search_text,
          search_type = search_type,
          limit = limit,
          order_by = order_by,
          sort_order = sort_order,
          realtime_start = realtime_start,
          realtime_end = realtime_end
        ),
        auth = TRUE,
        .parser = parse_fred_series_info
      )
      return(connectcore::then_or_now(res, assert_return_FredSeries__search_series, is_async = private$.is_async))
    },

    #' @description List the FRED releases (the publications series belong to, e.g.
    #'   the H.6 Money Stock release).
    #' @param realtime_start (scalar<character> | NULL) start of the real-time
    #'   period, ISO `"YYYY-MM-DD"`. Default `NULL`.
    #' @param realtime_end (scalar<character> | NULL) end of the real-time period,
    #'   ISO `"YYYY-MM-DD"`. Default `NULL`.
    #' @param limit (scalar<count in [1, Inf[>) maximum releases (FRED caps this at
    #'   1,000). Default `1000`.
    #' @param offset (scalar<count in [0, Inf[> | NULL) row offset for paging.
    #'   Default `NULL`.
    #' @param order_by (scalar<character> | NULL) the ordering, e.g. `"release_id"`,
    #'   `"name"`. `NULL` uses FRED's default. Default `NULL`.
    #' @param sort_order (scalar<character in c("asc", "desc")> | NULL) the sort
    #'   direction. Default `NULL`.
    #' @return (FredReleases | promise<FredReleases>) one row per release, or a
    #'   promise thereof.
    get_releases = function(
      realtime_start = NULL,
      realtime_end = NULL,
      limit = 1000L,
      offset = NULL,
      order_by = NULL,
      sort_order = NULL
    ) {
      assert_args_FredSeries__get_releases(realtime_start, realtime_end, limit, offset, order_by, sort_order)
      res <- private$.request(
        endpoint = "/fred/releases",
        query = list(
          realtime_start = realtime_start,
          realtime_end = realtime_end,
          limit = limit,
          offset = offset,
          order_by = order_by,
          sort_order = sort_order
        ),
        auth = TRUE,
        .parser = parse_fred_releases
      )
      return(connectcore::then_or_now(res, assert_return_FredSeries__get_releases, is_async = private$.is_async))
    },

    #' @description List the publication dates of a single release (its release
    #'   calendar).
    #' @param release_id (scalar<count in [1, Inf[>) the numeric release id (from
    #'   `get_releases()`).
    #' @param realtime_start (scalar<character> | NULL) start of the real-time
    #'   period, ISO `"YYYY-MM-DD"`. `NULL` uses FRED's floor (`"1776-07-04"`).
    #'   Default `NULL`.
    #' @param realtime_end (scalar<character> | NULL) end of the real-time period,
    #'   ISO `"YYYY-MM-DD"`. `NULL` uses FRED's ceiling. Default `NULL`.
    #' @param limit (scalar<count in [1, Inf[> | NULL) maximum dates (FRED caps this
    #'   at 10,000). `NULL` uses FRED's default. Default `NULL`.
    #' @param offset (scalar<count in [0, Inf[> | NULL) row offset for paging.
    #'   Default `NULL`.
    #' @param sort_order (scalar<character in c("asc", "desc")> | NULL) the sort
    #'   direction by date. Default `NULL`.
    #' @param include_empty (scalar<logical>) include release dates with no new data
    #'   (FRED's `include_release_dates_with_no_data`). Default `FALSE`.
    #' @return (FredReleaseDates | promise<FredReleaseDates>) one row per publication
    #'   date, or a promise thereof.
    get_release_dates = function(
      release_id,
      realtime_start = NULL,
      realtime_end = NULL,
      limit = NULL,
      offset = NULL,
      sort_order = NULL,
      include_empty = FALSE
    ) {
      assert_args_FredSeries__get_release_dates(
        release_id,
        realtime_start,
        realtime_end,
        limit,
        offset,
        sort_order,
        include_empty
      )
      res <- private$.request(
        endpoint = "/fred/release/dates",
        query = list(
          release_id = as.integer(release_id),
          realtime_start = realtime_start,
          realtime_end = realtime_end,
          limit = limit,
          offset = offset,
          sort_order = sort_order,
          include_release_dates_with_no_data = tolower(as.character(isTRUE(include_empty)))
        ),
        auth = TRUE,
        .parser = parse_fred_release_dates
      )
      return(connectcore::then_or_now(res, assert_return_FredSeries__get_release_dates, is_async = private$.is_async))
    }
  ),
  private = list(
    # FRED "signing" is appending the api_key + file_type query params; ctx unused.
    .sign = function(req, keys, ctx) {
      return(fred_sign_key(req, keys))
    },
    # FRED's JSON {error_code, error_message} error envelope.
    .parse_envelope = function(resp) {
      return(parse_fred_response(resp))
    },
    # Reject an empty series id before spending a keyed request.
    .require_series_id = function(series_id) {
      if (!nzchar(series_id)) {
        abort_fred_validation_error("`series_id` must be a non-empty FRED series id, e.g. \"DFII10\".")
      }
      return(invisible(series_id))
    },
    .require_search_text = function(search_text) {
      if (!nzchar(search_text)) {
        abort_fred_validation_error("`search_text` must be a non-empty string.")
      }
      return(invisible(search_text))
    },
    .validate_search_type = function(search_type) {
      if (!search_type %in% unlist(SEARCH_TYPE, use.names = FALSE)) {
        abort_fred_validation_error(sprintf(
          "Invalid `search_type` '%s'. Valid: %s.",
          search_type,
          paste(unlist(SEARCH_TYPE, use.names = FALSE), collapse = ", ")
        ))
      }
      return(invisible(search_type))
    },
    # Both bounds are ISO "YYYY-MM-DD" strings, so a lexicographic compare is a date
    # compare; a start after the end would make FRED return an empty matrix silently.
    .require_realtime_order = function(realtime_start, realtime_end) {
      if (realtime_start > realtime_end) {
        abort_fred_validation_error(sprintf(
          "`realtime_start` (%s) must be on or before `realtime_end` (%s).",
          realtime_start,
          realtime_end
        ))
      }
      return(invisible(NULL))
    }
  )
)
