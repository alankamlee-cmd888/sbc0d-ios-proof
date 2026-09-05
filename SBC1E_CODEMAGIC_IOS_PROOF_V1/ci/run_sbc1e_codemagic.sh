#!/bin/bash
set -euo pipefail

TARGET_REPO="https://github.com/alankamlee-cmd888/shark-books-community.git"
TARGET_COMMIT="3a29ed7607906c0c3c04ceab67dbb51ed973fc7b"
SBC1F_COMMIT="8efc296006f6320a0021bb4f4504b0f2c309122d"
SBC1E_COMMIT="fe58cef65cc2506dd993360673c72cbce7dbb655"
SBC1D_BASE="b1ba585c9c739432e3328a7ed1475ae690fb5b9c"
BEANKEEPER_PIN="d573db5e61089b0922f95c991732394d08e3cf92"
FACADE_SHA="6274cffc89ccb2fcea4d489e76375c9c5be1e3c8cc2fbd4c4e56b37bdef0ef46"
LOCK_SHA="3239385c688f64120a6701cdf3f603134950902f2591bae6b7be7248388ec4a9"
RUST_TOOLCHAIN="1.98.1"
TAURI_CLI_VERSION="2.11.4"
TYPESCRIPT_VERSION="5.9.3"
ROOT="${CM_BUILD_DIR}/.sbc1-work"
SRC="$ROOT/shark-books-community"
ARTIFACTS="${CM_BUILD_DIR}/artifacts/sbc1"
mkdir -p "$ARTIFACTS"
rm -rf "$SRC"

finish() {
  rc=$?
  {
    echo "batch=SBC-1E-to-1G"
    echo "target_commit=$TARGET_COMMIT"
    echo "sbc1f_commit=$SBC1F_COMMIT"
    echo "sbc1e_commit=$SBC1E_COMMIT"
    echo "sbc1d_base=$SBC1D_BASE"
    echo "beankeeper_pin=$BEANKEEPER_PIN"
    echo "rust_toolchain=$RUST_TOOLCHAIN"
    echo "tauri_cli=$TAURI_CLI_VERSION"
    echo "typescript=$TYPESCRIPT_VERSION"
    echo "result=$([ "$rc" -eq 0 ] && echo PASS || echo FAIL)"
    echo "codemagic_build_id=${CM_BUILD_ID:-unknown}"
  } > "$ARTIFACTS/SUMMARY.txt"
  exit "$rc"
}
trap finish EXIT

printf 'SBC-1 consolidated Apple proof for %s\n' "$TARGET_COMMIT"
uname -a
xcodebuild -version
xcrun --sdk iphoneos --show-sdk-path >/dev/null
xcrun --sdk iphonesimulator --show-sdk-path >/dev/null
node --version
npm --version

# Exact official source and exact bounded commit chain.
git clone --filter=blob:none --no-checkout "$TARGET_REPO" "$SRC"
git -C "$SRC" fetch --depth 4 origin "$TARGET_COMMIT"
git -C "$SRC" checkout --detach "$TARGET_COMMIT"
test "$(git -C "$SRC" rev-parse HEAD)" = "$TARGET_COMMIT"
test "$(git -C "$SRC" rev-parse HEAD^)" = "$SBC1F_COMMIT"
test "$(git -C "$SRC" rev-parse HEAD~2)" = "$SBC1E_COMMIT"
test "$(git -C "$SRC" rev-parse HEAD~3)" = "$SBC1D_BASE"

# Frozen source/lock and no dependency-manifest change across the whole batch.
test "$(shasum -a 256 "$SRC/workspace/shark-foundation/src/lib.rs" | awk '{print $1}')" = "$FACADE_SHA"
test "$(shasum -a 256 "$SRC/workspace/Cargo.lock" | awk '{print $1}')" = "$LOCK_SHA"
git -C "$SRC" diff --exit-code "$SBC1D_BASE" "$TARGET_COMMIT" -- \
  workspace/Cargo.toml \
  workspace/Cargo.lock \
  workspace/shark-foundation/Cargo.toml \
  workspace/shark-foundation/src/lib.rs \
  workspace/shark-tauri-spike/Cargo.toml \
  workspace/shark-tauri-spike/src/lib.rs

python3 "$SRC/scripts/check_frozen_baseline.py"
python3 "$SRC/scripts/check_sbc1_ci_policy.py"

# 1F exact compile/type seam with the frozen policy version.
npx --yes --package "typescript@$TYPESCRIPT_VERSION" tsc -p "$SRC/workspace/browser-adapter-contract/tsconfig.json"

python3 "$SRC/scripts/bootstrap_beankeeper.py"
test "$(git -C "$SRC/upstream/beankeeper" rev-parse HEAD)" = "$BEANKEEPER_PIN"

export PATH="$HOME/.cargo/bin:$PATH"
if ! command -v rustup >/dev/null 2>&1; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain none
  export PATH="$HOME/.cargo/bin:$PATH"
fi
rustup toolchain install "$RUST_TOOLCHAIN" --profile minimal
rustup target add --toolchain "$RUST_TOOLCHAIN" aarch64-apple-ios aarch64-apple-ios-sim
rustup default "$RUST_TOOLCHAIN"
rustc -Vv
cargo -V

# Run all facade regressions once on the Mac host; this includes the new SBC-1G fixtures.
cd "$SRC/workspace"
cargo fetch --locked
cargo test -p shark-foundation --locked

# 1E physical iOS target proof through the exact production facade/shell crates.
cargo check -p shark-foundation --target aarch64-apple-ios --locked
cargo check -p shark-tauri-spike --target aarch64-apple-ios --locked

test "$(shasum -a 256 Cargo.lock | awk '{print $1}')" = "$LOCK_SHA"
python3 "$SRC/scripts/check_frozen_baseline.py"
python3 "$SRC/scripts/check_sbc1_ci_policy.py"

# Unsigned Simulator Tauri shell link/build. No certificates, profiles or publishing.
cd "$SRC/workspace/shark-tauri-spike"
npx --yes "@tauri-apps/cli@$TAURI_CLI_VERSION" --version
rm -rf gen/apple
npx --yes "@tauri-apps/cli@$TAURI_CLI_VERSION" ios init --ci
npx --yes "@tauri-apps/cli@$TAURI_CLI_VERSION" icon icons/icon.png
export CI=true
export CODE_SIGNING_ALLOWED=NO
export CODE_SIGNING_REQUIRED=NO
export CODE_SIGN_IDENTITY=""
npx --yes "@tauri-apps/cli@$TAURI_CLI_VERSION" ios build --target aarch64-sim --debug --ci

test "$(shasum -a 256 "$SRC/workspace/Cargo.lock" | awk '{print $1}')" = "$LOCK_SHA"
python3 "$SRC/scripts/check_frozen_baseline.py"
python3 "$SRC/scripts/check_sbc1_ci_policy.py"

find "$SRC/workspace/shark-tauri-spike/gen/apple" "$SRC/workspace/target" -type d -name '*.app' -print | tee "$ARTIFACTS/app_paths.txt" || true
cp "$SRC/workspace/Cargo.lock" "$ARTIFACTS/Cargo.lock"
git -C "$SRC" show --stat --oneline "$TARGET_COMMIT" > "$ARTIFACTS/target_commit.txt"
git -C "$SRC" diff --name-status "$SBC1D_BASE" "$TARGET_COMMIT" > "$ARTIFACTS/batch_diff.txt"
echo "SBC-1 consolidated Apple proof PASS"
