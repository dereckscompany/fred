# FRED free-tier request budget (requests per minute)

FRED throttles at 120 requests per minute per API key. Exposed so a
caller can set the client's `throttle_rate` from it (120 / 60 = 2
requests/second).

## Usage

``` r
FRED_RPM
```

## Format

A `scalar<integer>`.
