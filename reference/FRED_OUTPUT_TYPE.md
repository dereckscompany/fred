# FRED observations `output_type` vocabulary

The four shapes the `series/observations` endpoint can return, selected
by the `output_type` parameter:

- `by_realtime_period` (1): observations by real-time period — the
  ALFRED as-known-then **long form**, one row per (observation date,
  contiguous real-time window). This is the shape
  `get_series_vintages()` pins, and the shape whose deterministic total
  order lets disjoint offset pages stitch back to the un-paged whole.

- `by_vintage_all` (2): observations by vintage date, all — a **wide**
  matrix (one column per vintage date) this package does not parse.

- `by_vintage_new` (3): observations by vintage date, new and revised
  only.

- `initial_release` (4): initial release only (plus the latest value).

## Usage

``` r
FRED_OUTPUT_TYPE
```

## Format

A named `list` of `scalar<integer>` codes.
