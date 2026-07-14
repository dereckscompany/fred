# ALFRED earliest real-time-period sentinel

The floor FRED accepts for `realtime_start`. Passing it as the vintage
window's start makes `output_type = 1` return every vintage from the
beginning of the series' archival record.

## Usage

``` r
FRED_REALTIME_MIN
```

## Format

A `scalar<character>` ISO date, `"1776-07-04"`.
