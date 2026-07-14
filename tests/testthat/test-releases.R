# get_releases and get_release_dates: the release-calendar surface.

box::use(./mock_router[.mock_routes])

test_that("get_releases returns typed releases (press_release logical, missing notes NA)", {
  connectcore::local_mock_api(.mock_routes)
  client <- FredSeries$new(api_key = "test-key")
  rel <- client$get_releases()
  expect_named(rel, c("release_id", "name", "press_release", "link", "notes", "realtime_start", "realtime_end"))
  expect_identical(nrow(rel), 2L)
  expect_type(rel$release_id, "integer")
  expect_type(rel$press_release, "logical")
  expect_true(all(rel$press_release))
  expect_true(is.na(rel$notes[rel$release_id == 10L])) # the first release carries no notes
})

test_that("get_release_dates returns one row per publication date", {
  connectcore::local_mock_api(.mock_routes)
  client <- FredSeries$new(api_key = "test-key")
  d <- client$get_release_dates(10L)
  expect_named(d, c("release_id", "date"))
  expect_identical(nrow(d), 3L)
  expect_s3_class(d$date, "Date")
  expect_true(all(d$release_id == 10L))
})
