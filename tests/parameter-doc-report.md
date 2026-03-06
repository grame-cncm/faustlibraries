# Parameter Documentation Report

This report lists functions whose parameter documentation is still likely incomplete or not machine-readable enough for the JSON extractor.

Scope filtering applied:
- excluded temporary, `old/`, and `unsupported/` libraries
- focused on likely documentation issues rather than parser limitations on complex signatures

## Summary

- Total likely issues: 14
- `missing_where`: 14

## By File

- `aanl.lib`: 7 issues (`missing_where`: 7)
- `signals.lib`: 1 issues (`missing_where`: 1)
- `wdmodels.lib`: 6 issues (`missing_where`: 6)

## Details

### `aanl.lib`

- `Racos`: `missing_where`
  usage: `_ : Racos(_) : _`
- `Racosh`: `missing_where`
  usage: `_ : Racosh(_) : _`
- `Rasin`: `missing_where`
  usage: `_ : Rasin(_) : _`
- `Rcosh`: `missing_where`
  usage: `_ : Rcosh(_) : _`
- `Rlog`: `missing_where`
  usage: `_ : Rlog(_) : _`
- `Rsqrt`: `missing_where`
  usage: `_ : Rsqrt(_) : _`
- `Rtan`: `missing_where`
  usage: `_ : Rtan(_) : _`
### `signals.lib`

- `cmul`: `missing_where`
  usage: `(r1,i1) : cmul(r2,i2) : (_,_)`
### `wdmodels.lib`

- `builddown`: `missing_where`
  usage: `builddown(A : B)~buildup(A : B);`
- `buildout`: `missing_where`
  usage: `buildout( A : B );`
- `buildtree`: `missing_where`
  usage: `buildtree(A : B);`
- `buildup`: `missing_where`
  usage: `builddown(A : B)~buildup(A : B);`
- `getres`: `missing_where`
  usage: `getres(A : B)~getres(A : B);`
- `parres`: `missing_where`
  usage: `parres((A , B))~parres((A , B));`
