# File: R/conditions.R
# The typed condition family for fred. Two roots, mirroring the fleet split:
#   * fred_api_error   -> layered IN FRONT of connectcore's transport chain, so a
#     caller can catch fred_api_error (any FRED HTTP failure), connectcore_api_error
#     (any HTTP failure fleet-wide), or connectcore_error (any transport failure)
#     and read $status / $error_code / $url / $body_snippet.
#   * fred_validation_error -> fred_error, the connector's DOMAIN root, parallel to
#     connectcore_error and never meeting it (a bad argument is not a transport
#     failure) -- the same split census/coinbase/aisstream use.

#' Typed fred conditions
#'
#' `fred` raises **classed conditions** so a caller branches on error *type* and
#' reads structured *fields* instead of matching the message text.
#'
#' ### Class taxonomy
#'
#' - **Transport failures** nest specific -> general as
#'   `fred_api_error_<status>` -> `fred_api_error` ->
#'   `connectcore_api_error_<status>` -> `connectcore_api_error` ->
#'   `connectcore_error`, carrying the fields `status` (the HTTP status), `error_code`
#'   (FRED's own error code from the response body), `url`, and `body_snippet`.
#'   Raised for any non-2xx HTTP status, including the missing/invalid-key case
#'   (FRED answers it with a plain HTTP 400 whose JSON body names the key problem;
#'   unlike some APIs there is no HTML redirect to disentangle).
#' - **Validation failures** nest `fred_validation_error` -> `fred_error` (the
#'   domain root). Raised for a malformed argument (an empty `series_id`, a
#'   `realtime_end` before `realtime_start`, an unknown `search_type`) before any
#'   request is made.
#'
#' The `url` is stored with query-string credentials redacted (via
#' [connectcore::scrub_url()], whose sensitive-parameter set matches both `key` and
#' `api_key`), so logging `e$url` never leaks the FRED key.
#'
#' @seealso [connectcore::connectcore_conditions]
#' @name fred_conditions
NULL

#' Raise a typed FRED HTTP API error
#'
#' Signals a condition classed
#' `c("fred_api_error_<status>", "fred_api_error",`
#' `"connectcore_api_error_<status>", "connectcore_api_error", "connectcore_error")`
#' carrying the HTTP `status`, FRED's own `error_code` from the response body, the
#' request `url` (query-string credentials redacted with [connectcore::scrub_url()]),
#' and a truncated `body_snippet`. See [fred_conditions] for the taxonomy.
#'
#' @param status (scalar<count in [100, 599]>) the HTTP status code. Also names the
#'   most specific classes.
#' @param error_code (scalar<count> | NULL) FRED's own `error_code` from the JSON
#'   error body, when present. Default `NULL`.
#' @param url (scalar<character> | NULL) the request URL; credentials are redacted
#'   before storing. Default `NULL`.
#' @param body (scalar<character> | NULL) the response body text; stored truncated
#'   on the `body_snippet` field (named `body_snippet`, not `body`, because
#'   `rlang::abort()` reserves `body`). Default `NULL`.
#' @param message (scalar<character>) the condition message.
#' @return (class<connectcore_error>) never returns normally; signals the classed
#'   condition described above.
#' @importFrom rlang abort caller_env
#' @keywords internal
#' @noassert
#' @noRd
abort_fred_error <- function(status, error_code = NULL, url = NULL, body = NULL, message) {
  code <- if (is.null(error_code)) NA_integer_ else as.integer(error_code)
  return(rlang::abort(
    message = message,
    class = c(
      sprintf("fred_api_error_%d", as.integer(status)),
      "fred_api_error",
      sprintf("connectcore_api_error_%d", as.integer(status)),
      "connectcore_api_error",
      "connectcore_error"
    ),
    status = as.integer(status),
    error_code = code,
    url = connectcore::scrub_url(url),
    body_snippet = body,
    call = rlang::caller_env()
  ))
}

#' Raise a typed FRED input-validation error
#'
#' Signals a condition classed `c("fred_validation_error", "fred_error")` for a
#' NON-transport failure: an argument is malformed or violates a rule before any
#' request is made. `fred_error` is the connector's DOMAIN root, parallel to the
#' transport `connectcore_error` root; the two never meet. See [fred_conditions]
#' for the taxonomy.
#'
#' @param message (scalar<character>) the condition message, passed through
#'   verbatim to [rlang::abort()].
#' @param ... structured fields stored on the condition, read with `e[["field"]]`.
#' @param call (environment) the environment blamed in the traceback; defaults to
#'   the caller.
#' @return (class<fred_error>) never returns normally; signals the classed
#'   condition described above.
#' @importFrom rlang abort caller_env
#' @keywords internal
#' @noassert
#' @noRd
abort_fred_validation_error <- function(message, ..., call = rlang::caller_env()) {
  return(rlang::abort(
    message = message,
    class = c("fred_validation_error", "fred_error"),
    ...,
    call = call
  ))
}
