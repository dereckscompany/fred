# The async (promise) path must agree with the sync path. The connectcore mock
# harness intercepts req_perform AND req_perform_promise, so the SAME router serves
# both. is_async threads from the constructor through every method's then_or_now()
# tail (and through the vintage pager); these prove a promise is returned and
# resolves to the same table the sync call returns.

box::use(./mock_router[.mock_routes])

test_that("get_series async returns a promise resolving to the sync table", {
  skip_if_not_installed("promises")
  skip_if_not_installed("later")
  connectcore::local_mock_api(.mock_routes)
  sync <- FredSeries$new(api_key = "k", async = FALSE)$get_series("DFII10")
  p <- FredSeries$new(api_key = "k", async = TRUE)$get_series("DFII10")
  expect_true(inherits(p, "promise"))
  expect_equal(resolve_promise(p), sync)
})

test_that("get_series_vintages async agrees with sync (paged through the promise transport)", {
  skip_if_not_installed("promises")
  skip_if_not_installed("later")
  connectcore::local_mock_api(.mock_routes)
  sync <- FredSeries$new(api_key = "k", async = FALSE)$get_series_vintages("M2SL")
  p <- FredSeries$new(api_key = "k", async = TRUE)$get_series_vintages("M2SL")
  expect_true(inherits(p, "promise"))
  expect_equal(resolve_promise(p), sync)
})

test_that("get_series_info and get_releases async agree with sync", {
  skip_if_not_installed("promises")
  skip_if_not_installed("later")
  connectcore::local_mock_api(.mock_routes)
  expect_equal(
    resolve_promise(FredSeries$new(api_key = "k", async = TRUE)$get_series_info("UNRATE")),
    FredSeries$new(api_key = "k", async = FALSE)$get_series_info("UNRATE")
  )
  expect_equal(
    resolve_promise(FredSeries$new(api_key = "k", async = TRUE)$get_releases()),
    FredSeries$new(api_key = "k", async = FALSE)$get_releases()
  )
})

test_that("an async FRED error rejects the promise", {
  skip_if_not_installed("promises")
  skip_if_not_installed("later")
  connectcore::local_mock_api(.mock_routes)
  p <- FredSeries$new(api_key = "k", async = TRUE)$get_series("BADSERIES")
  expect_true(inherits(p, "promise"))
  err <- tryCatch(resolve_promise(p), error = function(e) e)
  expect_s3_class(err, "fred_api_error_400")
})
