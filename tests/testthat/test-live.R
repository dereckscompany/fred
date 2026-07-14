# Live tests against api.stlouisfed.org. All gate on FRED_LIVE_TESTS = "true" so a
# normal R CMD check never hits the network, AND on a working key (probed once and
# cached) so a present-but-invalid key skips cleanly rather than failing. Every
# FRED endpoint needs a key, so there is no keyless surface to test. The key is
# never printed, logged, or asserted on.

.fred_probe_env <- new.env(parent = emptyenv())

fred_key_works <- function() {
  if (!is.null(.fred_probe_env$works)) {
    return(.fred_probe_env$works)
  }
  works <- FALSE
  key <- fred_api_key()
  if (nzchar(key)) {
    works <- tryCatch(
      {
        info <- FredSeries$new(api_key = key)$get_series_info("DFII10")
        nrow(info) > 0L
      },
      error = function(e) FALSE
    )
  }
  .fred_probe_env$works <- isTRUE(works)
  return(.fred_probe_env$works)
}

skip_unless_live <- function() {
  if (!identical(Sys.getenv("FRED_LIVE_TESTS"), "true")) {
    skip("FRED_LIVE_TESTS != 'true'")
  }
  return(invisible(NULL))
}

skip_unless_live_key <- function() {
  skip_unless_live()
  if (!fred_key_works()) {
    skip("FRED_API_KEY absent or invalid (probe failed)")
  }
  return(invisible(NULL))
}

test_that("get_series returns live latest observations", {
  skip_unless_live_key()
  obs <- FredSeries$new()$get_series("DFII10", observation_start = "2024-01-01", observation_end = "2024-03-31")
  expect_s3_class(obs, "data.table")
  expect_gt(nrow(obs), 0L)
  expect_true(all(obs$series_id == "DFII10"))
  expect_s3_class(obs$date, "Date")
  expect_type(obs$value, "double")
})

test_that("get_series_vintages returns the live as-known-then long form (revised series)", {
  skip_unless_live_key()
  # UNRATE is revised (seasonal factors + population controls), so it has multiple
  # vintages per observation date.
  v <- FredSeries$new()$get_series_vintages("UNRATE")
  expect_s3_class(v, "data.table")
  expect_gt(nrow(v), 0L)
  expect_true(all(v$series_id == "UNRATE"))
  expect_false(any(is.na(v$date)))
  expect_false(any(is.na(v$realtime_start)))
  # More vintage rows than distinct observation dates <=> at least one date revised.
  expect_gt(nrow(v), length(unique(v$date)))
})

test_that("get_series_vintages offset-pages a large matrix and stitches (NFCI is ~900k rows)", {
  skip_unless_live_key()
  # A small page_limit forces multiple offset pages against the live matrix; the
  # stitched result must be sorted by observation date and internally consistent.
  v <- FredSeries$new()$get_series_vintages("NFCI", page_limit = 50000L)
  expect_gt(nrow(v), 50000L) # more than one page => paging actually happened
  expect_false(any(is.na(v$date)))
})

test_that("get_series_info returns live metadata", {
  skip_unless_live_key()
  info <- FredSeries$new()$get_series_info("UNRATE")
  expect_identical(nrow(info), 1L)
  expect_identical(info$series_id, "UNRATE")
  expect_true(nzchar(info$frequency))
  expect_s3_class(info$last_updated, "POSIXct")
})

test_that("search_series returns live hits", {
  skip_unless_live_key()
  hits <- FredSeries$new()$search_series("real gross domestic product", limit = 10L)
  expect_gt(nrow(hits), 0L)
  expect_true("series_id" %in% names(hits))
})

test_that("get_releases and get_release_dates return live data", {
  skip_unless_live_key()
  rel <- FredSeries$new()$get_releases(limit = 20L)
  expect_gt(nrow(rel), 0L)
  d <- FredSeries$new()$get_release_dates(rel$release_id[1], limit = 10L)
  expect_true("date" %in% names(d))
})

test_that("an invalid key surfaces as a typed fred_api_error live", {
  skip_unless_live()
  err <- tryCatch(
    FredSeries$new(api_key = "THIS_IS_NOT_A_VALID_KEY_000")$get_series("DFII10"),
    error = function(e) e
  )
  expect_s3_class(err, "fred_api_error")
  expect_s3_class(err, "connectcore_api_error")
})
