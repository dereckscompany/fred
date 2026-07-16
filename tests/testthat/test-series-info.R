# get_series_info and search_series: the metadata surface. Both flow through the
# same seriess-element parser (search adds group_popularity); one row vs many.

box::use(./mock_router[.mock_routes])

test_that("get_series_info returns typed one-row metadata", {
  connectcore::local_mock_api(.mock_routes)
  client <- FredSeries$new(api_key = "test-key")
  info <- client$get_series_info("UNRATE")
  expect_s3_class(info, "data.table")
  expect_identical(nrow(info), 1L)
  expect_identical(info$series_id, "UNRATE")
  expect_identical(info$frequency, "Monthly")
  expect_s3_class(info$observation_start, "Date")
  expect_s3_class(info$last_updated, "POSIXct")
  expect_false(is.na(info$last_updated)) # the "-05" offset timestamp parses
  # The faithful raw string sits alongside the parsed value, byte-for-byte as FRED sent it.
  expect_type(info$last_updated_raw, "character")
  expect_identical(info$last_updated_raw, "2026-07-03 07:48:03-05")
  expect_type(info$popularity, "integer")
  expect_true(is.na(info$group_popularity)) # the metadata endpoint omits it -> NA
})

test_that("search_series returns many rows with group_popularity, and a null notes as NA", {
  connectcore::local_mock_api(.mock_routes)
  client <- FredSeries$new(api_key = "test-key")
  hits <- client$search_series("real gdp")
  expect_identical(nrow(hits), 2L)
  expect_true(all(c("GDPC1", "GDP") %in% hits$series_id))
  expect_type(hits$group_popularity, "integer")
  expect_false(any(is.na(hits$group_popularity)))
  expect_true(is.na(hits$notes[hits$series_id == "GDP"])) # JSON null -> NA
  # Every row carries FRED's raw last_updated string verbatim, alongside the parsed value.
  expect_type(hits$last_updated_raw, "character")
  expect_identical(hits$last_updated_raw[hits$series_id == "GDPC1"], "2026-06-26 07:52:01-05")
})

test_that("search_series rejects an unknown search_type before any request", {
  client <- FredSeries$new(api_key = "test-key")
  err <- tryCatch(client$search_series("gdp", search_type = "nonsense"), error = function(e) e)
  expect_s3_class(err, "fred_validation_error")
  expect_match(conditionMessage(err), "search_type")
})
