# File: R/pagination.R
# The ALFRED vintage-matrix offset pager -- the one piece of hard-won production
# logic this package absorbs from the data-scraper's src/fred collector (its
# stream_vintage, proven live against NFCI's 906,899-row matrix, PR #63). Ported
# here into typed form: each page is a parsed FredVintages data.table rather than a
# raw record list, and the pager is threaded through connectcore::then_or_now() so
# the SAME stitching logic drives the synchronous and the asynchronous transport.

#' Stream the offset pages of a FRED observations/vintage matrix
#'
#' Pulls a FRED `series/observations` matrix page by page, handing each parsed page
#' to `sink` as it arrives, and returns the total number of rows handed over.
#'
#' @details
#' The ALFRED `output_type = 1` as-known-then long form over a wide real-time
#' window is the honest vintage history -- one row per (observation date,
#' contiguous real-time window). For a series revised across its whole history it
#' exceeds FRED's per-response row cap ([FRED_MAX_ROWS_PER_PAGE], 100,000), so it
#' MUST be pulled in offset pages. FRED returns the rows in a single deterministic
#' total order (observation date ascending, then real-time window), so the disjoint
#' offset pages `[0, limit)`, `[limit, 2*limit)`, ... tile the matrix with no
#' overlap and no gap: the pages `sink` sees, concatenated, are EXACTLY the
#' one-giant-pull row set -- no seam clip, no skip, no duplicate (proven against the
#' live API, where NFCI's 906,899 rows reassemble byte-identical).
#'
#' A page shorter than `page_limit` is the last one; an exact-multiple matrix ends
#' with one empty boundary page, which stops the pull. `fetch_page(offset)` returns
#' a parsed page (a `data.table`) in synchronous mode or a promise resolving to one
#' in asynchronous mode; the whole pager is threaded through
#' [connectcore::then_or_now()] so a single recursion serves both. Because
#' `fetch_page` and `sink` are injected, the stitching is tested offline with no
#' network (see the seam-stitching test).
#'
#' @param fetch_page (function) `function(offset)` returning the parsed page at
#'   that offset -- a `data.table` (sync) or a promise resolving to one (async).
#' @param page_limit (scalar<count in [1, Inf[>) the `limit` each page is requested
#'   with; a page with fewer rows than this is the last.
#' @param sink (function) `function(page)` handed each parsed page as it arrives.
#' @param is_async (scalar<logical>) if `TRUE`, `fetch_page` returns promises and
#'   the pager returns a promise resolving to the total. Default `FALSE`.
#' @return (scalar<integer> | promise<integer>) the total rows streamed, or a
#'   promise thereof.
#' @keywords internal
#' @noassert
#' @noRd
fred_stream_pages <- function(fetch_page, page_limit, sink, is_async = FALSE) {
  pump <- function(offset, total) {
    step <- function(page) {
      sink(page)
      n <- nrow(page)
      new_total <- total + n
      out <- new_total
      if (n >= page_limit) {
        out <- pump(offset + page_limit, new_total)
      }
      return(out)
    }
    return(connectcore::then_or_now(fetch_page(offset), step, is_async = is_async))
  }
  return(pump(0L, 0L))
}
