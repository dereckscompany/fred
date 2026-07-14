# FredSeries: the FRED / ALFRED economic-data client

Retrieves St. Louis Fed economic data: series observations at any
real-time window (get_series), the ALFRED as-known-then vintage history
(get_series_vintages), series metadata (get_series_info), full-text
search (search_series), and the release calendar (get_releases /
get_release_dates). Every method returns a tidy
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html).

## Details

Inherits the transport plumbing (the single sync/async request funnel,
retry, throttle) from
[connectcore::RestClient](https://dereckscompany.github.io/connectcore/reference/RestClient.html)
and customises only the two seams specific to FRED:

- `.sign()` — FRED authentication is a single query-parameter `api_key`,
  so this appends `&api_key=<FRED_API_KEY>&file_type=json` to every
  request (there is no HMAC or JWT).

- `.parse_envelope()` — FRED answers every failure with a real non-2xx
  HTTP status and a JSON `{error_code, error_message}` body, which this
  raises as a typed
  [fred_conditions](https://dereckscompany.github.io/fred/reference/fred_conditions.md)
  error.

### Vintages vs latest — the revision trap

FRED and ALFRED are the same host, split only by the `realtime_start` /
`realtime_end` window and the `output_type`. The **latest** value of an
observation is simply the value at today's real-time window; it is not a
separate endpoint or code path. `get_series()` exposes the window
directly: omit it for the latest values, or pass a past `realtime_start`
to see what was known *then*. `get_series_vintages()` returns the whole
as-known-then matrix (every value of every observation as it stood in
each real-time window) — the honest surface for a point-in-time
backtest. See `get_series_vintages()` for why this matters.

### Sync vs async

The `async` argument selects the execution mode for every method:

- `async = FALSE` (default): methods return a
  [data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html).

- `async = TRUE`: methods return a
  [promises::promise](https://rstudio.github.io/promises/reference/promise.html)
  that resolves to the same `data.table`.

The mode is stored once as `private$.is_async` and threaded through
every method's
[`connectcore::then_or_now()`](https://dereckscompany.github.io/connectcore/reference/then_or_now.html)
tail (and through the vintage pager); nothing hardcodes it. Consume
promises with
[`coro::async()`](https://coro.r-lib.org/reference/async.html) and
`await()`; drive the loop in a script with
`while (!later::loop_empty()) later::run_now()`.

### The API key

Every FRED endpoint requires a key (unlike some connectors, there is no
keyless surface). The key is read from `FRED_API_KEY` (the `api_key`
argument overrides). An empty key **warns** at construction rather than
aborting; a request with an empty or invalid key aborts with a typed
[fred_conditions](https://dereckscompany.github.io/fred/reference/fred_conditions.md)
error at request time.

## Super class

[`connectcore::RestClient`](https://dereckscompany.github.io/connectcore/reference/RestClient.html)
-\> `FredSeries`

## Methods

### Public methods

- [`FredSeries$new()`](#method-FredSeries-new)

- [`FredSeries$get_series()`](#method-FredSeries-get_series)

- [`FredSeries$get_series_vintages()`](#method-FredSeries-get_series_vintages)

- [`FredSeries$get_series_info()`](#method-FredSeries-get_series_info)

- [`FredSeries$search_series()`](#method-FredSeries-search_series)

- [`FredSeries$get_releases()`](#method-FredSeries-get_releases)

- [`FredSeries$get_release_dates()`](#method-FredSeries-get_release_dates)

- [`FredSeries$clone()`](#method-FredSeries-clone)

------------------------------------------------------------------------

### Method `new()`

Initialise a FredSeries client.

#### Usage

    FredSeries$new(
      api_key = fred_api_key(),
      base_url = fred_base_url(),
      async = FALSE,
      max_tries = 3L,
      throttle_rate = NULL
    )

#### Arguments

- `api_key`:

  (scalar\<character\>) the FRED API key. Defaults to the `FRED_API_KEY`
  environment variable (empty when unset).

- `base_url`:

  (scalar\<character\>) the FRED API base URL. Defaults to
  [`fred_base_url()`](https://dereckscompany.github.io/fred/reference/fred_base_url.md).

- `async`:

  (scalar\<logical\>) if `TRUE`, methods return promises. Default
  `FALSE`.

- `max_tries`:

  (scalar\<count in \[1, Inf\[\>) retry an idempotent GET up to this
  many times on a transient failure (408, 429, any 5xx, or a connection
  failure). FRED reads are all GETs, so retry is always safe. Default
  `3`.

- `throttle_rate`:

  (scalar\<numeric in \]0, Inf\[\> \| NULL) client-side rate cap in
  requests/second. FRED's budget is 120/minute (2/second); pass `2` to
  stay under it during rapid loops. Default `NULL` (no throttle).

#### Returns

(class\<FredSeries\>) invisibly, self.

------------------------------------------------------------------------

### Method `get_series()`

Retrieve a series' observations at a real-time window. Omit the
real-time window for the **latest** values (today's window); pass a past
`realtime_start` (and matching `realtime_end`) for the values as they
were known then. This is a single request: a single real-time window
rarely exceeds FRED's 100,000-row response cap, but if it does, page
with `limit` / `offset`. For the full as-known-then matrix across every
real-time window, use `get_series_vintages()`.

#### Usage

    FredSeries$get_series(
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
    )

#### Arguments

- `series_id`:

  (scalar\<character\>) the FRED series id, e.g. `"DFII10"`.

- `observation_start`:

  (scalar\<character\> \| NULL) earliest observation date to return, ISO
  `"YYYY-MM-DD"`. `NULL` uses FRED's floor. Default `NULL`.

- `observation_end`:

  (scalar\<character\> \| NULL) latest observation date, ISO
  `"YYYY-MM-DD"`. `NULL` uses FRED's ceiling. Default `NULL`.

- `realtime_start`:

  (scalar\<character\> \| NULL) start of the real-time period (the as-of
  window), ISO `"YYYY-MM-DD"`. `NULL` is today (the latest values).
  Default `NULL`.

- `realtime_end`:

  (scalar\<character\> \| NULL) end of the real-time period, ISO
  `"YYYY-MM-DD"`. `NULL` is today. Default `NULL`.

- `units`:

  (scalar\<character\> \| NULL) a server-side value transform (`"lin"`,
  `"chg"`, `"pch"`, `"pc1"`, `"log"`, ...). `NULL` is levels (`"lin"`).
  Default `NULL`.

- `frequency`:

  (scalar\<character\> \| NULL) a server-side frequency aggregation
  (`"d"`, `"w"`, `"m"`, `"q"`, `"a"`, ...). `NULL` is the series' native
  frequency. Default `NULL`.

- `aggregation_method`:

  (scalar\<character\> \| NULL) how to aggregate when `frequency` is
  coarser than native (`"avg"`, `"sum"`, `"eop"`). Default `NULL`.

- `sort_order`:

  (scalar\<character in c("asc", "desc")\>) observation date order.
  Default `"asc"`.

- `limit`:

  (scalar\<count in \[1, Inf\[\> \| NULL) maximum rows (FRED caps a
  single response at 100,000). `NULL` uses FRED's default. Default
  `NULL`.

- `offset`:

  (scalar\<count in \[0, Inf\[\> \| NULL) row offset for paging. Default
  `NULL`.

#### Returns

(FredObservations \| promise\<FredObservations\>) the observations, or a
promise thereof.

------------------------------------------------------------------------

### Method `get_series_vintages()`

Retrieve a series' ALFRED as-known-then vintage history — the headline
surface.

#### Usage

    FredSeries$get_series_vintages(
      series_id,
      realtime_start = FRED_REALTIME_MIN,
      realtime_end = FRED_REALTIME_MAX,
      page_limit = FRED_MAX_ROWS_PER_PAGE
    )

#### Arguments

- `series_id`:

  (scalar\<character\>) the FRED series id, e.g. `"NFCI"`.

- `realtime_start`:

  (scalar\<character\>) start of the vintage window, ISO `"YYYY-MM-DD"`.
  Default
  [FRED_REALTIME_MIN](https://dereckscompany.github.io/fred/reference/FRED_REALTIME_MIN.md)
  (every vintage from the start).

- `realtime_end`:

  (scalar\<character\>) end of the vintage window, ISO `"YYYY-MM-DD"`.
  Default
  [FRED_REALTIME_MAX](https://dereckscompany.github.io/fred/reference/FRED_REALTIME_MAX.md)
  (through the latest vintage).

- `page_limit`:

  (scalar\<count in \[1, Inf\[\>) rows per offset page. Default
  [FRED_MAX_ROWS_PER_PAGE](https://dereckscompany.github.io/fred/reference/FRED_MAX_ROWS_PER_PAGE.md)
  (FRED's per-response maximum).

#### Details

FRED serves the **latest revised** value of every observation. Most
macro series are revised after first release — money supply,
unemployment, and jobless claims restate their history when seasonal
factors or population controls are re-estimated; a financial-conditions
index revises its *entire* history every week. So the history FRED shows
today is not the history anyone had in the past: it embeds numbers that
did not exist then. Backtesting a strategy on it is look-ahead by
construction — the model "knows" revisions that had not happened.

ALFRED (ArchivaL FRED) fixes this. This method requests the
`output_type = 1` as-known-then **long form** over the whole real-time
window: one row per (observation date, contiguous real-time window),
each carrying the value that was current during that window. A row whose
`realtime_end` is the
[FRED_REALTIME_MAX](https://dereckscompany.github.io/fred/reference/FRED_REALTIME_MAX.md)
sentinel (`"9999-12-31"`) is still current. To reconstruct what was
knowable on a given date `d`, keep the row for each observation whose
`[realtime_start, realtime_end]` window contains `d`.

The whole-history matrix of a heavily-revised series exceeds FRED's
100,000-row response cap, so it is pulled in disjoint offset pages that
stitch back to the un-paged whole with no seam clip, skip, or duplicate
(the logic is proven live — see the seam-stitching test). The pages are
streamed internally and returned as one table; the request runs with a
generous timeout because the first page of a deeply-revised series makes
FRED build the whole matrix server-side.

#### Returns

(FredVintages \| promise\<FredVintages\>) the as-known-then long form,
or a promise thereof.

------------------------------------------------------------------------

### Method `get_series_info()`

Retrieve a series' metadata (title, frequency, units, seasonal
adjustment, observation span, last-updated timestamp, popularity, and
the free-text notes that often describe the revision cadence).

#### Usage

    FredSeries$get_series_info(
      series_id,
      realtime_start = NULL,
      realtime_end = NULL
    )

#### Arguments

- `series_id`:

  (scalar\<character\>) the FRED series id, e.g. `"UNRATE"`.

- `realtime_start`:

  (scalar\<character\> \| NULL) start of the real-time period, ISO
  `"YYYY-MM-DD"`. `NULL` is today. Default `NULL`.

- `realtime_end`:

  (scalar\<character\> \| NULL) end of the real-time period, ISO
  `"YYYY-MM-DD"`. `NULL` is today. Default `NULL`.

#### Returns

(FredSeriesInfo \| promise\<FredSeriesInfo\>) the one-row metadata, or a
promise thereof.

------------------------------------------------------------------------

### Method `search_series()`

Search the FRED series catalogue by full text or series id.

#### Usage

    FredSeries$search_series(
      search_text,
      search_type = SEARCH_TYPE$full_text,
      limit = 1000L,
      order_by = NULL,
      sort_order = NULL,
      realtime_start = NULL,
      realtime_end = NULL
    )

#### Arguments

- `search_text`:

  (scalar\<character\>) the query, e.g. `"real gdp"`.

- `search_type`:

  (scalar\<character\>) match the text against series attributes
  (`"full_text"`, ranked by relevance) or against the series id only
  (`"series_id"`), one of `names(SEARCH_TYPE)`. Validated against that
  vocabulary with a typed
  [fred_conditions](https://dereckscompany.github.io/fred/reference/fred_conditions.md)
  error. Default `"full_text"`.

- `limit`:

  (scalar\<count in \[1, Inf\[\>) maximum results (FRED caps search at
  1,000). Default `1000`.

- `order_by`:

  (scalar\<character\> \| NULL) the result ordering, e.g.
  `"search_rank"`, `"popularity"`, `"last_updated"`. `NULL` uses FRED's
  default. Default `NULL`.

- `sort_order`:

  (scalar\<character in c("asc", "desc")\> \| NULL) the sort direction.
  `NULL` uses FRED's default. Default `NULL`.

- `realtime_start`:

  (scalar\<character\> \| NULL) start of the real-time period, ISO
  `"YYYY-MM-DD"`. Default `NULL`.

- `realtime_end`:

  (scalar\<character\> \| NULL) end of the real-time period, ISO
  `"YYYY-MM-DD"`. Default `NULL`.

#### Returns

(FredSeriesInfo \| promise\<FredSeriesInfo\>) one row per matched
series, or a promise thereof.

------------------------------------------------------------------------

### Method `get_releases()`

List the FRED releases (the publications series belong to, e.g. the H.6
Money Stock release).

#### Usage

    FredSeries$get_releases(
      realtime_start = NULL,
      realtime_end = NULL,
      limit = 1000L,
      offset = NULL,
      order_by = NULL,
      sort_order = NULL
    )

#### Arguments

- `realtime_start`:

  (scalar\<character\> \| NULL) start of the real-time period, ISO
  `"YYYY-MM-DD"`. Default `NULL`.

- `realtime_end`:

  (scalar\<character\> \| NULL) end of the real-time period, ISO
  `"YYYY-MM-DD"`. Default `NULL`.

- `limit`:

  (scalar\<count in \[1, Inf\[\>) maximum releases (FRED caps this at
  1,000). Default `1000`.

- `offset`:

  (scalar\<count in \[0, Inf\[\> \| NULL) row offset for paging. Default
  `NULL`.

- `order_by`:

  (scalar\<character\> \| NULL) the ordering, e.g. `"release_id"`,
  `"name"`. `NULL` uses FRED's default. Default `NULL`.

- `sort_order`:

  (scalar\<character in c("asc", "desc")\> \| NULL) the sort direction.
  Default `NULL`.

#### Returns

(FredReleases \| promise\<FredReleases\>) one row per release, or a
promise thereof.

------------------------------------------------------------------------

### Method `get_release_dates()`

List the publication dates of a single release (its release calendar).

#### Usage

    FredSeries$get_release_dates(
      release_id,
      realtime_start = NULL,
      realtime_end = NULL,
      limit = NULL,
      offset = NULL,
      sort_order = NULL,
      include_empty = FALSE
    )

#### Arguments

- `release_id`:

  (scalar\<count in \[1, Inf\[\>) the numeric release id (from
  `get_releases()`).

- `realtime_start`:

  (scalar\<character\> \| NULL) start of the real-time period, ISO
  `"YYYY-MM-DD"`. `NULL` uses FRED's floor (`"1776-07-04"`). Default
  `NULL`.

- `realtime_end`:

  (scalar\<character\> \| NULL) end of the real-time period, ISO
  `"YYYY-MM-DD"`. `NULL` uses FRED's ceiling. Default `NULL`.

- `limit`:

  (scalar\<count in \[1, Inf\[\> \| NULL) maximum dates (FRED caps this
  at 10,000). `NULL` uses FRED's default. Default `NULL`.

- `offset`:

  (scalar\<count in \[0, Inf\[\> \| NULL) row offset for paging. Default
  `NULL`.

- `sort_order`:

  (scalar\<character in c("asc", "desc")\> \| NULL) the sort direction
  by date. Default `NULL`.

- `include_empty`:

  (scalar\<logical\>) include release dates with no new data (FRED's
  `include_release_dates_with_no_data`). Default `FALSE`.

#### Returns

(FredReleaseDates \| promise\<FredReleaseDates\>) one row per
publication date, or a promise thereof.

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    FredSeries$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.

## Examples

``` r
if (FALSE) { # \dontrun{
fred <- FredSeries$new()

# Latest values (today's real-time window):
tips <- fred$get_series("DFII10")

# As-known-then vintages of a heavily-revised series:
m2 <- fred$get_series_vintages("M2SL")

# Metadata and search:
info <- fred$get_series_info("UNRATE")
hits <- fred$search_series("real gross domestic product")

# Asynchronous:
fred_async <- FredSeries$new(async = TRUE)
main <- coro::async(function() {
  nfci <- await(fred_async$get_series("NFCI"))
  print(nfci)
})
main()
while (!later::loop_empty()) later::run_now()
} # }
```
