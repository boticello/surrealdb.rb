# Code Review Checklist

Use this checklist when reviewing pull requests to the SurrealDB Ruby SDK.

## Thread Safety

- [ ] All shared mutable state is protected by a `Mutex`
- [ ] No race conditions in request ID generation or pending-request routing
- [ ] Background reader thread is properly joined/killed on `close`
- [ ] No deadlocks between the reader thread and `send_request` callers
- [ ] WebSocket frame writes are serialized via `@write_mutex`
- [ ] Live query handlers are registered/removed under the connection mutex
- [ ] Reader thread EOF/error paths push `:closed` onto all pending queues

## Memory and Resource Management

- [ ] Sockets are closed in all error paths (use `ensure` blocks)
- [ ] Background threads are stopped when the connection closes
- [ ] No references held to closed connections or sockets
- [ ] ConditionVariable entries for pending requests are cleaned up after use
- [ ] Live query notification handlers are removed when `kill` is called
- [ ] Embedded FFI: every `sr_surreal_rpc_execute` response buffer is freed with `sr_free_byte_arr`
- [ ] Embedded FFI: every error string is freed with `sr_free_string`
- [ ] Embedded FFI: close calls `sr_rpc_stream_close`, joins the reader, frees the stream exactly once on the owner thread, then calls `sr_surreal_rpc_free`

## Error Handling

- [ ] Malformed WebSocket messages are logged at `:warn` level (not silently dropped)
- [ ] Server errors are mapped to the correct `ServerError` subclass based on `kind`
- [ ] Both legacy (code + message) and v3 structured (kind + details + cause) error formats are handled
- [ ] `ConnectionError` is raised when operations are attempted on a closed connection
- [ ] `TimeoutError` is raised with a clear message including the timeout duration
- [ ] `UnsupportedError` is raised for live queries, sessions, and transactions on HTTP connections
- [ ] Cause chains are preserved and traversable via `#server_cause` and `#find_cause`
- [ ] `send_rpc` validates that `method` is a non-empty String

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

## Sessions and Transactions

- [ ] `attach`/`detach`/`begin_transaction`/`commit`/`cancel` raise `UnsupportedError` on HTTP
- [ ] Transaction state is not leaked across unrelated operations
- [ ] `detach` accepts a session ID parameter

## Reconnection (ReliableWebSocket)

- [ ] State tracking intercepts `use`, `signin`/`signup`/`authenticate`, `let`/`unset`
- [ ] State replay re-authenticates before calling `use`
- [ ] Exponential backoff respects `max_retries` and `reconnect_delay`
- [ ] Live query handlers are re-registered after reconnect
- [ ] Failed reconnection raises the original `ConnectionError`, not a reconnect-internal error
- [ ] Credentials stored for replay are not leaked via inspect/to_s/logs

## Embedded FFI

- [ ] All FFI calls use `blocking: true` to release the GVL
- [ ] `SR_FATAL` (-3) sets `@connected = false` and raises `ConnectionError`
- [ ] `SR_ERROR` (-2) raises `ServerError` with the error string from `err_ptr`
- [ ] Embedded live-query handlers are synchronized and native stream close wakes every blocking reader before ownership is freed
- [ ] Platform detection handles macOS, Linux, and Windows
- [ ] `SURREALDB_LIB_PATH` env var is checked before system library path

## Async / Fiber Compatibility

- [ ] WebSocket `send_request` uses `ConditionVariable#wait` (not busy-wait polling)
- [ ] `ConditionVariable#wait` receives a timeout to prevent indefinite blocking
- [ ] Reader thread signals `entry[:cv].signal` under the mutex
- [ ] `notify_pending_closed` signals all pending CVs so blocked fibers wake up

## Security

- [ ] TLS certificate verification is enabled for `wss://` and `https://` connections
- [ ] Credentials are not logged or included in error messages
- [ ] Auth tokens are not leaked in exception backtraces
- [ ] Logger output does not contain credentials or tokens
- [ ] Input strings are validated before being sent to the server

## Performance

- [ ] No unnecessary object allocations in the hot path (encode/decode)
- [ ] HTTP connections reuse `Net::HTTP` persistent connections
- [ ] WebSocket uses `ConditionVariable` signaling (no busy-wait CPU spin)
- [ ] WebSocket reader thread uses `readpartial` (not byte-at-a-time reads)
- [ ] Embedded FFI uses zero-copy byte passing where possible
- [ ] CBOR encoding avoids redundant deep-copies of data
- [ ] Request routing uses O(1) Hash lookup, not linear scan
