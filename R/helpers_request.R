# File: R/helpers_request.R
# FRED-specific request machinery layered on connectcore's transport base. The
# generic funnel (sync/async branch, retry, throttle) lives in connectcore; this
# file keeps only what is FRED-specific: the query-parameter key "signing" seam
# and the FRED JSON error envelope.

#' Append the FRED credentials to a request (the `.sign()` seam)
#'
#' The FRED implementation of connectcore's auth-agnostic `.sign(req, keys, ctx)`
#' seam. FRED "signing" is trivial: the credential is a single query-parameter
#' `api_key`, appended to the request together with `file_type=json` (so every
#' call, no matter the caller, asks for the JSON surface this package parses).
#' There is no HMAC or JWT, so `ctx` is unused. An empty key is still appended, so
#' a keyless request reaches FRED and surfaces as a typed [fred_conditions] error
#' (an HTTP 400 naming the key problem) rather than failing silently.
#'
#' @param req (class<httr2_request>) the request to sign.
#' @param keys (list) credentials with an `api_key` field.
#' @return (class<httr2_request>) the request with `api_key=` and `file_type=json`
#'   appended.
#' @importFrom httr2 req_url_query
#' @keywords internal
#' @noRd
fred_sign_key <- function(req, keys) {
  assert_args_fred_sign_key(req, keys)
  return(assert_return_fred_sign_key(
    httr2::req_url_query(req, api_key = keys$api_key, file_type = "json")
  ))
}

#' Parse and validate a FRED API response (the `.parse_envelope()` seam)
#'
#' The FRED implementation of connectcore's `.parse_envelope(resp)` seam. FRED's
#' error surface is simple and honest: it answers every failure with a real non-2xx
#' HTTP status and a JSON body `{"error_code": <n>, "error_message": "<text>"}` (a
#' missing or invalid key is just an HTTP 400 — there is no HTML redirect to
#' disentangle). So:
#' 1. **Non-2xx status**: parse the JSON error body and raise a
#'    `fred_api_error_<status>` carrying FRED's own `error_code` and the
#'    `error_message` as the condition message.
#' 2. **Empty body**: returns `NULL`, which each parser turns into its typed
#'    zero-row `data.table`.
#' 3. **Success**: the parsed JSON body, returned as a nested list.
#'
#' @param resp (class<httr2_response>) the response to parse.
#' @return (list | NULL) the parsed JSON body, or `NULL` for an empty body.
#' @importFrom httr2 resp_status resp_body_string
#' @keywords internal
#' @noRd
parse_fred_response <- function(resp) {
  assert_args_parse_fred_response(resp)
  status <- httr2::resp_status(resp)
  final_url <- resp$url
  body_text <- tryCatch(httr2::resp_body_string(resp), error = function(e) "")

  result <- NULL
  if (status < 200L || status >= 300L) {
    parsed_error <- tryCatch(
      jsonlite::fromJSON(body_text, simplifyVector = FALSE),
      error = function(e) list()
    )
    error_code <- parsed_error[["error_code"]]
    error_message <- parsed_error[["error_message"]]
    message <- if (is.null(error_message)) {
      paste0("FRED HTTP error ", status, if (nzchar(body_text)) paste0("\n", body_text) else "")
    } else {
      as.character(error_message)
    }
    abort_fred_error(
      status = status,
      error_code = error_code,
      url = final_url,
      body = body_text,
      message = message
    )
  } else if (nzchar(trimws(body_text))) {
    result <- tryCatch(
      jsonlite::fromJSON(body_text, simplifyVector = FALSE),
      error = function(e) {
        abort_fred_error(
          status = status,
          url = final_url,
          body = body_text,
          message = paste0("FRED returned a non-JSON body on HTTP ", status, ".")
        )
      }
    )
  }
  return(result)
}
