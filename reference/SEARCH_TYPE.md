# Series-search `search_type` vocabulary

The accepted values of the `series/search` endpoint's `search_type`
parameter:

- `full_text`: match the search text against series attributes (title,
  units, frequency, ...) and rank by relevance. The default.

- `series_id`: substring-match the search text against the series id
  only.

## Usage

``` r
SEARCH_TYPE
```

## Format

A named `list` of `scalar<character>` values: `full_text`, `series_id`.
