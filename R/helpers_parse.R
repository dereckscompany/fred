# File: R/helpers_parse.R
# The FRED JSON -> typed data.table parse layer. FRED serves observations as an
# array of {realtime_start, realtime_end, date, value} objects (value a STRING,
# with "." meaning a missing observation) and metadata/releases as arrays of flat
# objects. Every parser's empty branch returns a fully-typed zero-row table via an
# `empty_dt_*()` constructor, so a caller's column contract holds on an empty
# result. Extraction is vectorised (one pass per column) because the ALFRED
# as-known-then long form of a heavily-revised series runs to ~900,000 rows.

# ---- Small coercers ----

#' Coerce a possibly-NULL scalar to integer, or NA
#'
#' @param x (any | NULL) a scalar value (number, string, or `NULL`).
#' @return (scalar<integer | NA>) the parsed integer, or `NA_integer_`.
#' @keywords internal
#' @noassert
#' @noRd
fred_int_or_na <- function(x) {
  out <- NA_integer_
  if (!is.null(x) && length(x) > 0L) {
    out <- suppressWarnings(as.integer(x[[1L]]))
  }
  return(out)
}

#' Turn a vector of FRED value strings into numerics
#'
#' FRED delivers each observation `value` as a STRING, and the sentinel "." means
#' a missing observation. Both "." and an absent (`NA_character_`) value become
#' `NA_real_` -- never 0, the classic FRED trap -- and everything else parses to a
#' double.
#'
#' @param x (character) the raw value strings.
#' @return (numeric) the parsed values, `NA_real_` where missing.
#' @keywords internal
#' @noassert
#' @noRd
fred_value_to_numeric <- function(x) {
  x[x == "."] <- NA_character_
  return(suppressWarnings(as.numeric(x)))
}

#' Parse a FRED `last_updated` timestamp to POSIXct (UTC)
#'
#' The metadata `last_updated` field arrives as `"2026-06-23 08:01:02-05"` (a date
#' time with a UTC offset); it is parsed to a UTC POSIXct. Unparseable or absent
#' values become `NA`.
#'
#' @param x (character) the raw `last_updated` string(s).
#' @return (class<POSIXct>) the timestamp(s) in UTC.
#' @importFrom lubridate ymd_hms
#' @keywords internal
#' @noassert
#' @noRd
fred_parse_last_updated <- function(x) {
  return(lubridate::ymd_hms(x, tz = "UTC", quiet = TRUE))
}

#' Parse a vector of FRED date strings to Date
#'
#' FRED serves every date (observation date, real-time-window bound) as
#' `"YYYY-MM-DD"`; the ALFRED "still current" sentinel `"9999-12-31"` is a valid
#' Date. Unparseable values become `NA` (caught structurally at the return
#' boundary, since the date columns are typed non-nullable).
#'
#' @param x (character) the raw date strings.
#' @return (class<Date>) the parsed dates.
#' @importFrom lubridate ymd
#' @keywords internal
#' @noassert
#' @noRd
fred_parse_dates <- function(x) {
  return(lubridate::ymd(x, quiet = TRUE))
}

# ---- Observations / vintages (the same 5-column shape) ----

# The observations endpoint returns the same element shape whether we ask for the
# latest window (get_series) or the whole ALFRED matrix (get_series_vintages), so
# one parser and one set of columns serve both; the methods differ only in their
# typed return contract (FredObservations vs FredVintages) and their docs.
.fred_observation_columns <- function() {
  return(data.table::data.table(
    series_id = character(0L),
    date = lubridate::as_date(numeric(0L)),
    value = numeric(0L),
    realtime_start = lubridate::as_date(numeric(0L)),
    realtime_end = lubridate::as_date(numeric(0L))
  ))
}

#' The typed zero-row FredObservations table
#'
#' @return (FredObservations) a zero-row, fully-typed observations table.
#' @keywords internal
#' @noRd
empty_dt_fred_observations <- function() {
  return(assert_return_empty_dt_fred_observations(.fred_observation_columns()))
}

#' The typed zero-row FredVintages table
#'
#' @return (FredVintages) a zero-row, fully-typed vintages table.
#' @keywords internal
#' @noRd
empty_dt_fred_vintages <- function() {
  return(assert_return_empty_dt_fred_vintages(.fred_observation_columns()))
}

#' Parse a FRED observations response into the 5-column observation shape
#'
#' Flattens `body$observations` (a list of {realtime_start, realtime_end, date,
#' value} objects) into a typed `data.table` tagged with `series_id`. Used by both
#' `get_series()` (one real-time window) and `get_series_vintages()` (each vintage
#' page); the value "." sentinel becomes `NA`.
#'
#' @param body (list | NULL) the parsed observations response, or `NULL` for an
#'   empty body.
#' @param series_id (scalar<character>) the series id (a constant column).
#' @return (FredObservations) the parsed observations (zero-row when empty).
#' @importFrom data.table data.table
#' @keywords internal
#' @noassert
#' @noRd
parse_fred_observations <- function(body, series_id) {
  obs <- if (is.null(body)) NULL else body[["observations"]]
  result <- empty_dt_fred_observations()
  if (!is.null(obs) && length(obs) > 0L) {
    date_chr <- vapply(obs, function(o) connectcore::chr_or_na(o[["date"]]), character(1L))
    value_chr <- vapply(obs, function(o) connectcore::chr_or_na(o[["value"]]), character(1L))
    rts_chr <- vapply(obs, function(o) connectcore::chr_or_na(o[["realtime_start"]]), character(1L))
    rte_chr <- vapply(obs, function(o) connectcore::chr_or_na(o[["realtime_end"]]), character(1L))
    result <- data.table::data.table(
      series_id = series_id,
      date = fred_parse_dates(date_chr),
      value = fred_value_to_numeric(value_chr),
      realtime_start = fred_parse_dates(rts_chr),
      realtime_end = fred_parse_dates(rte_chr)
    )
  }
  return(result)
}

# ---- Series metadata / search ----

#' The typed zero-row FredSeriesInfo table
#'
#' @return (FredSeriesInfo) a zero-row, fully-typed series-info table.
#' @importFrom lubridate as_datetime as_date
#' @keywords internal
#' @noRd
empty_dt_fred_series_info <- function() {
  return(assert_return_empty_dt_fred_series_info(data.table::data.table(
    series_id = character(0L),
    title = character(0L),
    observation_start = lubridate::as_date(numeric(0L)),
    observation_end = lubridate::as_date(numeric(0L)),
    frequency = character(0L),
    frequency_short = character(0L),
    units = character(0L),
    units_short = character(0L),
    seasonal_adjustment = character(0L),
    seasonal_adjustment_short = character(0L),
    last_updated = lubridate::as_datetime(numeric(0L), tz = "UTC"),
    popularity = integer(0L),
    group_popularity = integer(0L),
    notes = character(0L),
    realtime_start = lubridate::as_date(numeric(0L)),
    realtime_end = lubridate::as_date(numeric(0L))
  )))
}

#' Parse a FRED series (metadata or search) response into the FredSeriesInfo shape
#'
#' Both `/fred/series` and `/fred/series/search` return a `seriess` array of the
#' same element shape (search additionally populates `group_popularity`); this
#' binds one row per element.
#'
#' @param body (list | NULL) the parsed series response, or `NULL`.
#' @return (FredSeriesInfo) one row per series (zero-row when empty).
#' @importFrom data.table data.table rbindlist
#' @keywords internal
#' @noassert
#' @noRd
parse_fred_series_info <- function(body) {
  seriess <- if (is.null(body)) NULL else body[["seriess"]]
  result <- empty_dt_fred_series_info()
  if (!is.null(seriess) && length(seriess) > 0L) {
    result <- data.table::rbindlist(
      lapply(seriess, function(s) {
        return(data.table::data.table(
          series_id = connectcore::chr_or_na(s[["id"]]),
          title = connectcore::chr_or_na(s[["title"]]),
          observation_start = fred_parse_dates(connectcore::chr_or_na(s[["observation_start"]])),
          observation_end = fred_parse_dates(connectcore::chr_or_na(s[["observation_end"]])),
          frequency = connectcore::chr_or_na(s[["frequency"]]),
          frequency_short = connectcore::chr_or_na(s[["frequency_short"]]),
          units = connectcore::chr_or_na(s[["units"]]),
          units_short = connectcore::chr_or_na(s[["units_short"]]),
          seasonal_adjustment = connectcore::chr_or_na(s[["seasonal_adjustment"]]),
          seasonal_adjustment_short = connectcore::chr_or_na(s[["seasonal_adjustment_short"]]),
          last_updated = fred_parse_last_updated(connectcore::chr_or_na(s[["last_updated"]])),
          popularity = fred_int_or_na(s[["popularity"]]),
          group_popularity = fred_int_or_na(s[["group_popularity"]]),
          notes = connectcore::chr_or_na(s[["notes"]]),
          realtime_start = fred_parse_dates(connectcore::chr_or_na(s[["realtime_start"]])),
          realtime_end = fred_parse_dates(connectcore::chr_or_na(s[["realtime_end"]]))
        ))
      }),
      fill = TRUE
    )
  }
  return(result)
}

# ---- Releases ----

#' The typed zero-row FredReleases table
#'
#' @return (FredReleases) a zero-row, fully-typed releases table.
#' @importFrom lubridate as_date
#' @keywords internal
#' @noRd
empty_dt_fred_releases <- function() {
  return(assert_return_empty_dt_fred_releases(data.table::data.table(
    release_id = integer(0L),
    name = character(0L),
    press_release = logical(0L),
    link = character(0L),
    notes = character(0L),
    realtime_start = lubridate::as_date(numeric(0L)),
    realtime_end = lubridate::as_date(numeric(0L))
  )))
}

#' Parse a FRED releases response into the FredReleases shape
#'
#' @param body (list | NULL) the parsed releases response, or `NULL`.
#' @return (FredReleases) one row per release (zero-row when empty).
#' @importFrom data.table data.table rbindlist
#' @keywords internal
#' @noassert
#' @noRd
parse_fred_releases <- function(body) {
  releases <- if (is.null(body)) NULL else body[["releases"]]
  result <- empty_dt_fred_releases()
  if (!is.null(releases) && length(releases) > 0L) {
    result <- data.table::rbindlist(
      lapply(releases, function(r) {
        return(data.table::data.table(
          release_id = fred_int_or_na(r[["id"]]),
          name = connectcore::chr_or_na(r[["name"]]),
          press_release = connectcore::lgl_or_na(r[["press_release"]]),
          link = connectcore::chr_or_na(r[["link"]]),
          notes = connectcore::chr_or_na(r[["notes"]]),
          realtime_start = fred_parse_dates(connectcore::chr_or_na(r[["realtime_start"]])),
          realtime_end = fred_parse_dates(connectcore::chr_or_na(r[["realtime_end"]]))
        ))
      }),
      fill = TRUE
    )
  }
  return(result)
}

# ---- Release dates ----

#' The typed zero-row FredReleaseDates table
#'
#' @return (FredReleaseDates) a zero-row, fully-typed release-dates table.
#' @importFrom lubridate as_date
#' @keywords internal
#' @noRd
empty_dt_fred_release_dates <- function() {
  return(assert_return_empty_dt_fred_release_dates(data.table::data.table(
    release_id = integer(0L),
    date = lubridate::as_date(numeric(0L))
  )))
}

#' Parse a FRED release-dates response into the FredReleaseDates shape
#'
#' @param body (list | NULL) the parsed release-dates response, or `NULL`.
#' @return (FredReleaseDates) one row per (release, publication date).
#' @importFrom data.table data.table rbindlist
#' @keywords internal
#' @noassert
#' @noRd
parse_fred_release_dates <- function(body) {
  dates <- if (is.null(body)) NULL else body[["release_dates"]]
  result <- empty_dt_fred_release_dates()
  if (!is.null(dates) && length(dates) > 0L) {
    result <- data.table::rbindlist(
      lapply(dates, function(d) {
        return(data.table::data.table(
          release_id = fred_int_or_na(d[["release_id"]]),
          date = fred_parse_dates(connectcore::chr_or_na(d[["date"]]))
        ))
      }),
      fill = TRUE
    )
  }
  return(result)
}
