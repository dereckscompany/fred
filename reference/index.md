# Package index

## The client

The FRED / ALFRED R6 client — observations, vintages, metadata, search,
releases.

- [`FredSeries`](https://dereckscompany.github.io/fred/reference/FredSeries.md)
  : FredSeries: the FRED / ALFRED economic-data client

## Configuration and vocabulary

The URL getter, key reader, and the exported constants.

- [`fred_base_url()`](https://dereckscompany.github.io/fred/reference/fred_base_url.md)
  : FRED / ALFRED API base URL

- [`fred_api_key()`](https://dereckscompany.github.io/fred/reference/fred_api_key.md)
  : Read the FRED API key from the environment

- [`FRED_RPM`](https://dereckscompany.github.io/fred/reference/FRED_RPM.md)
  : FRED free-tier request budget (requests per minute)

- [`FRED_MAX_ROWS_PER_PAGE`](https://dereckscompany.github.io/fred/reference/FRED_MAX_ROWS_PER_PAGE.md)
  : Maximum observation rows per FRED response (the offset-page size)

- [`FRED_REALTIME_MIN`](https://dereckscompany.github.io/fred/reference/FRED_REALTIME_MIN.md)
  : ALFRED earliest real-time-period sentinel

- [`FRED_REALTIME_MAX`](https://dereckscompany.github.io/fred/reference/FRED_REALTIME_MAX.md)
  : ALFRED latest real-time-period sentinel

- [`FRED_OUTPUT_TYPE`](https://dereckscompany.github.io/fred/reference/FRED_OUTPUT_TYPE.md)
  :

  FRED observations `output_type` vocabulary

- [`SORT_ORDER`](https://dereckscompany.github.io/fred/reference/SORT_ORDER.md)
  : Sort-order vocabulary

- [`SEARCH_TYPE`](https://dereckscompany.github.io/fred/reference/SEARCH_TYPE.md)
  :

  Series-search `search_type` vocabulary

## Conditions and shapes

The typed condition family and the documented return shapes.

- [`fred_conditions`](https://dereckscompany.github.io/fred/reference/fred_conditions.md)
  : Typed fred conditions
- [`fred_shapes`](https://dereckscompany.github.io/fred/reference/fred_shapes.md)
  : fred return shapes
