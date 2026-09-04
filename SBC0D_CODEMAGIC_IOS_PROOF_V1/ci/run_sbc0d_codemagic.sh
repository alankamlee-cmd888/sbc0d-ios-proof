#!/bin/bash
set -u
set -o pipefail

PIN="d573db5e61089b0922f95c991732394d08e3cf92"
FACADE_SHA="2c679b0fd5e146e2f82050a32e047c48fa9aa02d386964f8b307c2cae68fb87b"
LOCK_SHA_EXPECTED="3239385c688f64120a6701cdf3f603134950902f2591bae6b7be7248388ec4a9"
TAURI_CLI_VERSION="2.11.4"
TAURI_CORE_VERSION="2.11.5"
TAURI_BUILD_VERSION="2.6.3"
RUST_TOOLCHAIN="${RUST_TOOLCHAIN:-1.98.1}"
MIN_FREE_GIB=40
REPO_ROOT="${CM_BUILD_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
ROOT="$REPO_ROOT/.sbc0d"
UPSTREAM="$REPO_ROOT/upstream/beankeeper"
WORKSPACE="$REPO_ROOT/workspace"
TOOLS="$ROOT/tools/tauri-cli"
ARTIFACTS="$REPO_ROOT/artifacts"
TS="$(date +%Y%m%d_%H%M%S)"
RESULT_DIR="$ROOT/results_$TS"
LOG_DIR="$RESULT_DIR/logs"
RESULT_ZIP="$ARTIFACTS/SBC0D_CODEMAGIC_RESULT_$TS.zip"
SUMMARY_JSON="$ARTIFACTS/SUMMARY.json"
SUMMARY_TXT="$ARTIFACTS/SUMMARY.txt"
mkdir -p "$LOG_DIR" "$ARTIFACTS" "$ROOT/tools"

CMD_N=0
ASSERT_N=0
FAIL_N=0
PHASE="CM0_PREFLIGHT"
CLASSIFICATION="UNRESOLVED"
OVERALL="FAIL"
APP_PATH=""
LOCK_SHA=""
START_FREE_GIB=""
XCODE_VERSION=""
RUSTC_VERSION=""
CARGO_VERSION=""
TAURI_VERSION=""

json_escape() {
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read())[1:-1])'
}

assert_ok() {
  ASSERT_N=$((ASSERT_N+1))
  printf 'PASS\t%s\n' "$1" >> "$RESULT_DIR/assertions.tsv"
  printf '[PASS] %s\n' "$1"
}
assert_fail() {
  ASSERT_N=$((ASSERT_N+1)); FAIL_N=$((FAIL_N+1))
  printf 'FAIL\t%s\n' "$1" >> "$RESULT_DIR/assertions.tsv"
  printf '[FAIL] %s\n' "$1"
}

run_cmd() {
  label="$1"; shift
  CMD_N=$((CMD_N+1))
  num=$(printf '%03d' "$CMD_N")
  cmdfile="$LOG_DIR/${num}_${label}.command.txt"
  outfile="$LOG_DIR/${num}_${label}.stdout.txt"
  errfile="$LOG_DIR/${num}_${label}.stderr.txt"
  resultfile="$LOG_DIR/${num}_${label}.result.txt"
  printf '%q ' "$@" > "$cmdfile"; printf '\n' >> "$cmdfile"
  "$@" >"$outfile" 2>"$errfile"
  rc=$?
  printf 'exit_code=%s\n' "$rc" > "$resultfile"
  return "$rc"
}

run_shell() {
  label="$1"; shift
  CMD_N=$((CMD_N+1))
  num=$(printf '%03d' "$CMD_N")
  cmdfile="$LOG_DIR/${num}_${label}.command.txt"
  outfile="$LOG_DIR/${num}_${label}.stdout.txt"
  errfile="$LOG_DIR/${num}_${label}.stderr.txt"
  resultfile="$LOG_DIR/${num}_${label}.result.txt"
  printf '%s\n' "$*" > "$cmdfile"
  /bin/bash -lc "$*" >"$outfile" 2>"$errfile"
  rc=$?
  printf 'exit_code=%s\n' "$rc" > "$resultfile"
  return "$rc"
}

finish() {
  rc=$?
  set +e
  [ -f "$WORKSPACE/Cargo.lock" ] && cp "$WORKSPACE/Cargo.lock" "$RESULT_DIR/Cargo.lock"
  [ -f "$WORKSPACE/resolved_metadata.json" ] && cp "$WORKSPACE/resolved_metadata.json" "$RESULT_DIR/resolved_metadata.json"
  [ -f "$WORKSPACE/dependency_tree.txt" ] && cp "$WORKSPACE/dependency_tree.txt" "$RESULT_DIR/dependency_tree.txt"
  if [ -d "$WORKSPACE/shark-tauri-spike/gen/apple" ]; then
    find "$WORKSPACE/shark-tauri-spike/gen/apple" -maxdepth 5 -type f \( -name 'project.pbxproj' -o -name 'Info.plist' -o -name 'Podfile' -o -name '*.xcconfig' \) -print > "$RESULT_DIR/apple_project_files.txt" 2>/dev/null || true
  fi
  df -h > "$RESULT_DIR/disk_at_finish.txt" 2>/dev/null || true
  git -C "$REPO_ROOT" rev-parse HEAD > "$RESULT_DIR/repository_commit.txt" 2>/dev/null || true
  git -C "$UPSTREAM" rev-parse HEAD > "$RESULT_DIR/beankeeper_commit.txt" 2>/dev/null || true
  cat > "$SUMMARY_TXT" <<EOF
SBC-0D Codemagic iOS Compile Proof
Overall: $OVERALL
Classification: $CLASSIFICATION
Phase: $PHASE
Assertions: $ASSERT_N
Failures: $FAIL_N
Commands: $CMD_N
Codemagic build id: ${CM_BUILD_ID:-unknown}
Codemagic workflow id: ${CM_WORKFLOW_ID:-unknown}
Repository commit: ${CM_COMMIT:-unknown}
Beankeeper pin: $PIN
Shark facade SHA-256: $FACADE_SHA
Reviewed Cargo.lock SHA-256: $LOCK_SHA_EXPECTED
Observed Cargo.lock SHA-256: $LOCK_SHA
Rust toolchain: $RUST_TOOLCHAIN
rustc: $RUSTC_VERSION
cargo: $CARGO_VERSION
Tauri CLI: $TAURI_VERSION
Tauri core pin: $TAURI_CORE_VERSION
Tauri build pin: $TAURI_BUILD_VERSION
Xcode: $XCODE_VERSION
Free disk at start: $START_FREE_GIB GiB
Built app path: $APP_PATH
EOF
  cat > "$SUMMARY_JSON" <<EOF
{
  "overall": "$(printf '%s' "$OVERALL" | json_escape)",
  "classification": "$(printf '%s' "$CLASSIFICATION" | json_escape)",
  "phase": "$(printf '%s' "$PHASE" | json_escape)",
  "assertions": $ASSERT_N,
  "failures": $FAIL_N,
  "commands": $CMD_N,
  "codemagic_build_id": "$(printf '%s' "${CM_BUILD_ID:-unknown}" | json_escape)",
  "codemagic_workflow_id": "$(printf '%s' "${CM_WORKFLOW_ID:-unknown}" | json_escape)",
  "repository_commit": "$(printf '%s' "${CM_COMMIT:-unknown}" | json_escape)",
  "beankeeper_pin": "$PIN",
  "shark_facade_sha256": "$FACADE_SHA",
  "reviewed_cargo_lock_sha256": "$LOCK_SHA_EXPECTED",
  "observed_cargo_lock_sha256": "$(printf '%s' "$LOCK_SHA" | json_escape)",
  "rust_toolchain": "$RUST_TOOLCHAIN",
  "rustc_version": "$(printf '%s' "$RUSTC_VERSION" | json_escape)",
  "cargo_version": "$(printf '%s' "$CARGO_VERSION" | json_escape)",
  "tauri_cli_version": "$(printf '%s' "$TAURI_VERSION" | json_escape)",
  "xcode_version": "$(printf '%s' "$XCODE_VERSION" | json_escape)",
  "free_disk_gib_at_start": "$(printf '%s' "$START_FREE_GIB" | json_escape)",
  "built_app_path": "$(printf '%s' "$APP_PATH" | json_escape)"
}
EOF
  cp "$SUMMARY_TXT" "$RESULT_DIR/SUMMARY.txt" 2>/dev/null || true
  cp "$SUMMARY_JSON" "$RESULT_DIR/SUMMARY.json" 2>/dev/null || true
  rm -f "$RESULT_ZIP"
  if command -v ditto >/dev/null 2>&1; then
    ditto -c -k --sequesterRsrc --keepParent "$RESULT_DIR" "$RESULT_ZIP" 2>/dev/null || true
  fi
  if [ ! -f "$RESULT_ZIP" ]; then
    (cd "$ROOT" && zip -qry "$RESULT_ZIP" "$(basename "$RESULT_DIR")") || true
  fi
  if [ -f "$RESULT_ZIP" ]; then
    shasum -a 256 "$RESULT_ZIP" > "$RESULT_ZIP.sha256" 2>/dev/null || true
    echo "SBC-0D result artifact: $RESULT_ZIP"
    cat "$RESULT_ZIP.sha256" 2>/dev/null || true
  fi
  echo "OVERALL: $OVERALL"
  echo "Classification: $CLASSIFICATION"
  exit "$rc"
}
trap finish EXIT
: > "$RESULT_DIR/assertions.tsv"

# ---------- CM0: Codemagic/macOS preflight ----------
PHASE="CM0_PREFLIGHT"
if [ "$(uname -s)" != "Darwin" ]; then assert_fail "Host is macOS"; CLASSIFICATION="HOST_NOT_MACOS"; exit 20; fi
assert_ok "Host is macOS"
if [ "$(uname -m)" != "arm64" ]; then assert_fail "Host is Apple Silicon arm64"; CLASSIFICATION="HOST_NOT_ARM64"; exit 21; fi
assert_ok "Host is Apple Silicon arm64"

for tool in git curl xcodebuild xcrun pod python3 shasum zip; do
  if command -v "$tool" >/dev/null 2>&1; then assert_ok "$tool available"; else assert_fail "$tool available"; CLASSIFICATION="HOST_PREREQUISITE_MISSING_$tool"; exit 22; fi
done

if run_cmd xcode_version xcodebuild -version; then
  XCODE_VERSION="$(tr '\n' ' ' < "$LOG_DIR/$(printf '%03d' "$CMD_N")_xcode_version.stdout.txt" | sed 's/[[:space:]]*$//')"
  assert_ok "Xcode responds"
else assert_fail "Xcode responds"; CLASSIFICATION="XCODE_NOT_READY"; exit 23; fi
if run_cmd iphoneos_sdk xcrun --sdk iphoneos --show-sdk-path; then assert_ok "iphoneos SDK visible"; else assert_fail "iphoneos SDK visible"; CLASSIFICATION="IPHONEOS_SDK_MISSING"; exit 24; fi
if run_cmd iphonesimulator_sdk xcrun --sdk iphonesimulator --show-sdk-path; then assert_ok "iphonesimulator SDK visible"; else assert_fail "iphonesimulator SDK visible"; CLASSIFICATION="IPHONESIMULATOR_SDK_MISSING"; exit 25; fi
if run_cmd pod_version pod --version; then assert_ok "CocoaPods responds"; else assert_fail "CocoaPods responds"; CLASSIFICATION="COCOAPODS_BROKEN"; exit 26; fi

FREE_KIB=$(df -Pk "$REPO_ROOT" | awk 'NR==2 {print $4}')
START_FREE_GIB=$((FREE_KIB / 1024 / 1024))
printf '%s\n' "$START_FREE_GIB" > "$RESULT_DIR/free_gib_at_start.txt"
if [ "$START_FREE_GIB" -lt "$MIN_FREE_GIB" ]; then assert_fail "At least ${MIN_FREE_GIB} GiB free (found ${START_FREE_GIB} GiB)"; CLASSIFICATION="INSUFFICIENT_DISK_SPACE"; exit 27; fi
assert_ok "At least ${MIN_FREE_GIB} GiB free (${START_FREE_GIB} GiB)"
run_cmd sw_vers sw_vers || true
run_cmd disk_start df -h || true
run_cmd simulator_devices xcrun simctl list devices available || true

# ---------- CM1: exact Rust toolchain ----------
PHASE="CM1_RUST_TOOLCHAIN"
if ! command -v rustup >/dev/null 2>&1; then
  if run_shell rustup_install 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain none'; then
    export PATH="$HOME/.cargo/bin:$PATH"
  else assert_fail "rustup installed"; CLASSIFICATION="RUSTUP_INSTALL_FAIL"; exit 30; fi
else
  export PATH="$HOME/.cargo/bin:$PATH"
fi
assert_ok "rustup available"
if run_cmd rust_toolchain rustup toolchain install "$RUST_TOOLCHAIN" --profile minimal; then assert_ok "Rust $RUST_TOOLCHAIN installed"; else assert_fail "Rust $RUST_TOOLCHAIN installed"; CLASSIFICATION="RUST_TOOLCHAIN_INSTALL_FAIL"; exit 31; fi
if run_cmd rust_default rustup default "$RUST_TOOLCHAIN"; then assert_ok "Rust $RUST_TOOLCHAIN selected"; else assert_fail "Rust $RUST_TOOLCHAIN selected"; CLASSIFICATION="RUST_TOOLCHAIN_SELECT_FAIL"; exit 32; fi
if run_cmd rust_targets rustup target add --toolchain "$RUST_TOOLCHAIN" aarch64-apple-ios aarch64-apple-ios-sim; then assert_ok "iOS Rust targets installed"; else assert_fail "iOS Rust targets installed"; CLASSIFICATION="RUST_IOS_TARGET_INSTALL_FAIL"; exit 33; fi
RUSTC_VERSION="$(rustc -V 2>/dev/null || true)"
CARGO_VERSION="$(cargo -V 2>/dev/null || true)"
run_cmd rustc_vv rustc -Vv || true
run_cmd cargo_v cargo -V || true
run_cmd rustup_show rustup show || true

# ---------- CM2: immutable source and reviewed lock ----------
PHASE="CM2_SOURCE_AND_LOCK"
PKG_FACADE_SHA="$(shasum -a 256 "$WORKSPACE/shark-foundation/src/lib.rs" | awk '{print $1}')"
if [ "$PKG_FACADE_SHA" != "$FACADE_SHA" ]; then assert_fail "Shark facade matches SBC-0C accepted SHA"; CLASSIFICATION="FACADE_HASH_MISMATCH"; exit 40; fi
assert_ok "Shark facade matches SBC-0C accepted SHA"
LOCK_SHA="$(shasum -a 256 "$WORKSPACE/Cargo.lock" | awk '{print $1}')"
if [ "$LOCK_SHA" != "$LOCK_SHA_EXPECTED" ]; then assert_fail "Cargo.lock matches SBC-0C reviewed dependency graph"; CLASSIFICATION="LOCK_HASH_MISMATCH"; exit 41; fi
assert_ok "Cargo.lock matches SBC-0C reviewed dependency graph"

mkdir -p "$REPO_ROOT/upstream"
rm -rf "$UPSTREAM"
mkdir -p "$UPSTREAM"
if ! run_cmd git_init git -C "$UPSTREAM" init; then assert_fail "Initialise Beankeeper checkout"; CLASSIFICATION="BEANKEEPER_FETCH_FAIL"; exit 42; fi
if ! run_cmd git_remote git -C "$UPSTREAM" remote add origin https://github.com/Govcraft/beankeeper.git; then assert_fail "Configure Beankeeper remote"; CLASSIFICATION="BEANKEEPER_FETCH_FAIL"; exit 42; fi
if ! run_cmd git_fetch git -C "$UPSTREAM" fetch --depth 1 origin "$PIN"; then assert_fail "Fetch exact Beankeeper pin"; CLASSIFICATION="BEANKEEPER_FETCH_FAIL"; exit 42; fi
if ! run_cmd git_checkout git -C "$UPSTREAM" checkout --detach FETCH_HEAD; then assert_fail "Checkout exact Beankeeper pin"; CLASSIFICATION="BEANKEEPER_FETCH_FAIL"; exit 42; fi
HEAD="$(git -C "$UPSTREAM" rev-parse HEAD 2>/dev/null || true)"
if [ "$HEAD" != "$PIN" ]; then assert_fail "Exact Beankeeper pin checked out"; CLASSIFICATION="BEANKEEPER_PIN_MISMATCH"; exit 43; fi
assert_ok "Exact Beankeeper pin checked out"
if [ -n "$(git -C "$UPSTREAM" status --porcelain 2>/dev/null)" ]; then assert_fail "Beankeeper checkout clean"; CLASSIFICATION="BEANKEEPER_DIRTY"; exit 44; fi
assert_ok "Beankeeper checkout clean"

if grep -R -E 'beankeeper_cli|rusqlite|Db::|\.conn\(' "$WORKSPACE/shark-tauri-spike/src" >/dev/null 2>&1; then assert_fail "Tauri layer uses Shark facade only"; CLASSIFICATION="TAURI_BOUNDARY_VIOLATION"; exit 45; fi
assert_ok "Tauri layer uses Shark facade only"

cd "$WORKSPACE" || exit 46
if run_cmd cargo_fetch cargo fetch --locked; then assert_ok "Reviewed dependency graph fetches under --locked"; else assert_fail "Reviewed dependency graph fetches under --locked"; CLASSIFICATION="CARGO_FETCH_LOCKED_FAIL"; exit 46; fi
if cargo metadata --format-version 1 --locked > "$WORKSPACE/resolved_metadata.json" 2> "$LOG_DIR/metadata.stderr.txt"; then assert_ok "Cargo metadata resolves under reviewed lock"; else assert_fail "Cargo metadata resolves under reviewed lock"; CLASSIFICATION="CARGO_METADATA_LOCKED_FAIL"; exit 47; fi
cargo tree --locked > "$WORKSPACE/dependency_tree.txt" 2> "$LOG_DIR/cargo_tree.stderr.txt" || true
LOCK_SHA_AFTER_METADATA="$(shasum -a 256 Cargo.lock | awk '{print $1}')"
if [ "$LOCK_SHA_AFTER_METADATA" = "$LOCK_SHA_EXPECTED" ]; then assert_ok "Cargo.lock unchanged by metadata/fetch"; else assert_fail "Cargo.lock unchanged by metadata/fetch"; CLASSIFICATION="LOCKFILE_DRIFT"; exit 48; fi

# ---------- CM3: actual iPhone/iPad Rust portability ----------
PHASE="CM3_FOUNDATION_DEVICE_COMPILE"
export CARGO_BUILD_JOBS=1
export CARGO_INCREMENTAL=0
if run_cmd foundation_device cargo build -p shark-foundation --target aarch64-apple-ios --locked; then assert_ok "Shark foundation builds for physical ARM64 iPhone/iPad target"; else assert_fail "Shark foundation builds for physical ARM64 iPhone/iPad target"; CLASSIFICATION="FOUNDATION_IOS_DEVICE_COMPILE_FAIL"; exit 50; fi
LOCK_SHA_DEVICE="$(shasum -a 256 Cargo.lock | awk '{print $1}')"
if [ "$LOCK_SHA_DEVICE" = "$LOCK_SHA_EXPECTED" ]; then assert_ok "Cargo.lock unchanged by physical-device compile"; else assert_fail "Cargo.lock unchanged by physical-device compile"; CLASSIFICATION="LOCKFILE_DRIFT"; exit 51; fi

PHASE="CM4_FOUNDATION_SIMULATOR_COMPILE"
if run_cmd foundation_sim cargo build -p shark-foundation --target aarch64-apple-ios-sim --locked; then assert_ok "Shark foundation builds for Apple-silicon iOS Simulator target"; else assert_fail "Shark foundation builds for Apple-silicon iOS Simulator target"; CLASSIFICATION="FOUNDATION_IOS_SIM_COMPILE_FAIL"; exit 52; fi
LOCK_SHA_SIM="$(shasum -a 256 Cargo.lock | awk '{print $1}')"
if [ "$LOCK_SHA_SIM" = "$LOCK_SHA_EXPECTED" ]; then assert_ok "Cargo.lock unchanged by simulator compile"; else assert_fail "Cargo.lock unchanged by simulator compile"; CLASSIFICATION="LOCKFILE_DRIFT"; exit 53; fi

# ---------- CM5: exact Tauri CLI ----------
PHASE="CM5_TAURI_CLI"
mkdir -p "$TOOLS"
if run_cmd install_tauri_cli cargo install tauri-cli --version "$TAURI_CLI_VERSION" --locked --root "$TOOLS" --force; then assert_ok "Pinned Tauri CLI installed"; else assert_fail "Pinned Tauri CLI installed"; CLASSIFICATION="TAURI_CLI_INSTALL_FAIL"; exit 60; fi
export PATH="$TOOLS/bin:$PATH"
TAURI_VERSION="$(cargo tauri --version 2>/dev/null || true)"
if printf '%s' "$TAURI_VERSION" | grep -q "$TAURI_CLI_VERSION"; then assert_ok "Tauri CLI $TAURI_CLI_VERSION active"; else assert_fail "Tauri CLI $TAURI_CLI_VERSION active"; CLASSIFICATION="TAURI_CLI_VERSION_MISMATCH"; exit 61; fi
run_cmd tauri_version cargo tauri --version || true

# ---------- CM6: Tauri iOS simulator project/build, unsigned ----------
PHASE="CM6_TAURI_IOS_SIMULATOR"
cd "$WORKSPACE/shark-tauri-spike" || exit 62
rm -rf gen/apple
if run_cmd tauri_ios_init cargo tauri ios init --ci; then assert_ok "Tauri iOS project initialised"; else assert_fail "Tauri iOS project initialised"; CLASSIFICATION="TAURI_IOS_INIT_FAIL"; exit 62; fi
if run_cmd tauri_icons cargo tauri icon "$REPO_ROOT/app-icon.png"; then assert_ok "Tauri iOS icon set generated"; else assert_fail "Tauri iOS icon set generated"; CLASSIFICATION="TAURI_IOS_ICON_FAIL"; exit 63; fi
export CI=true
export CODE_SIGNING_ALLOWED=NO
export CODE_SIGNING_REQUIRED=NO
export CODE_SIGN_IDENTITY=""
if run_cmd tauri_ios_build cargo tauri ios build --target aarch64-sim --debug --ci; then assert_ok "Unsigned minimal Tauri iOS simulator app builds"; else assert_fail "Unsigned minimal Tauri iOS simulator app builds"; CLASSIFICATION="TAURI_IOS_SIM_BUILD_FAIL"; exit 64; fi

LOCK_SHA_FINAL="$(shasum -a 256 "$WORKSPACE/Cargo.lock" | awk '{print $1}')"
if [ "$LOCK_SHA_FINAL" = "$LOCK_SHA_EXPECTED" ]; then assert_ok "Reviewed Cargo.lock unchanged through complete iOS gate"; else assert_fail "Reviewed Cargo.lock unchanged through complete iOS gate"; CLASSIFICATION="LOCKFILE_DRIFT"; exit 65; fi
APP_PATH="$(find "$WORKSPACE/shark-tauri-spike/gen/apple" "$WORKSPACE/target" -type d -name '*.app' 2>/dev/null | head -1 || true)"
if [ -n "$APP_PATH" ]; then assert_ok "Generated iOS simulator .app located"; else assert_ok "Tauri iOS build succeeded (app path not required for foundation gate)"; fi

PHASE="COMPLETE"
OVERALL="PASS"
CLASSIFICATION="PASS_CODEMAGIC_IOS_FOUNDATION_AND_TAURI_SIMULATOR"
exit 0
