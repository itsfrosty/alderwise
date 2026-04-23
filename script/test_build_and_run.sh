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

assert_file_order() {
  local file="$1"
  local first="$2"
  local second="$3"
  local first_line
  local second_line

  first_line="$(grep -n -F -- "$first" "$file" | head -n 1 | cut -d: -f1)"
  second_line="$(grep -n -F -- "$second" "$file" | head -n 1 | cut -d: -f1)"

  if [[ -z "$first_line" || -z "$second_line" ]]; then
    echo "Missing order target in $file" >&2
    cat "$file" >&2
    fail "cannot verify command order"
  fi

  if (( first_line >= second_line )); then
    echo "Unexpected order in $file" >&2
    cat "$file" >&2
    fail "command order mismatch"
  fi
}

assert_occurrence_count() {
  local file="$1"
  local pattern="$2"
  local expected="$3"
  local actual

  actual="$(grep -c -F -- "$pattern" "$file")"
  if [[ "$actual" != "$expected" ]]; then
    echo "Expected $expected occurrences of: $pattern" >&2
    echo "Found $actual in $file" >&2
    cat "$file" >&2
    fail "unexpected occurrence count"
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

write_open_stub() {
  local temp_dir="$1"

  cat >"$temp_dir/stubs/open" <<EOF
#!/usr/bin/env bash
set -euo pipefail
echo "open \$*" >>"$temp_dir/command.log"
exit 0
EOF

  chmod +x "$temp_dir/stubs/open"
}

write_log_stub() {
  local temp_dir="$1"

  cat >"$temp_dir/stubs/log" <<EOF
#!/usr/bin/env bash
set -euo pipefail
echo "log \$*" >>"$temp_dir/command.log"
exit 0
EOF

  chmod +x "$temp_dir/stubs/log"
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

  write_open_stub "$temp_dir"

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

run_verify_success_contract() {
  local temp_dir
  local exit_code
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' RETURN

  make_stub_environment "$temp_dir"
  write_open_stub "$temp_dir"

  cat >"$temp_dir/stubs/pgrep" <<EOF
#!/usr/bin/env bash
set -euo pipefail
echo "pgrep \$*" >>"$temp_dir/command.log"
exit 0
EOF

  chmod +x "$temp_dir/stubs/pgrep"

  exit_code=0
  PATH="$temp_dir/stubs:$PATH" \
  OPEN_BIN="$temp_dir/stubs/open" \
  "$SCRIPT_PATH" --verify >/dev/null 2>&1 || exit_code=$?

  assert_exit_code 0 "$exit_code"
  assert_file_contains "$temp_dir/command.log" "open -n "
  assert_file_contains "$temp_dir/command.log" "pgrep -x AlderwiseApp"
  assert_occurrence_count "$temp_dir/command.log" "pgrep -x AlderwiseApp" 4
  assert_occurrence_count "$temp_dir/command.log" "sleep 1" 3
}

run_logs_contract() {
  local temp_dir
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' RETURN

  make_stub_environment "$temp_dir"
  write_open_stub "$temp_dir"
  write_log_stub "$temp_dir"

  PATH="$temp_dir/stubs:$PATH" \
  OPEN_BIN="$temp_dir/stubs/open" \
  LOG_BIN="$temp_dir/stubs/log" \
  "$SCRIPT_PATH" --logs >/dev/null 2>&1

  assert_file_contains "$temp_dir/command.log" "pkill -x AlderwiseApp"
  assert_file_contains "$temp_dir/command.log" "open -n "
  assert_file_contains "$temp_dir/command.log" "log stream --info --style compact --predicate process == \"AlderwiseApp\""
  assert_file_order "$temp_dir/command.log" "pkill -x AlderwiseApp" "open -n "
  assert_file_order "$temp_dir/command.log" "open -n " "log stream --info --style compact --predicate process == \"AlderwiseApp\""
}

run_telemetry_contract() {
  local temp_dir
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' RETURN

  make_stub_environment "$temp_dir"
  write_open_stub "$temp_dir"
  write_log_stub "$temp_dir"

  PATH="$temp_dir/stubs:$PATH" \
  OPEN_BIN="$temp_dir/stubs/open" \
  LOG_BIN="$temp_dir/stubs/log" \
  "$SCRIPT_PATH" --telemetry >/dev/null 2>&1

  assert_file_contains "$temp_dir/command.log" "pkill -x AlderwiseApp"
  assert_file_contains "$temp_dir/command.log" "open -n "
  assert_file_contains "$temp_dir/command.log" "log stream --info --style compact --predicate subsystem == \"com.alderwise.AlderwiseApp\""
  assert_file_order "$temp_dir/command.log" "pkill -x AlderwiseApp" "open -n "
  assert_file_order "$temp_dir/command.log" "open -n " "log stream --info --style compact --predicate subsystem == \"com.alderwise.AlderwiseApp\""
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
run_verify_success_contract
run_logs_contract
run_telemetry_contract
run_invalid_mode_contract

echo "build_and_run.sh contract checks passed"
