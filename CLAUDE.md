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

4. **Thread safety**: The WebSocket connection uses a Mutex-protected pending-requests Hash and a background reader Thread. Request IDs are generated under a Mutex.

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
