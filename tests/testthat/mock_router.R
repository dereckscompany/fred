# Shared mock HTTP router for the fred README and tests.
#
# The THIN fred-specific layer over connectcore's shared mock harness
# (connectcore::mock_router / with_mock_api / local_mock_api / load_fixtures /
# mock_response). connectcore owns the response builder, the dispatch loop, and
# the scoped-activation helpers; this file only declares the route table (URL
# pattern -> fixture) and loads the fixtures from disk.
#
# Every fixture is FULLY SYNTHETIC authored JSON (never captured from the live
# API), shaped exactly per FRED's documented JSON formats. The observations
# fixture carries a "." cell to exercise the missing-value -> NA rule; the vintage
# fixture carries two real-time windows of one date; the search fixture carries a
# null `notes` and a populated `group_popularity`. Because the key is a query
# parameter, the mock ignores it entirely.

box::use(
  connectcore[load_fixtures]
)

# Load every synthetic fixture as its raw JSON string, keyed by file basename
# (series_info.json -> "series_info"). Resolved relative to THIS module file so it
# works from the package root (README) and tests/testthat alike.
.fixtures <- load_fixtures(box::file("fixtures"))

# FRED answers every failure with a real non-2xx status and a JSON
# {error_code, error_message} body. This reproduces the "series does not exist"
# HTTP 400 so the envelope's typed-error path is exercised end-to-end.
#' @export
.error_response <- function() {
  return(httr2::response(
    status_code = 400L,
    url = "https://api.stlouisfed.org/fred/series/observations",
    headers = list("content-type" = "application/json"),
    body = charToRaw(paste0(
      "{\"error_code\":400,\"error_message\":\"Bad Request.  The series does not exist.\"}"
    ))
  ))
}

#' Route table: URL pattern -> synthetic-fixture JSON string (or a response thunk).
#'
#' Order matters -- the router returns the first substring match on `req$url`, so
#' the more-specific patterns precede the ones they contain (the vintage route
#' `output_type=1` before the bare observations route; `/fred/series/search` and
#' `/fred/series/observations` before `/fred/series`).
#' @export
.mock_routes <- list(
  # ---- Error surface (a specific series id triggers FRED's 400) ----
  list(pattern = "series_id=BADSERIES", fixture = .error_response),

  # ---- Observations: the vintage (output_type=1) route before the bare one ----
  list(pattern = "output_type=1", fixture = .fixtures$vintages_page),
  list(pattern = "/fred/series/observations", fixture = .fixtures$observations_latest),

  # ---- Series metadata / search (search before the bare series route) ----
  list(pattern = "/fred/series/search", fixture = .fixtures$series_search),
  list(pattern = "/fred/series", fixture = .fixtures$series_info),

  # ---- Releases (release/dates before releases) ----
  list(pattern = "/fred/release/dates", fixture = .fixtures$release_dates),
  list(pattern = "/fred/releases", fixture = .fixtures$releases)
)
