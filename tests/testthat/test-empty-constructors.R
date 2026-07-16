# The typed zero-row constructors and the parsers' empty branches: a caller's
# column contract must hold even when nothing comes back.

test_that("empty constructors return zero-row, fully-typed tables", {
  obs <- empty_dt_fred_observations()
  expect_identical(nrow(obs), 0L)
  expect_named(obs, c("series_id", "date", "value", "realtime_start", "realtime_end"))
  expect_s3_class(obs$date, "Date")
  expect_type(obs$value, "double")

  vin <- empty_dt_fred_vintages()
  expect_identical(nrow(vin), 0L)
  expect_named(vin, c("series_id", "date", "value", "realtime_start", "realtime_end"))

  info <- empty_dt_fred_series_info()
  expect_identical(nrow(info), 0L)
  expect_s3_class(info$last_updated, "POSIXct")
  expect_type(info$last_updated_raw, "character")
  expect_s3_class(info$observation_start, "Date")
  expect_type(info$popularity, "integer")

  rel <- empty_dt_fred_releases()
  expect_identical(nrow(rel), 0L)
  expect_type(rel$release_id, "integer")
  expect_type(rel$press_release, "logical")

  rd <- empty_dt_fred_release_dates()
  expect_identical(nrow(rd), 0L)
  expect_named(rd, c("release_id", "date"))
  expect_s3_class(rd$date, "Date")
})

test_that("parsers return the typed empty table on an empty/NULL body", {
  expect_identical(nrow(parse_fred_observations(NULL, "X")), 0L)
  expect_identical(nrow(parse_fred_series_info(NULL)), 0L)
  expect_identical(nrow(parse_fred_releases(NULL)), 0L)
  expect_identical(nrow(parse_fred_release_dates(NULL)), 0L)
})
