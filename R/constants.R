# File: R/constants.R
# Package constants and the environment-backed URL getter / key reader. No bare
# constants are hoisted at the top of other module files; every vocabulary value
# lives here with roxygen documentation, per the house convention.

#' FRED / ALFRED API base URL
#'
#' The single host under which every FRED endpoint is addressed (e.g.
#' `/fred/series/observations`, `/fred/series`). FRED (latest values) and ALFRED
#' (as-known-then vintages) are the **same host**, split only by the
#' `realtime_start` / `realtime_end` and `output_type` query parameters — there is
#' no separate ALFRED host. Overridable with the `FRED_BASE_URL` environment
#' variable.
#'
#' @param url (scalar<character>) an explicit base URL override. Defaults to the
#'   `FRED_BASE_URL` environment variable, or the public host when unset.
#' @return (scalar<character>) the base URL.
#' @export
fred_base_url <- connectcore::url_getter("FRED_BASE_URL", "https://api.stlouisfed.org")

#' Read the FRED API key from the environment
#'
#' Resolves the `FRED_API_KEY` environment variable, returning an empty string
#' when unset. Every FRED endpoint requires a key; a request made with an empty
#' (or invalid) key aborts with a typed [fred_conditions] error at request time
#' (FRED answers with an HTTP 400 whose body names the key problem).
#'
#' @return (scalar<character>) the API key, or `""` when unset.
#' @export
fred_api_key <- function() {
  return(connectcore::env_or("FRED_API_KEY"))
}

#' FRED free-tier request budget (requests per minute)
#'
#' FRED throttles at 120 requests per minute per API key. Exposed so a caller can
#' set the client's `throttle_rate` from it (120 / 60 = 2 requests/second).
#'
#' @format A `scalar<integer>`.
#' @export
FRED_RPM <- 120L

#' Maximum observation rows per FRED response (the offset-page size)
#'
#' The FRED `series/observations` endpoint caps a single response at 100,000 rows.
#' The ALFRED as-known-then long form of a heavily-revised series exceeds this (a
#' whole-history financial-conditions index is ~900,000 rows), so
#' `get_series_vintages()` pulls it in disjoint offset pages of this size (see
#' [FredSeries]). It is also the default `limit` a page is requested with.
#'
#' @format A `scalar<integer>`.
#' @export
FRED_MAX_ROWS_PER_PAGE <- 100000L

#' ALFRED earliest real-time-period sentinel
#'
#' The floor FRED accepts for `realtime_start`. Passing it as the vintage window's
#' start makes `output_type = 1` return every vintage from the beginning of the
#' series' archival record.
#'
#' @format A `scalar<character>` ISO date, `"1776-07-04"`.
#' @export
FRED_REALTIME_MIN <- "1776-07-04"

#' ALFRED latest real-time-period sentinel
#'
#' The ceiling FRED accepts for `realtime_end`. Passing it as the vintage window's
#' end makes `output_type = 1` return every vintage through the most recent one; a
#' vintage row whose `realtime_end` equals this value is **still current** (has not
#' yet been superseded by a later revision).
#'
#' @format A `scalar<character>` ISO date, `"9999-12-31"`.
#' @export
FRED_REALTIME_MAX <- "9999-12-31"

#' FRED observations `output_type` vocabulary
#'
#' The four shapes the `series/observations` endpoint can return, selected by the
#' `output_type` parameter:
#' - `by_realtime_period` (1): observations by real-time period — the ALFRED
#'   as-known-then **long form**, one row per (observation date, contiguous
#'   real-time window). This is the shape `get_series_vintages()` pins, and the
#'   shape whose deterministic total order lets disjoint offset pages stitch back
#'   to the un-paged whole.
#' - `by_vintage_all` (2): observations by vintage date, all — a **wide** matrix
#'   (one column per vintage date) this package does not parse.
#' - `by_vintage_new` (3): observations by vintage date, new and revised only.
#' - `initial_release` (4): initial release only (plus the latest value).
#'
#' @format A named `list` of `scalar<integer>` codes.
#' @export
FRED_OUTPUT_TYPE <- list(
  by_realtime_period = 1L,
  by_vintage_all = 2L,
  by_vintage_new = 3L,
  initial_release = 4L
)

#' Sort-order vocabulary
#'
#' The accepted values of the `sort_order` parameter shared by the observations,
#' search, releases, and release-dates endpoints.
#'
#' @format A named `list` of `scalar<character>` values: `asc`, `desc`.
#' @export
SORT_ORDER <- list(
  asc = "asc",
  desc = "desc"
)

#' Series-search `search_type` vocabulary
#'
#' The accepted values of the `series/search` endpoint's `search_type` parameter:
#' - `full_text`: match the search text against series attributes (title, units,
#'   frequency, ...) and rank by relevance. The default.
#' - `series_id`: substring-match the search text against the series id only.
#'
#' @format A named `list` of `scalar<character>` values: `full_text`, `series_id`.
#' @export
SEARCH_TYPE <- list(
  full_text = "full_text",
  series_id = "series_id"
)
