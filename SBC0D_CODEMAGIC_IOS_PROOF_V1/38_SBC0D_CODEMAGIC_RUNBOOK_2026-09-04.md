# SBC-0D Codemagic iOS Proof — browser/cloud-Mac route

This repository snapshot replaces the earlier local-Mac SBC-0D package for users who do not own a Mac.

## What it proves
1. Exact SBC-0C-approved Shark facade is unchanged.
2. Exact SBC-0C-reviewed Cargo.lock is unchanged.
3. Exact Beankeeper commit is fetched.
4. Shark foundation compiles for `aarch64-apple-ios` (physical iPhone/iPad ARM64 target).
5. Shark foundation compiles for `aarch64-apple-ios-sim`.
6. Tauri 2 iOS project initialises.
7. Unsigned Tauri iOS Simulator app builds on a real Codemagic macOS/Xcode M2 VM.

No Apple Developer account, certificate, provisioning profile, Mac, iPhone or iPad is required for this gate.

## Browser setup
1. Create a Codemagic **personal** account (not Team) so the 500 free M2 macOS minutes apply.
2. Put all files from this ZIP into the root of a Git repository (GitHub is simplest).
3. In Codemagic: **Add application** → connect the repository → finish adding it.
4. Select the branch and choose **Check for configuration file**. Codemagic must find root-level `codemagic.yaml`.
5. Start workflow **SBC-0D iOS Foundation Proof** / ID `sbc0d-ios-foundation-proof`.
6. When the build finishes, download artifact `SBC0D_CODEMAGIC_RESULT_<timestamp>.zip` and upload it to the Shark Books ChatGPT thread.

## Do not add
- Apple signing credentials
- App Store Connect credentials
- paid Codemagic machine types
- dependency upgrades
- source modifications

If the build fails, upload the result ZIP unchanged. The harness classifies the exact phase.
