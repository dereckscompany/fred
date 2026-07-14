# get_series_vintages: the headline ALFRED as-known-then surface. The multi-page
# stitching itself is proved in test-pagination.R; here we prove the method wires
# the pager + parser + return contract, keeps distinct vintages of one date, and
# validates the real-time window.

box::use(./mock_router[.mock_routes])

test_that("get_series_vintages returns the as-known-then long form (both vintages of one date)", {
  connectcore::local_mock_api(.mock_routes)
  client <- FredSeries$new(api_key = "test-key")
  v <- client$get_series_vintages("M2SL")
  expect_s3_class(v, "data.table")
  expect_named(v, c("series_id", "date", "value", "realtime_start", "realtime_end"))
  expect_identical(nrow(v), 2L) # two distinct real-time windows of the same date, both kept
  expect_true(all(v$series_id == "M2SL"))
  expect_equal(v$value, c(20800, 20850))
  expect_identical(as.character(v$realtime_end[2]), "9999-12-31") # the current vintage
})

test_that("get_series_vintages rejects an inverted real-time window before any request", {
  client <- FredSeries$new(api_key = "test-key")
  err <- tryCatch(
    client$get_series_vintages("M2SL", realtime_start = "2020-01-01", realtime_end = "2010-01-01"),
    error = function(e) e
  )
  expect_s3_class(err, "fred_validation_error")
  expect_match(conditionMessage(err), "on or before")
})
