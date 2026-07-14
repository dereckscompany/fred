# Shared test helper: drive a promise to settlement on the local event loop and
# return its value (or re-throw its rejection). Used by the async and pagination
# suites. testthat auto-sources helper-*.R before the tests.

resolve_promise <- function(p) {
  done <- FALSE
  val <- NULL
  err <- NULL
  promises::then(
    p,
    onFulfilled = function(v) {
      val <<- v
      done <<- TRUE
      return(invisible(NULL))
    },
    onRejected = function(e) {
      err <<- e
      done <<- TRUE
      return(invisible(NULL))
    }
  )
  for (i in seq_len(1000L)) {
    if (done) {
      break
    }
    later::run_now(timeout = 0.01)
  }
  if (!is.null(err)) {
    stop(err)
  }
  return(val)
}
