Stack: Rust.

Prioritize:
- Edition 2024 (or 2021 if the MSRV forbids it); document MSRV in README
- `cargo clippy -- -D warnings` clean; `cargo fmt` enforced in CI
- `#![deny(unsafe_op_in_unsafe_fn, clippy::undocumented_unsafe_blocks)]` at crate root
- Error handling: `thiserror` for libraries, `anyhow` for binaries; no `unwrap()` in lib code
- Async: `tokio` with `#[tokio::main(flavor = "current_thread")]` by default; `async-trait` only when needed
- Cancellation safety: document which futures are cancel-safe
- `tracing` + `tracing-subscriber` for structured logs, not `println!`
- Feature flags documented; `--no-default-features` works
- `cargo-audit` in CI; `cargo-deny` for supply chain; dependabot enabled
- `rustls` over `openssl` for TLS (no C toolchain dependency)
- Cross-compilation: `cross` or pre-built targets in CI matrix
- Release binaries: `strip = true`, `lto = "thin"`, `codegen-units = 1`, `panic = "abort"` for size
- API: `#[must_use]` on builder-style methods; `#[non_exhaustive]` on public enums that may grow

Skip "add more tests" — identify specific untested boundaries.
