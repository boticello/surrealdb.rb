# Code Review Checklist

Use this checklist when reviewing pull requests to the SurrealDB Ruby SDK.

## Thread Safety

- [ ] All shared mutable state is protected by a `Mutex`
- [ ] No race conditions in request ID generation or pending-request routing
- [ ] Background reader thread is properly joined/killed on `close`
- [ ] No deadlocks between the reader thread and `send_request` callers
- [ ] Live query handlers are registered/removed under the connection mutex

## Memory and Resource Management

- [ ] Sockets are closed in all error paths (use `ensure` blocks)
- [ ] Background threads are stopped when the connection closes
- [ ] No references held to closed connections or sockets
- [ ] `Queue` instances for pending requests are cleaned up after use
- [ ] Live query notification handlers are removed when `kill` is called

## Error Handling

- [ ] No exceptions are silently swallowed (except in the reader thread for malformed messages)
- [ ] Server errors are mapped to the correct `ServerError` subclass based on `kind`
- [ ] Both legacy (code + message) and v3 structured (kind + details + cause) error formats are handled
- [ ] `ConnectionError` is raised when operations are attempted on a closed connection
- [ ] `TimeoutError` is raised with a clear message including the timeout duration
- [ ] `UnsupportedError` is raised for live queries on HTTP connections
- [ ] Cause chains are preserved and traversable via `#server_cause` and `#find_cause`

## CBOR Fidelity

- [ ] Every SurrealDB type round-trips correctly through encode → decode
- [ ] `NONE` (tag 6) is distinct from `nil` (CBOR null)
- [ ] `RecordID` IDs can be strings, integers, arrays, or objects
- [ ] `Duration` handles all units (y, w, d, h, m, s, ms, us, ns)
- [ ] `Time` objects preserve nanosecond precision via the compact datetime tag (12)
- [ ] `BigDecimal` values survive round-trip via the decimal string tag (10)
- [ ] Geometry types encode/decode all 7 variants (Point through Collection)
- [ ] Nested structures (Hash/Array containing SurrealDB types) are recursively processed

## Transport Parity

- [ ] WebSocket and HTTP connections return identical results for the same operations
- [ ] HTTP connection correctly sets `surreal-ns`, `surreal-db`, and `Authorization` headers
- [ ] HTTP connection tracks namespace/database/token state from `use`/`signin` calls
- [ ] WebSocket connection properly handles the `/rpc` path

## Backward Compatibility

- [ ] Works with SurrealDB v2.x (legacy error format)
- [ ] Works with SurrealDB v3.x (structured errors, sessions, transactions)
- [ ] Unknown CBOR tags are passed through rather than causing errors
- [ ] Unknown error kinds fall back to `ServerError` rather than crashing

## Security

- [ ] TLS certificate verification is enabled for `wss://` and `https://` connections
- [ ] Credentials are not logged or included in error messages
- [ ] Auth tokens are not leaked in exception backtraces
- [ ] Input strings are validated before being sent to the server

## Performance

- [ ] No unnecessary object allocations in the hot path (encode/decode)
- [ ] HTTP connections reuse `Net::HTTP` persistent connections
- [ ] WebSocket reader thread uses `readpartial` (not byte-at-a-time reads)
- [ ] CBOR encoding avoids redundant deep-copies of data
- [ ] Request routing uses O(1) Hash lookup, not linear scan
