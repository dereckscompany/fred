# File: R/fred-package.R
# Package-level documentation and shared imports.

#' fred: API Wrapper to the FRED and ALFRED Federal Reserve Economic Data API
#'
#' A connector for the St. Louis Fed's FRED and ALFRED economic-data API
#' (`api.stlouisfed.org`), built on the shared [connectcore::RestClient]
#' transport base. It returns tidy [data.table::data.table]s and is built around
#' one discipline the CRAN alternatives leave to the caller: **vintages are a
#' first-class, typed surface**.
#'
#' ### The revision trap, in one paragraph
#' FRED serves the *latest revised* value of every observation. Most macro series
#' (money supply, unemployment, jobless claims, financial-conditions indices) are
#' revised — sometimes heavily, sometimes across their whole history — long after
#' first release. So "what does the API say GDP growth was in 2008-Q1 today" is
#' **not** "what a trader knew in 2008-Q1": today's history embeds numbers nobody
#' had then. Backtesting on it is look-ahead by construction. ALFRED (ArchivaL
#' FRED) fixes this: it serves every value *as it was known at each point in
#' time*. This package exposes that as-known-then surface directly through
#' [FredSeries]'s `get_series_vintages()`.
#'
#' ### What is covered
#' - [FredSeries]: the client. `get_series()` (observations at any real-time
#'   window — the latest values are simply today's window), the headline
#'   `get_series_vintages()` (the ALFRED as-known-then long form, offset-paged so
#'   a whole-history matrix that exceeds FRED's per-response row cap streams back
#'   safely), `get_series_info()` (metadata: frequency, units, revision cadence),
#'   `search_series()`, `get_releases()`, and `get_release_dates()`.
#'
#' ### Sync and async
#' Every request-making method supports both a synchronous mode (returns a
#' `data.table`) and an asynchronous mode (returns a [promises::promise] resolving
#' to the same `data.table`), selected by the `async` argument at construction.
#' See [FredSeries] for the mechanism.
#'
#' ### The API key
#' Every FRED endpoint requires a free API key (a 32-character lowercase
#' credential from <https://fred.stlouisfed.org/docs/api/api_key.html>). Supply it
#' as the `FRED_API_KEY` environment variable or the `api_key` constructor
#' argument. FRED throttles at 120 requests/minute per key. A missing or invalid
#' key surfaces as a typed [fred_conditions] error (an HTTP 400 whose body names
#' the key problem).
#'
#' @keywords internal
#' @import data.table
#' @import assert
"_PACKAGE"

# Quiet R CMD check's "no visible binding" notes for any data.table columns
# referenced unquoted in the parsers/pagers.
utils::globalVariables(c(
  "date",
  "realtime_start",
  "realtime_end",
  "series_id",
  "value"
))
