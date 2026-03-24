# CLAUDE.md

Project context for AI assistants working on the SurrealDB Ruby SDK.

## Commands

```bash
bundle install              # Install dependencies
bundle exec rspec spec/unit # Run unit tests (no server needed)
bundle exec rspec           # Run all non-integration tests
bundle exec rubocop         # Run linter
bundle exec rake            # Run lint + unit tests (default task)

# Integration tests require a running SurrealDB instance:
docker run --rm -p 8000:8000 surrealdb/surrealdb:latest start --user root --pass root --allow-all
bundle exec rspec spec/integration
```

## Architecture

This SDK follows the same connection-interface pattern as the Go (`surrealdb.go`) and Python (`surrealdb.py`) SDKs.

### Layer structure

```
SurrealDB::Client          — Public API (CRUD, query, auth, live queries)
SurrealDB::Protocol::RPC   — RPC request/response framing over CBOR
SurrealDB::CBOR::*         — CBOR encode/decode with custom SurrealDB type tags
SurrealDB::Connections::*  — Transport backends (WebSocket, HTTP)
```

- `Client` is the user-facing class. It delegates all operations to a `Connection`.
- `Protocol::RPC` generates request IDs, encodes requests as CBOR maps `{id, method, params}`, and decodes CBOR responses.
- `CBOR::Encoder` converts Ruby objects (including SurrealDB types) to CBOR bytes. `CBOR::Decoder` reverses the process.
- Connections implement `#connect`, `#close`, and `#send_request(method, params)`.

### Connection types

URL scheme determines the transport:
- `ws://` / `wss://` → `Connections::WebSocket` (background reader thread, live queries)
- `http://` / `https://` → `Connections::HTTP` (synchronous POST to /rpc)

### CBOR custom tags

SurrealDB encodes custom types via numbered CBOR tags. See `lib/surrealdb/cbor/tags.rb` for the full mapping. Key tags: 6=NONE, 7=Table, 8=RecordID, 12=Datetime, 14=Duration, 88-94=Geometry.

## Key design decisions

1. **RPC API over direct C API**: The C library (`surrealdb.c`) exposes both a full C API (~40 functions) and a minimal RPC API (4 functions that pass CBOR bytes). We use the CBOR RPC approach because it keeps the FFI surface tiny and lets us handle all serialization in Ruby. This matches the Go SDK's approach.

2. **CBOR, not JSON**: SurrealDB's RPC protocol uses CBOR for all transports (WebSocket, HTTP, embedded). The `cbor` gem handles encoding/decoding; we add a pre/post-processing step for SurrealDB's custom tagged types.

3. **Structured error hierarchy**: Server errors carry `kind`, `details`, and a `cause` chain matching SurrealDB v3's structured error format. We also handle legacy v2 code+message errors.

4. **Thread safety**: Neither connection type is safe for concurrent use from multiple threads. The WebSocket connection uses a `@write_mutex` to prevent frame corruption and a `@mutex` for pending-request routing, but the overall request lifecycle is not atomic. The HTTP connection shares `Net::HTTP` and header state. Users needing concurrency should use one Client per thread.

5. **Logger**: `SurrealDB.configuration.logger` is wired into both connections. WebSocket logs connection events at `:debug` level and dropped messages at `:warn`. HTTP logs connect/close at `:debug`. The logger must never receive credentials or auth tokens.

6. **`send_rpc` escape hatch**: `Client#send_rpc(method, params)` forwards directly to the connection, letting users call new or undocumented RPC methods without waiting for SDK wrapper methods.

7. **Sessions and transactions** (WebSocket only): `Client#attach`, `#detach`, `#begin_transaction`, `#commit`, `#cancel` wrap the SurrealDB v3 session/transaction RPC methods. These raise `UnsupportedError` on HTTP connections.

## Dependencies

- `cbor` (~> 0.5) — C-extension CBOR codec. `CBOR::Tagged` is used for custom tags.
- `websocket-driver` (~> 0.7) — WebSocket protocol (handshake, framing). Transport-agnostic; we provide the TCP/SSL socket.

## Code conventions

- All files start with `# frozen_string_literal: true`
- YARD doc comments on public methods
- RuboCop enforced (see `.rubocop.yml`)
- RSpec for testing, `describe`/`context`/`it` style
- Integration tests tagged `:integration`, require a Docker SurrealDB instance
- Shared examples in `spec/support/shared_examples.rb` run CRUD/query/auth tests across both transports

## Testing

- **Unit tests** (`spec/unit/`): Test CBOR round-trips, model parsing, RPC encoding, error mapping. No server needed.
- **Integration tests** (`spec/integration/`): Test against a live SurrealDB. Organized by transport (`websocket/`, `http/`). Use shared examples for cross-transport parity.
- **Environment variables**: `SURREALDB_WS_URL`, `SURREALDB_HTTP_URL`, `SURREALDB_USER`, `SURREALDB_PASS`, `SURREALDB_NS`, `SURREALDB_DB`.

## File layout

```
lib/surrealdb.rb                    Entry point
lib/surrealdb/client.rb             Public API
lib/surrealdb/errors.rb             Error hierarchy
lib/surrealdb/models/               RecordID, Table, Duration, None, Range, Geometry
lib/surrealdb/cbor/                 Tags, Encoder, Decoder
lib/surrealdb/protocol/             RPC, Methods, Response
lib/surrealdb/connections/          Base, WebSocket, HTTP
spec/unit/                          Unit tests
spec/integration/                   Integration tests (websocket/, http/)
spec/support/                       Helpers, shared examples
```
