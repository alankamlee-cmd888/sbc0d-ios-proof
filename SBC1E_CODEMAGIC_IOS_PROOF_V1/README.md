# SBC-1 consolidated Codemagic Apple proof

This proof repository is reused only as the already-connected Codemagic/macOS execution surface for the official Shark Books Community repository.

Exact official batch target: `3a29ed7607906c0c3c04ceab67dbb51ed973fc7b`

Bounded chain:
- SBC-1E `fe58cef65cc2506dd993360673c72cbce7dbb655`
- SBC-1F `8efc296006f6320a0021bb4f4504b0f2c309122d`
- SBC-1G `3a29ed7607906c0c3c04ceab67dbb51ed973fc7b`
- SBC-1D base `b1ba585c9c739432e3328a7ed1475ae690fb5b9c`

The workflow is unsigned and zero-secret. In one M2 run it verifies the frozen source/lock, both policy guards, the TypeScript browser seam, all `shark-foundation` regressions, physical `aarch64-apple-ios` compilation, and an unsigned `aarch64-sim` Tauri shell build. It does not sign, provision, install on a physical device, publish, or access user data.

This consolidation is intentional to conserve the owner's 500 free Codemagic M2 minutes per month. Public forks are not entitled to this CI resource and should use their own build environment.
