# Maximum observation rows per FRED response (the offset-page size)

The FRED `series/observations` endpoint caps a single response at
100,000 rows. The ALFRED as-known-then long form of a heavily-revised
series exceeds this (a whole-history financial-conditions index is
~900,000 rows), so `get_series_vintages()` pulls it in disjoint offset
pages of this size (see
[FredSeries](https://dereckscompany.github.io/fred/reference/FredSeries.md)).
It is also the default `limit` a page is requested with.

## Usage

``` r
FRED_MAX_ROWS_PER_PAGE
```

## Format

A `scalar<integer>`.
