#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_PATH="$ROOT_DIR/script/build_and_run.sh"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_file_contains() {
  local file="$1"
  local expected="$2"

  if ! grep -F -- "$expected" "$file" >/dev/null 2>&1; then
    echo "Expected to find: $expected" >&2
    echo "In file: $file" >&2
    cat "$file" >&2
    fail "missing expected content"
  fi
}

assert_exit_code() {
  local expected="$1"
  local actual="$2"

  if [[ "$expected" != "$actual" ]]; then
    fail "expected exit code $expected, got $actual"
  fi
}

make_stub_environment() {
  local temp_dir="$1"
  local fake_bin="$temp_dir/fake-bin"
  local stub_bin="$temp_dir/stubs"
  local command_log="$temp_dir/command.log"

  mkdir -p "$fake_bin" "$stub_bin"

  cat >"$fake_bin/AlderwiseApp" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$fake_bin/AlderwiseApp"

  cat >"$stub_bin/swift" <<EOF
#!/usr/bin/env bash
set -euo pipefail
echo "swift \$*" >>"$command_log"
if [[ "\$*" == *"--show-bin-path"* ]]; then
  echo "$fake_bin"
fi
EOF

  cat >"$stub_bin/pkill" <<EOF
#!/usr/bin/env bash
set -euo pipefail
echo "pkill \$*" >>"$command_log"
exit 0
EOF

  cat >"$stub_bin/lldb" <<EOF
#!/usr/bin/env bash
set -euo pipefail
echo "lldb \$*" >>"$command_log"
exit 0
EOF

  cat >"$stub_bin/sleep" <<EOF
#!/usr/bin/env bash
set -euo pipefail
echo "sleep \$*" >>"$command_log"
exit 0
EOF

  chmod +x "$stub_bin/swift" "$stub_bin/pkill" "$stub_bin/lldb" "$stub_bin/sleep"
}

run_debug_contract() {
  local temp_dir
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' RETURN

  make_stub_environment "$temp_dir"

  PATH="$temp_dir/stubs:$PATH" \
  OPEN_BIN="$temp_dir/stubs/open" \
  "$SCRIPT_PATH" --debug >/dev/null 2>&1

  assert_file_contains "$temp_dir/command.log" "lldb --one-line run -- "
}

run_verify_contract() {
  local temp_dir
  local exit_code
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' RETURN

  make_stub_environment "$temp_dir"

  cat >"$temp_dir/stubs/open" <<EOF
#!/usr/bin/env bash
set -euo pipefail
echo "open \$*" >>"$temp_dir/command.log"
exit 0
EOF

  cat >"$temp_dir/stubs/pgrep" <<EOF
#!/usr/bin/env bash
set -euo pipefail
echo "pgrep \$*" >>"$temp_dir/command.log"
state_file="$temp_dir/pgrep-state"
count=0
if [[ -f "\$state_file" ]]; then
  count="\$(cat "\$state_file")"
fi
next=\$((count + 1))
echo "\$next" >"\$state_file"
if [[ "\$next" -eq 1 ]]; then
  exit 0
fi
exit 1
EOF

  chmod +x "$temp_dir/stubs/open" "$temp_dir/stubs/pgrep"

  exit_code=0
  PATH="$temp_dir/stubs:$PATH" \
  OPEN_BIN="$temp_dir/stubs/open" \
  "$SCRIPT_PATH" --verify >/dev/null 2>&1 || exit_code=$?

  assert_exit_code 1 "$exit_code"
}

run_invalid_mode_contract() {
  local temp_dir
  local exit_code
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' RETURN

  make_stub_environment "$temp_dir"

  exit_code=0
  PATH="$temp_dir/stubs:$PATH" \
  OPEN_BIN="$temp_dir/stubs/open" \
  "$SCRIPT_PATH" --unknown >/dev/null 2>&1 || exit_code=$?

  assert_exit_code 2 "$exit_code"

  if [[ -f "$temp_dir/command.log" ]]; then
    fail "invalid mode should not build, kill, or launch anything"
  fi
}

run_debug_contract
run_verify_contract
run_invalid_mode_contract

echo "build_and_run.sh contract checks passed"
