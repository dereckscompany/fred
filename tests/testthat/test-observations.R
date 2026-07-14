# get_series and the observations parser: the "." missing-value trap, the typed
# columns, and the pre-flight validation. Driven through the shared mock_router
# (the same synthetic fixtures the README renders against).

box::use(./mock_router[.mock_routes])

test_that("get_series round-trips observations, turning '.' into NA (never 0)", {
  connectcore::local_mock_api(.mock_routes)
  client <- FredSeries$new(api_key = "test-key")
  obs <- client$get_series("DFII10")
  expect_s3_class(obs, "data.table")
  expect_named(obs, c("series_id", "date", "value", "realtime_start", "realtime_end"))
  expect_true(all(obs$series_id == "DFII10"))
  expect_s3_class(obs$date, "Date")
  expect_s3_class(obs$realtime_end, "Date")
  expect_type(obs$value, "double")
  expect_equal(obs$value[1], 2.05)
  expect_true(is.na(obs$value[2])) # "." -> NA
  expect_false(isTRUE(obs$value[2] == 0)) # and never 0
})

test_that("parse_fred_observations parses the '9999-12-31' still-current sentinel as a Date", {
  body <- list(
    observations = list(
      list(date = "2024-01-02", value = "2.05", realtime_start = "2024-01-03", realtime_end = "9999-12-31"),
      list(date = "2024-01-03", value = ".", realtime_start = "2024-01-04", realtime_end = "9999-12-31")
    )
  )
  dt <- parse_fred_observations(body, "DFII10")
  expect_identical(as.character(dt$realtime_end[1]), "9999-12-31")
  expect_true(is.na(dt$value[2]))
})

test_that("get_series validates an empty series_id before any request", {
  client <- FredSeries$new(api_key = "test-key")
  err <- tryCatch(client$get_series(""), error = function(e) e)
  expect_s3_class(err, "fred_validation_error")
  expect_s3_class(err, "fred_error")
})
