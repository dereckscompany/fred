# File: R/types_fred.R
# Reusable roxyassert `@type` shapes for the data.tables the public surface
# returns. Each request-making method documents its return as one of these named
# shapes via `(Shape | promise<Shape>)`; the contract roclet expands the shape
# into that method's generated `assert_return_*` helper, so every column's
# presence and type is enforced at the public boundary -- for both the synchronous
# value and the resolved value of a promise (wired through
# `connectcore::then_or_now()`). The parsers in R/helpers_parse.R build the same
# shapes and their empty branches return the fully-typed zero-row table
# (`empty_dt_*()`), so a shape's column contract holds even on an empty result.
#
# The observation VALUE is a measurement (typed `| NA`): FRED serves the sentinel
# "." for a missing observation, which becomes NA, never 0. The observation date
# and the real-time-window bounds are structural (strict): every FRED observation
# element carries all three, and together they are a row's identity.

#' @title fred return shapes
#' @description Reusable roxyassert `@type` shapes for the parsed fred
#' `data.table`s. Measurement columns (a published statistic value) are typed
#' `| NA`; structural columns (ids, dates, real-time-window bounds) are strict.
#' `fred` is a leaf connector: nothing internal calls a per-shape validator and no
#' downstream package validates against these shapes, so there is no `@genassert`
#' and no `@exportassert`; the shapes exist only to be expanded into each method's
#' own return contract.
#' @name fred_shapes
#'
#' @type FredObservations (data.table) one row per (series_id, observation date) at the requested real-time window:
#' - series_id (character) the FRED series id, e.g. "DFII10"; structural.
#' - date (Date) the observation (reference-period) date; structural.
#' - value (numeric | NA) the published value at the requested real-time window; NA where FRED serves "." (no
#'   observation, e.g. a market holiday), never 0.
#' - realtime_start (Date) the first day this value was the one FRED served for that date at the requested window;
#'   structural.
#' - realtime_end (Date) the last day this value was served; for a latest pull this is the request date; structural.
#'
#' @type FredVintages (data.table) the ALFRED output_type=1 as-known-then long form: one row per (observation date,
#' contiguous real-time window) of a series:
#' - series_id (character) the FRED series id, e.g. "NFCI"; structural.
#' - date (Date) the observation (reference-period) date; structural.
#' - value (numeric | NA) the value as it was known during that real-time window; NA where FRED serves "."; never 0.
#' - realtime_start (Date) the first day this value was the current vintage for that observation date; structural.
#' - realtime_end (Date) the last day this value was the current vintage; the FRED_REALTIME_MAX sentinel
#'   ("9999-12-31") means it is still current (not yet superseded by a later revision); structural.
#'
#' @type FredSeriesInfo (data.table) one row per series, from the metadata (series) or search endpoint:
#' - series_id (character) the FRED series id; structural.
#' - title (character) the human-readable title; structural.
#' - observation_start (Date) the earliest observation date FRED holds; structural.
#' - observation_end (Date) the latest observation date FRED holds; structural.
#' - frequency (character) the observation frequency, e.g. "Monthly"; structural.
#' - frequency_short (character) the short frequency code, e.g. "M"; structural.
#' - units (character) the value units, e.g. "Percent"; structural.
#' - units_short (character) the short units, e.g. "%"; structural.
#' - seasonal_adjustment (character) the seasonal-adjustment description, e.g. "Not Seasonally Adjusted"; structural.
#' - seasonal_adjustment_short (character) the short code, e.g. "NSA"; structural.
#' - last_updated (POSIXct | NA) when FRED last updated the series (the release timestamp, in UTC); NA if unparseable.
#' - last_updated_raw (character | NA) FRED's own last_updated string exactly as sent, e.g. "2026-07-03 07:48:03-05"
#'   (a datetime carrying a UTC offset); the faithful source last_updated is parsed from, preserved verbatim so a
#'   point-in-time archive keeps the venue's own representation; NA when FRED omits the field.
#' - popularity (integer | NA) FRED's 0-100 popularity score; measurement.
#' - group_popularity (integer | NA) the release-group popularity score; measurement; NA for the metadata endpoint
#'   (only the search endpoint returns it).
#' - notes (character | NA) the free-text series notes; NA when FRED omits them.
#' - realtime_start (Date) the start of the real-time period the metadata was requested for; structural.
#' - realtime_end (Date) the end of the real-time period; structural.
#'
#' @type FredReleases (data.table) one row per FRED release (the publication a series belongs to):
#' - release_id (integer) the numeric release id; structural.
#' - name (character) the release name, e.g. "H.6 Money Stock Measures"; structural.
#' - press_release (logical) whether the release has an associated press release; structural.
#' - link (character | NA) the release's web link; NA when absent.
#' - notes (character | NA) the free-text release notes; NA when absent.
#' - realtime_start (Date) the start of the requested real-time period; structural.
#' - realtime_end (Date) the end of the requested real-time period; structural.
#'
#' @type FredReleaseDates (data.table) one row per (release, publication date), from the release-dates endpoint:
#' - release_id (integer) the numeric release id; structural.
#' - date (Date) a date on which the release was published; structural.
NULL
