# Typed fred conditions

`fred` raises **classed conditions** so a caller branches on error
*type* and reads structured *fields* instead of matching the message
text.

## Details

### Class taxonomy

- **Transport failures** nest specific -\> general as
  `fred_api_error_<status>` -\> `fred_api_error` -\>
  `connectcore_api_error_<status>` -\> `connectcore_api_error` -\>
  `connectcore_error`, carrying the fields `status` (the HTTP status),
  `error_code` (FRED's own error code from the response body), `url`,
  and `body_snippet`. Raised for any non-2xx HTTP status, including the
  missing/invalid-key case (FRED answers it with a plain HTTP 400 whose
  JSON body names the key problem; unlike some APIs there is no HTML
  redirect to disentangle).

- **Validation failures** nest `fred_validation_error` -\> `fred_error`
  (the domain root). Raised for a malformed argument (an empty
  `series_id`, a `realtime_end` before `realtime_start`, an unknown
  `search_type`) before any request is made.

The `url` is stored with query-string credentials redacted (via
[`connectcore::scrub_url()`](https://dereckscompany.github.io/connectcore/reference/scrub_url.html),
whose sensitive-parameter set matches both `key` and `api_key`), so
logging `e$url` never leaks the FRED key.

## See also

[connectcore::connectcore_conditions](https://dereckscompany.github.io/connectcore/reference/connectcore_conditions.html)
