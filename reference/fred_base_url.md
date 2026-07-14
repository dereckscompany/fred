# FRED / ALFRED API base URL

The single host under which every FRED endpoint is addressed (e.g.
`/fred/series/observations`, `/fred/series`). FRED (latest values) and
ALFRED (as-known-then vintages) are the **same host**, split only by the
`realtime_start` / `realtime_end` and `output_type` query parameters —
there is no separate ALFRED host. Overridable with the `FRED_BASE_URL`
environment variable.

## Usage

``` r
fred_base_url(url = env_or(var, default))
```

## Arguments

- url:

  (scalar\<character\>) an explicit base URL override. Defaults to the
  `FRED_BASE_URL` environment variable, or the public host when unset.

## Value

(scalar\<character\>) the base URL.
