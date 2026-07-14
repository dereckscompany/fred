# The typed condition family: the fred_api_error transport chain (layered in front
# of connectcore's), the fred_validation_error domain root, and the key-redaction
# guarantee.

box::use(./mock_router[.mock_routes])

test_that("a FRED HTTP error surfaces as fred_api_error nested into the connectcore chain", {
  connectcore::local_mock_api(.mock_routes)
  client <- FredSeries$new(api_key = "test-key")
  err <- tryCatch(client$get_series("BADSERIES"), error = function(e) e)
  expect_s3_class(err, "fred_api_error_400")
  expect_s3_class(err, "fred_api_error")
  expect_s3_class(err, "connectcore_api_error_400")
  expect_s3_class(err, "connectcore_api_error")
  expect_s3_class(err, "connectcore_error")
  expect_identical(err$status, 400L)
  expect_identical(err$error_code, 400L) # FRED's own body error_code
  expect_match(conditionMessage(err), "does not exist")
})

test_that("abort_fred_error redacts the api_key in the stored url (no key leak)", {
  err <- tryCatch(
    abort_fred_error(
      status = 400L,
      error_code = 400L,
      url = "https://api.stlouisfed.org/fred/series?series_id=X&api_key=SUPERSECRETKEY&file_type=json",
      body = "{}",
      message = "boom"
    ),
    error = function(e) e
  )
  expect_false(grepl("SUPERSECRETKEY", err$url, fixed = TRUE))
  expect_match(err$url, "api_key=<redacted>")
})

test_that("fred_validation_error is the domain root, never a transport error", {
  err <- tryCatch(abort_fred_validation_error("nope"), error = function(e) e)
  expect_s3_class(err, "fred_validation_error")
  expect_s3_class(err, "fred_error")
  expect_false(inherits(err, "connectcore_error"))
})

test_that("an empty api_key warns at construction (metadata-then-fail contract)", {
  expect_warning(FredSeries$new(api_key = ""), "FRED_API_KEY is empty")
})
