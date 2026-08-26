# Changelog

## [Unreleased]

### Added

- Opt-in `surrealdb-embedded` gem with real `mem://`, `surrealkv://`, and
  `file://` integration coverage
- Explicit embedded query and transaction timeout options
- Platform-specific native library diagnostics and embedded CI build
- Embedded query, live-query, session, and transaction support through the
  canonical SurrealDB core RPC machinery

### Changed

- Embedded connections now enforce one-client-per-thread ownership
- Embedded connections use the canonical `DbResponse` envelope and carry
  explicit session and transaction IDs
- The base `surrealdb` gem no longer packages embedded or native files

### Fixed

- Native response and error buffers are always released, including decode
  failures
- Embedded notification close wakes and joins a blocking reader before freeing
  native stream ownership
- Canonical CBOR tags and structured RPC errors now survive the native boundary
- Closing an embedded SurrealKV context releases its path for same-process reuse
- `file://` embedded URLs use the available SurrealKV engine

## [0.7.0] - 2026-04-01

### Added

- Initial SDK implementation with WebSocket and HTTP transports
- CBOR serialization with custom SurrealDB type tags
- Full CRUD operations (create, select, insert, update, upsert, merge, patch, delete)
- Raw SurrealQL query support with parameterized variables
- Authentication (signin, signup, authenticate, invalidate)
- Live query support over WebSocket
- SurrealDB types: RecordID, Table, Duration, None, Range, Geometry
- Structured error hierarchy matching SurrealDB server errors
