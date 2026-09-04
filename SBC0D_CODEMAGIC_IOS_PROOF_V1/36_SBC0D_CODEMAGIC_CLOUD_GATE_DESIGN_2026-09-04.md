# SBC-0D Codemagic cloud gate design — 2026-09-04

## Decision
Replace the local-Mac execution route with a Codemagic personal-account M2 workflow because the user has no Mac. The evidential target is unchanged.

## Frozen inputs
- Beankeeper: `d573db5e61089b0922f95c991732394d08e3cf92`
- Shark facade SHA-256: `2c679b0fd5e146e2f82050a32e047c48fa9aa02d386964f8b307c2cae68fb87b`
- SBC-0C reviewed Cargo.lock SHA-256: `3239385c688f64120a6701cdf3f603134950902f2591bae6b7be7248388ec4a9`
- Rust: `1.98.1`
- Tauri core: `2.11.5`
- Tauri CLI: `2.11.4`
- tauri-build: `2.6.3`
- Codemagic: `mac_mini_m2`, Xcode `26.4`, CocoaPods default.

## Mandatory gates
CM0 host/Xcode/SDK/disk preflight.
CM1 exact Rust toolchain and Apple targets.
CM2 facade/pin/reviewed-lock integrity and locked metadata resolution.
CM3 physical-device `aarch64-apple-ios` foundation compile.
CM4 `aarch64-apple-ios-sim` foundation compile.
CM5 exact Tauri CLI.
CM6 unsigned Tauri iOS simulator init/icon/build.

## Distribution boundary
This is a compile/portability gate only. It deliberately excludes Apple Developer enrolment, provisioning, App Store Connect and device installation. Those are distribution concerns, not SBC-0 foundation selection concerns.

## Failure discipline
No automatic dependency upgrades, source patches, Cargo clean, or fallback toolchain changes. A failed build must emit a result ZIP and be adjudicated before changes.
