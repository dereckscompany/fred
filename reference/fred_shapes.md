# fred return shapes

Reusable roxyassert `@type` shapes for the parsed fred `data.table`s.
Measurement columns (a published statistic value) are typed `| NA`;
structural columns (ids, dates, real-time-window bounds) are strict.
`fred` is a leaf connector: nothing internal calls a per-shape validator
and no downstream package validates against these shapes, so there is no
`@genassert` and no `@exportassert`; the shapes exist only to be
expanded into each method's own return contract.
