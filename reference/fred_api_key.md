# Read the FRED API key from the environment

Resolves the `FRED_API_KEY` environment variable, returning an empty
string when unset. Every FRED endpoint requires a key; a request made
with an empty (or invalid) key aborts with a typed
[fred_conditions](https://dereckscompany.github.io/fred/reference/fred_conditions.md)
error at request time (FRED answers with an HTTP 400 whose body names
the key problem).

## Usage

``` r
fred_api_key()
```

## Value

(scalar\<character\>) the API key, or `""` when unset.
