Actual `dmdt gs` output could not be produced in user-mode without a QNX runtime
build; the keep_map arbiter probes it via `popen` and looks for the stock
displayable id as a standalone word. Provide a real capture from any unit here
as `dmdt_gs_<train>.txt` (do not commit firmware), then build a host test that
parses it against the same string rules used by `keep_map_stock_seen()`:
1. the grep finds `^{restore_displayable}$` as an exact decimal word token;
2. if that exact string appears nowhere, the probe returns "not seen".
