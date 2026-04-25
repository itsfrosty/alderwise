#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="AlderwiseApp"
BUNDLE_ID="com.alderwise.AlderwiseApp"
MIN_SYSTEM_VERSION="15.0"
VERIFY_STARTUP_ATTEMPTS=10
VERIFY_SMOKE_CHECKS=3
VERIFY_INTERVAL_SECONDS=1

SWIFT_BIN="${SWIFT_BIN:-swift}"
PKILL_BIN="${PKILL_BIN:-pkill}"
PGREP_BIN="${PGREP_BIN:-pgrep}"
LLDB_BIN="${LLDB_BIN:-lldb}"
OPEN_BIN="${OPEN_BIN:-/usr/bin/open}"
LOG_BIN="${LOG_BIN:-/usr/bin/log}"
SLEEP_BIN="${SLEEP_BIN:-sleep}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
LOGO_SOURCE="$ROOT_DIR/logo.png"
ICON_NAME="AppIcon"
ICONSET_DIR="$DIST_DIR/$ICON_NAME.iconset"
ICON_FILE="$APP_RESOURCES/$ICON_NAME.icns"

cd "$ROOT_DIR"

generate_app_icon() {
  if [[ ! -f "$LOGO_SOURCE" ]]; then
    return 0
  fi

  rm -rf "$ICONSET_DIR"
  mkdir -p "$ICONSET_DIR"

  for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$LOGO_SOURCE" --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null

    local retina_size=$((size * 2))
    sips -z "$retina_size" "$retina_size" "$LOGO_SOURCE" --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" >/dev/null
  done

  mkdir -p "$APP_RESOURCES"
  iconutil -c icns "$ICONSET_DIR" -o "$ICON_FILE"
}

print_help() {
  cat <<EOF
usage: $0 [run|--debug|--logs|--telemetry|--verify|--help]

All modes restart Alderwise before their mode-specific behavior.

run         Build and launch Alderwise, then return.
verify      Build and relaunch Alderwise, then require it to stay alive across a short smoke-check window.
debug       Build Alderwise and launch it under LLDB with the run started automatically.
logs        Build and relaunch Alderwise, then attach to a process-filtered unified log stream.
telemetry   Build and relaunch Alderwise, then attach to a subsystem-filtered unified log stream.
help        Show this launcher summary and exit without building or restarting.
EOF
}

case "$MODE" in
  run)
    MODE="run"
    ;;
  -h|--help|help)
    MODE="help"
    ;;
  --debug|debug)
    MODE="debug"
    ;;
  --logs|logs)
    MODE="logs"
    ;;
  --telemetry|telemetry)
    MODE="telemetry"
    ;;
  --verify|verify)
    MODE="verify"
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify|--help]" >&2
    exit 2
    ;;
esac

if [[ "$MODE" == "help" ]]; then
  print_help
  exit 0
fi

"$PKILL_BIN" -x "$APP_NAME" >/dev/null 2>&1 || true

"$SWIFT_BIN" build --product "$APP_NAME"
BUILD_BINARY="$("$SWIFT_BIN" build --product "$APP_NAME" --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"
generate_app_icon

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleIconFile</key>
  <string>$ICON_NAME</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

open_app() {
  "$OPEN_BIN" -n "$APP_BUNDLE"
}

verify_relaunch_sticks() {
  local startup_attempt
  local smoke_check

  # Verify means the relaunched app must appear and then remain alive briefly.
  for ((startup_attempt = 0; startup_attempt < VERIFY_STARTUP_ATTEMPTS; startup_attempt++)); do
    if "$PGREP_BIN" -x "$APP_NAME" >/dev/null; then
      break
    fi
    "$SLEEP_BIN" "$VERIFY_INTERVAL_SECONDS"
  done

  if ((startup_attempt == VERIFY_STARTUP_ATTEMPTS)); then
    return 1
  fi

  for ((smoke_check = 0; smoke_check < VERIFY_SMOKE_CHECKS; smoke_check++)); do
    "$SLEEP_BIN" "$VERIFY_INTERVAL_SECONDS"
    if ! "$PGREP_BIN" -x "$APP_NAME" >/dev/null; then
      return 1
    fi
  done
}

# All supported modes fully restart Alderwise before their mode-specific behavior.
case "$MODE" in
  run)
    open_app
    ;;
  debug)
    "$LLDB_BIN" --one-line run -- "$APP_BINARY"
    ;;
  logs)
    open_app
    "$LOG_BIN" stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  telemetry)
    open_app
    "$LOG_BIN" stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  verify)
    open_app
    verify_relaunch_sticks
    ;;
esac
