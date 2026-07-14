# The scraper's seam-stitching proof (data-scraper src/fred, PR #63) ported into
# this package. A fully-synthetic output_type=1 long-form matrix; its disjoint
# offset pages MUST reassemble to the un-paged whole with no clip, skip, or
# duplicate -- proven here offline, with no network, for both the synchronous and
# the asynchronous pager, and once more end-to-end through the client transport.

box::use(connectcore[local_mock_api])

# A fully-synthetic output_type=1 long-form matrix: n rows shaped exactly like
# FRED's real response element {realtime_start, realtime_end, date, value}, each
# distinct.
synthetic_matrix <- function(n) {
  return(lapply(seq_len(n), function(i) {
    return(list(
      realtime_start = sprintf("2021-%02d-%02d", ((i - 1L) %% 12L) + 1L, ((i - 1L) %% 28L) + 1L),
      realtime_end = "9999-12-31",
      date = sprintf("20%02d-01-01", i %% 100L),
      value = as.character(i / 10)
    ))
  }))
}

# A FRED-like server over `rows` that returns PARSED pages (data.tables): at most
# `limit` rows from `offset`, and an empty page past the end -- exactly how offset
# pagination behaves live. Counts its invocations so a test can assert it paged.
make_fetch <- function(rows, limit) {
  calls <- 0L
  fetch <- function(offset) {
    calls <<- calls + 1L
    page <- list()
    if (offset < length(rows)) {
      page <- rows[(offset + 1L):min(offset + limit, length(rows))]
    }
    return(parse_fred_observations(list(observations = page), "SYN"))
  }
  return(list(fetch = fetch, calls = function() calls))
}

# A sink that concatenates the parsed pages it is handed, so a test can assert the
# streamed pages reassemble to the unchunked whole.
collecting_sink <- function() {
  pages <- list()
  sink <- function(page) {
    pages[[length(pages) + 1L]] <<- page
    return(invisible(NULL))
  }
  return(list(sink = sink, stitched = function() data.table::rbindlist(pages)))
}

test_that("fred_stream_pages streams offset pages that reassemble to the unchunked whole (seam proof)", {
  rows <- synthetic_matrix(25L)
  whole <- parse_fred_observations(list(observations = rows), "SYN")
  srv <- make_fetch(rows, 10L)
  acc <- collecting_sink()
  total <- fred_stream_pages(srv$fetch, 10L, acc$sink, is_async = FALSE)
  expect_equal(total, 25L)
  expect_equal(acc$stitched(), whole) # order-preserving: no clip, no skip, no dupe
  expect_equal(srv$calls(), 3L) # 10 + 10 + 5: it actually paged
})

test_that("fred_stream_pages handles an exact-multiple seam (a trailing empty page)", {
  rows <- synthetic_matrix(20L)
  whole <- parse_fred_observations(list(observations = rows), "SYN")
  srv <- make_fetch(rows, 10L)
  acc <- collecting_sink()
  total <- fred_stream_pages(srv$fetch, 10L, acc$sink, is_async = FALSE)
  expect_equal(total, 20L)
  expect_equal(acc$stitched(), whole)
  expect_equal(srv$calls(), 3L) # 10 + 10 + 0 (the boundary probe), then stops
})

test_that("fred_stream_pages does a single request when the series fits one page", {
  rows <- synthetic_matrix(7L)
  srv <- make_fetch(rows, 100L)
  acc <- collecting_sink()
  total <- fred_stream_pages(srv$fetch, 100L, acc$sink, is_async = FALSE)
  expect_equal(total, 7L)
  expect_equal(srv$calls(), 1L)
})

test_that("fred_stream_pages stitches identically over the async (promise) transport", {
  skip_if_not_installed("promises")
  skip_if_not_installed("later")
  rows <- synthetic_matrix(25L)
  whole <- parse_fred_observations(list(observations = rows), "SYN")

  sync_srv <- make_fetch(rows, 10L)
  sync_acc <- collecting_sink()
  fred_stream_pages(sync_srv$fetch, 10L, sync_acc$sink, is_async = FALSE)

  base_srv <- make_fetch(rows, 10L)
  async_fetch <- function(offset) promises::promise_resolve(base_srv$fetch(offset))
  async_acc <- collecting_sink()
  p <- fred_stream_pages(async_fetch, 10L, async_acc$sink, is_async = TRUE)
  expect_true(inherits(p, "promise"))
  total <- resolve_promise(p)
  expect_equal(total, 25L)
  expect_equal(async_acc$stitched(), sync_acc$stitched()) # async == sync stitching
  expect_equal(async_acc$stitched(), whole)
})

test_that("get_series_vintages pages through the client transport and stitches (method-level)", {
  # A STATEFUL output_type=1 route: page 1 (2 rows), page 2 (2 rows), then the
  # empty boundary page. With page_limit = 2 the method must fetch all three.
  counter <- 0L
  paged <- function() {
    counter <<- counter + 1L
    body <- switch(
      as.character(counter),
      "1" = list(
        observations = list(
          list(realtime_start = "2024-01-08", realtime_end = "9999-12-31", date = "2024-01-01", value = "100"),
          list(realtime_start = "2024-01-08", realtime_end = "9999-12-31", date = "2024-01-08", value = "101")
        )
      ),
      "2" = list(
        observations = list(
          list(realtime_start = "2024-01-15", realtime_end = "9999-12-31", date = "2024-01-15", value = "102"),
          list(realtime_start = "2024-01-22", realtime_end = "9999-12-31", date = "2024-01-22", value = "103")
        )
      ),
      list(observations = list())
    )
    return(body)
  }
  local_mock_api(list(list(pattern = "output_type=1", fixture = paged)))
  client <- FredSeries$new(api_key = "test-key")
  v <- client$get_series_vintages("NFCI", page_limit = 2L)
  expect_identical(nrow(v), 4L) # two 2-row pages stitched across the seam
  expect_equal(v$value, c(100, 101, 102, 103))
  expect_identical(counter, 3L) # page 1 + page 2 + the empty boundary probe
})
