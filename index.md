# fred

R API wrapper to the St. Louis Fed’s **FRED** and **ALFRED**
economic-data API, supporting both synchronous and asynchronous
(promise-based) operations, built on the shared
[connectcore](https://github.com/dereckscompany/connectcore) transport
base.

## What this is

FRED (Federal Reserve Economic Data) is the standard free source for US
macro series — GDP, unemployment, money supply, financial-conditions
indices, the dollar, Treasury yields, and hundreds of thousands more.
This package returns those series as tidy `data.table`s, synchronously
or asynchronously, with typed columns and typed errors.

Its reason to exist alongside the excellent CRAN alternatives is one
discipline they leave to you: **vintages as a first-class, typed
surface.**

## The revision trap (why vintages matter)

FRED serves the *latest revised* value of every observation. Most macro
series are revised long after first release — money supply,
unemployment, and jobless claims restate their history when seasonal
factors or population controls are re-estimated; a financial-conditions
index revises its *entire* history every week. So the history FRED shows
today is **not** the history anyone actually had in the past: it embeds
numbers that did not exist then. Backtesting a strategy on it is
look-ahead by construction — the model silently “knows” revisions that
had not yet happened.

**ALFRED** (ArchivaL FRED) is the fix. It serves every value *as it was
known at each point in time*. This package makes that as-known-then
surface a headline method (`get_series_vintages()`), typed and tested,
so a point-in-time backtest can be honest.

## Design philosophy

- **`data.table` everywhere, no list columns.** Every method returns one
  flat `data.table`; the observation value is typed nullable (FRED
  serves `.` for a missing observation, which becomes `NA`, never `0`),
  structural columns (ids, dates, real-time-window bounds) strict.
- **Sync and async.** Every request-making method works in both modes.
  `async = TRUE` returns a \[promise\]\[promises::promise\]; otherwise
  the table is returned directly. There is a single sync/async branch
  point (inherited from `connectcore`), threaded even through the
  vintage pager.
- **Vintage-first.** `get_series()` exposes the real-time window
  directly (the latest values are simply today’s window);
  `get_series_vintages()` returns the whole as-known-then matrix,
  offset-paged so a ~900,000-row history streams back safely.
- **Typed errors.** Every failure is a classed condition
  (`fred_api_error`, `fred_validation_error`) carrying structured fields
  — you branch on the type, never grep the message. The API key is
  redacted from every stored URL.

## Installation

This project uses [`renv`](https://rstudio.github.io/renv/). Add `fred`
to your lockfile and restore:

``` r

renv::install("dereckscompany/fred")
# or, without renv:
# remotes::install_github("dereckscompany/fred")
```

## The API key

Every FRED endpoint requires a free API key. Request one at
<https://fred.stlouisfed.org/docs/api/api_key.html>, then store it in
`.Renviron`:

``` bash
FRED_API_KEY="your-32-char-key"
```

FRED throttles at 120 requests/minute per key; pass `throttle_rate = 2`
to the constructor to stay under it during rapid loops.

## Latest observations

Omit the real-time window for the latest values (today’s window). The
value column is nullable — FRED’s `.` sentinel (a market holiday here)
becomes `NA`, never `0`.

``` r

client <- FredSeries$new()

tips <- client$get_series("DFII10")
tips
```

``` R
#>    series_id       date value realtime_start realtime_end
#>       <char>     <Date> <num>         <Date>       <Date>
#> 1:    DFII10 2024-01-02  2.05     2026-07-14   2026-07-14
#> 2:    DFII10 2024-01-03    NA     2026-07-14   2026-07-14
```

`get_series()` also exposes `observation_start` / `observation_end` for
a date range, `realtime_start` / `realtime_end` to ask what was known
*then*, and FRED’s server-side `units` / `frequency` /
`aggregation_method` transforms.

## As-known-then vintages (the headline)

`get_series_vintages()` returns the ALFRED long form: one row per
(observation date, real-time window), each carrying the value that was
current during that window. A row whose `realtime_end` is `"9999-12-31"`
is still current.

``` r

m2 <- client$get_series_vintages("M2SL")
m2
```

``` R
#>    series_id       date value realtime_start realtime_end
#>       <char>     <Date> <num>         <Date>       <Date>
#> 1:      M2SL 2024-01-01 20800     2024-02-27   2024-03-25
#> 2:      M2SL 2024-01-01 20850     2024-03-26   9999-12-31
```

Here one reference month (`2024-01-01`) has two rows: the initial
`20800` (current 2024-02-27 through 2024-03-25) and the revised `20850`
(current from 2024-03-26 onward). To reconstruct what was knowable on a
date `d`, keep, for each observation, the row whose
`[realtime_start, realtime_end]` window contains `d`. A whole-history
matrix that exceeds FRED’s 100,000-row response cap is pulled in
disjoint offset pages that stitch back to the un-paged whole with no
seam clip, skip, or duplicate.

## Metadata and search

``` r

info <- client$get_series_info("UNRATE")
info[, .(series_id, title, frequency, units, last_updated)]

hits <- client$search_series("real gross domestic product")
hits[, .(series_id, title, popularity)]
```

``` R
#>    series_id             title frequency   units        last_updated
#>       <char>            <char>    <char>  <char>              <POSc>
#> 1:    UNRATE Unemployment Rate   Monthly Percent 2026-07-03 12:48:03
#>    series_id                       title popularity
#>       <char>                      <char>      <int>
#> 1:     GDPC1 Real Gross Domestic Product         89
#> 2:       GDP      Gross Domestic Product         85
```

## Releases

``` r

releases <- client$get_releases()
releases[, .(release_id, name, press_release)]

client$get_release_dates(10L)
```

``` R
#>    release_id                                                name press_release
#>         <int>                                              <char>        <lgcl>
#> 1:         10                                Consumer Price Index          TRUE
#> 2:         13 G.17 Industrial Production and Capacity Utilization          TRUE
#>    release_id       date
#>         <int>     <Date>
#> 1:         10 2026-05-13
#> 2:         10 2026-06-11
#> 3:         10 2026-07-15
```

## Asynchronous usage

Set `async = TRUE` and consume the promise with
[`coro::async`](https://coro.r-lib.org/reference/async.html) / `await`,
driving the event loop with `later`:

``` r

box::use(coro, later)

client_async <- FredSeries$new(async = TRUE)

main <- coro::async(function() {
    unrate <- await(client_async$get_series("UNRATE"))
    nfci <- await(client_async$get_series_vintages("NFCI"))
    print(list(unrate = unrate, nfci = nfci))
})

main()
while (!later::loop_empty()) later::run_now()
```

## Error handling

``` r

result <- tryCatch(
    client$get_series_vintages("M2SL", realtime_start = "2020-01-01", realtime_end = "2010-01-01"),
    fred_validation_error = function(e) paste("caught:", conditionMessage(e))
)
result
```

``` R
#> [1] "caught: `realtime_start` (2020-01-01) must be on or before `realtime_end` (2010-01-01)."
```

A FRED HTTP failure raises `fred_api_error_<status>` (nested into the
fleet-wide `connectcore_api_error` chain) carrying `status`, FRED’s own
`error_code`, and a key-redacted `url`.
