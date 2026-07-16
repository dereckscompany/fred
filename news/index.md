# Changelog

## fred 0.2.0

CRAN release: 2026-04-11

`get_series_info()` and `search_series()` now also carry FRED’s raw
`last_updated` string alongside the parsed timestamp.

In plain English: FRED reports when a series was last updated as a
string like `"2026-07-03 07:48:03-05"` — a timestamp with a UTC offset
baked in. The typed table has always parsed that into a clean UTC
`POSIXct`, which is the right value for analysis but discards the
exchange’s own wording. A point-in-time archive wants what FRED actually
sent, verbatim, so this release adds the raw string as a new column
beside the parsed one — the parsed value is unchanged, nothing is
removed, and the archive can now keep the venue’s own representation.

- `FredSeriesInfo` gains a `last_updated_raw` (character \| NA) column:
  FRED’s `last_updated` field exactly as sent, preserved byte-for-byte.
  It sits directly after the parsed `last_updated` (POSIXct \| NA),
  which is unchanged and still parsed from the same string. Populated by
  both `get_series_info()` and `search_series()` (they share the
  seriess-element parser). Additive only — every existing column keeps
  its name, type, and position.

## fred 0.1.0

Initial release: the St. Louis Fed’s FRED and ALFRED economic data in
the fleet’s connector idiom, built vintage-first.

In plain English: this package fetches official US economic statistics —
GDP, unemployment, money supply, financial-conditions indices, the
dollar, Treasury yields — through one typed, tested interface that works
both synchronously and asynchronously. Unlike the general-purpose
alternatives, it treats *vintages* (what each number was known to be at
each point in the past) as a first-class surface, so a backtest can use
the numbers a trader actually had then rather than today’s revised
history — the difference between an honest backtest and a look-ahead
illusion.

- `FredSeries`: the client, over the shared `connectcore` transport,
  with sync + async threaded from the constructor. Methods:
  `get_series()` (observations at any real-time window — the latest
  values are simply today’s window, never a separate code path);
  `get_series_vintages()` (the headline — the ALFRED `output_type=1`
  as-known-then long form); `get_series_info()` (metadata, including the
  revision-cadence notes); `search_series()`; `get_releases()`; and
  `get_release_dates()`.
- Vintage-first, point-in-time honest. `get_series_vintages()` returns
  one row per (observation date, real-time window), each carrying the
  value current during that window; a `realtime_end` of `"9999-12-31"`
  means still current. The whole-history matrix of a heavily-revised
  series exceeds FRED’s 100,000-row response cap, so it is pulled in
  disjoint offset pages that stitch back to the un-paged whole with no
  seam clip, skip, or duplicate — the offset-pager logic proven live in
  the data-scraper’s src/fred collector (NFCI’s 906,899 rows reassemble
  byte-identical) is ported here into typed form, and its seam-stitching
  proof is a unit test.
- Faithful typed shapes (`FredObservations`, `FredVintages`,
  `FredSeriesInfo`, `FredReleases`, `FredReleaseDates`) with every
  column documented as typed bullets — the observation value is
  `numeric | NA` because FRED serves `.` for a missing observation
  (which becomes `NA`, never `0`); the observation date and
  real-time-window bounds are structural and strict.
- Typed conditions from birth: `fred_api_error` layered in front of the
  `connectcore` transport chain (carrying `status`, FRED’s own body
  `error_code`, a key-redacted `url`, and a `body_snippet`);
  `fred_validation_error` under the `fred_error` domain root. A test
  proves the API key is redacted from every stored URL.
- Grounded against the live API’s error envelope (a real non-2xx status
  plus a JSON `{error_code, error_message}` body — a missing/invalid key
  is a plain HTTP 400, no HTML redirect to disentangle) and
  fully-synthetic mock fixtures offline. Live tests (`get_series`,
  vintages, metadata, search, releases) gate on `FRED_LIVE_TESTS` and a
  working key; every FRED endpoint needs a key, so there is no keyless
  surface.
