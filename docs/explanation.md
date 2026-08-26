# Explanation: How Embedded Connections Work

This document explains the architecture of the SurrealDB Ruby embedded
connection — the design decisions, the FFI lifecycle, and the threading
model.

## The embedded connection in the SDK architecture

The SurrealDB Ruby SDK supports three transports: WebSocket, HTTP, and
embedded. All three share the same `Client` API — the transport is selected
by URL scheme and the caller never needs to know which one is active.

```
SurrealDB::Client
  │
  ├── Connections::WebSocket    (ws://, wss://)
  ├── Connections::HTTP          (http://, https://)
  └── Connections::Embedded      (mem://, surrealkv://, file://)
        │
        ├── Native (FFI bindings)
        │     └── libsurrealdb_c.dylib / .so / .dll
        │           └── surrealdb-core (Rust)
        │
        └── CBOR codec (shared with WebSocket)
```

The embedded connection reuses the same CBOR encoder/decoder and RPC
protocol as WebSocket. The difference is that instead of sending bytes
over a network socket, it passes them directly into the C library's
`sr_surreal_rpc_execute` function.

## Why FFI, not a Rust gem?

SurrealDB's core is written in Rust. The `surrealdb.c` project exposes a
C ABI (`cdylib`) that wraps the Rust core with a flat, FFI-friendly
interface. Ruby's `ffi` gem calls into this shared library directly.

This design has three advantages:

1. **No Rust build dependency for gem users.** The shared library is
   pre-built or built once; the Ruby gem only needs `ffi`.
2. **Stable ABI.** The C interface is versioned and explicit. Ruby never
   touches Rust types directly.
3. **Shared codec.** CBOR encoding/decoding happens in Ruby (the same
   code path as WebSocket), so the wire format is identical across
   transports.

## The connection lifecycle

```
Client.new("mem://")
  └── Embedded.new(url, **options)
        ├── validate timeouts (0-255 integer range)
        ├── validate strict option (always false)
        └── normalize URL (file:// → surrealkv://, memory:// → mem://)

client.connect
  └── Embedded#connect
        ├── claim owner thread (first caller wins)
        ├── sr_surreal_rpc_new(err, surreal, url, opts)
        │     └── opens the engine, returns RPC handle
        ├── create NativeResources (owns the handle)
        ├── register GC finalizer (safety net)
        └── start_notification_reader
              ├── sr_surreal_rpc_notifications(rpc, err, stream)
              │     └── opens the notification stream
              └── NotificationReader.start
                    └── background thread reads sr_rpc_stream_next in a loop

client.close
  └── Embedded#close
        ├── verify owner thread
        ├── NativeResources#shutdown
        │     ├── close_stream (sr_rpc_stream_close)
        │     ├── join reader thread
        │     └── release
        │           ├── sr_rpc_stream_free
        │           ├── sr_surreal_rpc_close
        │           └── sr_surreal_rpc_free
        └── reset session/transaction state
```

## CBOR codec

Every RPC request is CBOR-encoded in Ruby, passed as a byte array to the
C library, and every response comes back as a CBOR byte array that Ruby
decodes. This means:

- SurrealDB types (RecordID, Duration, Geometry, Range, NONE) are encoded
  with the same CBOR tags as WebSocket RPC.
- Structured errors (`DbResponse` envelope) are decoded identically.
- The C library is a thin transport — it doesn't interpret the CBOR
  payload, just passes it to/from the SurrealDB core.

## Thread ownership model

An embedded connection is owned by the thread that first calls `#connect`.
This is enforced by `@owner_thread` — a mutex-protected reference set
exactly once. Every public method (`send_request`, `close`, `on_notification`)
calls `verify_owner_thread!` before proceeding.

Why thread-own?

The underlying C library uses a Tokio runtime and blocking FFI calls
(`blocking: true` releases the Ruby GVL). The Tokio runtime is not
designed for concurrent access from multiple Ruby threads. Thread
ownership gives you a clear contract: one connection, one thread.

If you need multiple threads, create one `Client` per thread. Each gets
its own Tokio runtime and native resources.

## Native resource management

`NativeResources` is a separate object that owns the native pointers
(`rpc_ptr`, `stream_ptr`, `reader_thread`). It exists so that a GC
finalizer can release abandoned connections without retaining the
`Embedded` instance itself.

The ownership chain:

```
Embedded instance
  └── @resources (NativeResources)
        ├── @rpc_ptr      → sr_surreal_rpc_close + sr_surreal_rpc_free
        ├── @stream_ptr   → sr_rpc_stream_close + sr_rpc_stream_free
        └── @reader_thread → Thread#join
```

`NativeResources#release` is idempotent — it uses a mutex-guarded
`@released` flag to ensure each pointer is freed exactly once, even if
both `#close` and the GC finalizer fire.

## Notification reader

Live queries produce notifications on a native stream. A background Ruby
thread (`NotificationReader`) reads from this stream in a loop:

1. `sr_rpc_stream_next(stream, res_ptr)` blocks until a notification
   arrives (GVL released).
2. The response bytes are decoded via the shared CBOR codec.
3. The notification is dispatched to the registered handler (a `Proc`
   or `Queue`).
4. If the connection is garbage-collected, the `WeakRef` to the
   `Embedded` instance expires and the reader exits cleanly.

The reader thread is joined during `#close` — the close sequence calls
`sr_rpc_stream_close` first, which unblocks the reader's
`sr_rpc_stream_next`, then joins the thread.

## URL normalization

The embedded connection normalizes user-facing URL schemes to the
schemes the C library expects:

| User writes | C library receives |
|-------------|-------------------|
| `mem://` | `mem://` |
| `memory://` | `mem://` |
| `surrealkv://path` | `surrealkv://path` |
| `file://path` | `surrealkv://path` |

This happens once in `#initialize`, before the URL reaches the C library.
