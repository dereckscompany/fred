# parse_fred_response (the .parse_envelope seam) in isolation: FRED's honest error
# surface (a real non-2xx status + a JSON {error_code, error_message} body), the
# success body, and the empty body.

test_that("parse_fred_response raises a typed error carrying FRED's error_code", {
  resp <- httr2::response(
    status_code = 400L,
    headers = list("content-type" = "application/json"),
    body = charToRaw("{\"error_code\":400,\"error_message\":\"Bad Request.  Variable api_key is not set.\"}")
  )
  err <- tryCatch(parse_fred_response(resp), error = function(e) e)
  expect_s3_class(err, "fred_api_error_400")
  expect_s3_class(err, "connectcore_api_error")
  expect_identical(err$error_code, 400L)
  expect_match(conditionMessage(err), "api_key is not set")
})

test_that("parse_fred_response returns the parsed body on success", {
  resp <- httr2::response(
    status_code = 200L,
    headers = list("content-type" = "application/json"),
    body = charToRaw("{\"seriess\":[{\"id\":\"X\"}]}")
  )
  parsed <- parse_fred_response(resp)
  expect_equal(parsed$seriess[[1]]$id, "X")
})

test_that("parse_fred_response returns NULL on an empty body", {
  resp <- httr2::response(
    status_code = 200L,
    headers = list("content-type" = "application/json"),
    body = charToRaw("")
  )
  expect_null(parse_fred_response(resp))
})
