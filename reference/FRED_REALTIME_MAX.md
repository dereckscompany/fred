# ALFRED latest real-time-period sentinel

The ceiling FRED accepts for `realtime_end`. Passing it as the vintage
window's end makes `output_type = 1` return every vintage through the
most recent one; a vintage row whose `realtime_end` equals this value is
**still current** (has not yet been superseded by a later revision).

## Usage

``` r
FRED_REALTIME_MAX
```

## Format

A `scalar<character>` ISO date, `"9999-12-31"`.
