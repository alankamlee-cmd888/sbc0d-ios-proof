# SBC-0D Codemagic package validation — 2026-09-04

Status: **READY TO RUN — NOT PASS**

Static/package validation completed before release.

## Checks passed
- `codemagic.yaml` parses as YAML.
- Workflow ID: `sbc0d-ios-foundation-proof`.
- Instance type: `mac_mini_m2`.
- Xcode selection: `26.4`.
- Shell harness passes `bash -n` syntax validation.
- Failure-path smoke test on the non-macOS build host correctly classified `HOST_NOT_MACOS`, exited non-zero, and still generated a result ZIP and summary artifacts.
- Shark facade SHA-256: `2c679b0fd5e146e2f82050a32e047c48fa9aa02d386964f8b307c2cae68fb87b` (matches SBC-0C accepted facade).
- Reviewed Cargo.lock SHA-256: `3239385c688f64120a6701cdf3f603134950902f2591bae6b7be7248388ec4a9` (matches SBC-0C reviewed dependency graph).
- Critical locked versions rechecked: Beankeeper 0.4.0; beankeeper-cli 0.8.0; rusqlite 0.39.0; openssl-sys 0.9.112; openssl-src 300.5.4+3.5.4; Tauri 2.11.5; tauri-build 2.6.3.
- Tauri application layer static scan remains facade-only (no intended raw SQLite/Beankeeper persistence import).
- No signing/App Store credentials are required by the workflow.
- Artifact collection includes the machine-readable evidence ZIP and any generated simulator `.app`.

## Runtime-only evidence still required
A real Codemagic M2/macOS/Xcode execution must prove:
1. `aarch64-apple-ios` Shark foundation compile;
2. `aarch64-apple-ios-sim` Shark foundation compile;
3. Tauri iOS init;
4. unsigned Tauri iOS simulator build;
5. reviewed Cargo.lock remains unchanged.

No claim of SBC-0D PASS is made until that artifact is returned and adjudicated.
