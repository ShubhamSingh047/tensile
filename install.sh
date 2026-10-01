#!/bin/sh
# Tensile installer for macOS and Linux.
#
#   curl -fsSL https://raw.githubusercontent.com/ShubhamSingh047/tensile/main/install.sh | sh
#
# Options (put them after `sh -s --`, e.g.  ... | sh -s -- --cli):
#   --app           install only the desktop app
#   --cli           install only the `tensile` command-line tool
#   --version vX.Y  install that release instead of the latest
#   --uninstall     remove what this script installed
#   --no-open       do not open the app when the install finishes
#   -h, --help      show this help
#
# What it does: downloads the release files from GitHub, checks them against the
# release's SHA256SUMS, and copies them into your user folders. It never uses
# sudo and never touches anything outside the places listed below.
#   macOS app    /Applications/Tensile.app   (or ~/Applications if /Applications is not writable)
#   Linux app    ~/.local/share/tensile/Tensile.AppImage, plus a launcher entry
#   CLI          ~/.local/bin/tensile
# Override the places with TENSILE_APP_DIR and TENSILE_BIN_DIR.
set -eu

REPO="ShubhamSingh047/tensile"
VERSION="${TENSILE_VERSION:-latest}"
# For testing: a directory or URL that holds the release files instead of GitHub.
BASE="${TENSILE_BASE_URL:-}"
WANT_APP=1
WANT_CLI=1
UNINSTALL=0
# Open the app once it is installed, unless asked not to or running on a CI machine.
OPEN_APP=1
[ -n "${TENSILE_NO_OPEN:-}${CI:-}" ] && OPEN_APP=0

say() { printf '%s\n' "$*"; }
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

usage() {
  cat <<'HELP'
Tensile installer for macOS and Linux.

  curl -fsSL https://raw.githubusercontent.com/ShubhamSingh047/tensile/main/install.sh | sh

Options (after `sh -s --`, e.g.  ... | sh -s -- --cli):
  --app           install only the desktop app
  --cli           install only the `tensile` command-line tool
  --version vX.Y  install that release instead of the latest
  --uninstall     remove what this script installed
  --no-open       do not open the app when the install finishes
  -h, --help      show this help

Installs into your own folders and never uses sudo:
  macOS app   /Applications/Tensile.app (or ~/Applications)
  Linux app   ~/.local/share/tensile/Tensile.AppImage
  CLI         ~/.local/bin/tensile
Override with TENSILE_APP_DIR and TENSILE_BIN_DIR.
HELP
}

while [ $# -gt 0 ]; do
  case "$1" in
    --app) WANT_CLI=0 ;;
    --cli) WANT_APP=0 ;;
    --version) shift; VERSION="${1:?--version needs a value, e.g. v0.1.0}" ;;
    --uninstall) UNINSTALL=1 ;;
    --no-open) OPEN_APP=0 ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1 (try --help)" ;;
  esac
  shift
done

have curl || die "curl is required."

# ---------- platform ----------
OS=$(uname -s)
ARCH=$(uname -m)
case "$OS" in
  Darwin)
    # A Terminal running under Rosetta reports x86_64 on an Apple Silicon Mac.
    if [ "$ARCH" = x86_64 ] && [ "$(sysctl -n hw.optional.arm64 2>/dev/null || echo 0)" = 1 ]; then ARCH=arm64; fi
    case "$ARCH" in
      arm64) PLAT=macos-arm64 ;;
      x86_64) PLAT=macos-x64 ;;
      *) die "Unsupported Mac processor: $ARCH" ;;
    esac ;;
  Linux)
    case "$ARCH" in
      x86_64|amd64) PLAT=linux-x64 ;;
      *) die "Prebuilt Linux downloads are for x86_64 only (this is $ARCH). Build from source: see the README." ;;
    esac ;;
  MINGW*|MSYS*|CYGWIN*)
    die "On Windows, download Tensile-windows-x64-setup.exe from https://github.com/$REPO/releases/latest" ;;
  *) die "Unsupported system: $OS" ;;
esac

BIN_DIR="${TENSILE_BIN_DIR:-$HOME/.local/bin}"
if [ "$OS" = Darwin ]; then
  if [ -n "${TENSILE_APP_DIR:-}" ]; then APP_DIR="$TENSILE_APP_DIR"
  elif [ -w /Applications ]; then APP_DIR=/Applications
  else APP_DIR="$HOME/Applications"; fi
else
  APP_DIR="${TENSILE_APP_DIR:-$HOME/.local/share/tensile}"
fi
DESKTOP_ENTRY="$HOME/.local/share/applications/tensile.desktop"

# ---------- uninstall ----------
if [ "$UNINSTALL" = 1 ]; then
  # With a custom folder, only that folder is touched. Otherwise the usual places.
  set -- "$APP_DIR/Tensile.app" "$APP_DIR/Tensile.AppImage" "$APP_DIR/tensile.png" "$BIN_DIR/tensile" "$BIN_DIR/tensile-desktop"
  if [ -z "${TENSILE_APP_DIR:-}${TENSILE_BIN_DIR:-}" ]; then
    set -- "$@" /Applications/Tensile.app "$HOME/Applications/Tensile.app" "$DESKTOP_ENTRY"
  fi
  removed=0
  for path in "$@"; do
    if [ -e "$path" ] || [ -L "$path" ]; then rm -rf "$path"; say "Removed $path"; removed=1; fi
  done
  [ "$removed" = 1 ] || say "Nothing to remove."
  say "Your collections are plain folders and were not touched."
  exit 0
fi

# ---------- download helpers ----------
TMP=$(mktemp -d 2>/dev/null || mktemp -d -t tensile)
trap 'rm -rf "$TMP"' EXIT INT TERM

url_for() {
  if [ -n "$BASE" ]; then printf '%s/%s' "${BASE%/}" "$1"
  elif [ "$VERSION" = latest ]; then printf 'https://github.com/%s/releases/latest/download/%s' "$REPO" "$1"
  else printf 'https://github.com/%s/releases/download/%s/%s' "$REPO" "$VERSION" "$1"; fi
}

fetch() { # name -> $TMP/name
  curl -fsSL --retry 3 --retry-delay 1 -o "$TMP/$1" "$(url_for "$1")" \
    || die "Could not download $(url_for "$1")
       Is there a release for your system? See https://github.com/$REPO/releases"
}

sha256() {
  if have shasum; then shasum -a 256 "$1" | awk '{print $1}'
  elif have sha256sum; then sha256sum "$1" | awk '{print $1}'
  else die "Need shasum or sha256sum to verify the download."; fi
}

verify() { # name
  want=$(awk -v n="$1" '$2 == n || $2 == "*" n {print $1}' "$TMP/SHA256SUMS")
  [ -n "$want" ] || die "No checksum listed for $1; refusing to install it."
  [ "$want" = "$(sha256 "$TMP/$1")" ] || die "Checksum mismatch for $1; refusing to install it."
}

say "Tensile installer: $PLAT, release ${VERSION}"
fetch SHA256SUMS

# ---------- desktop app ----------
install_app_macos() {
  name="Tensile-$PLAT.zip"
  fetch "$name"; verify "$name"
  if pgrep -f "$APP_DIR/Tensile.app/Contents/MacOS" >/dev/null 2>&1; then die "Tensile is running. Quit it, then run this again."; fi
  have ditto || die "ditto is missing; is this macOS?"
  mkdir -p "$APP_DIR" "$TMP/app"
  ditto -x -k "$TMP/$name" "$TMP/app"
  [ -d "$TMP/app/Tensile.app" ] || die "The download did not contain Tensile.app."
  rm -rf "$APP_DIR/Tensile.app"
  mv "$TMP/app/Tensile.app" "$APP_DIR/Tensile.app"
  # Files fetched with curl are not quarantined; clear the flag anyway in case a browser was involved.
  xattr -dr com.apple.quarantine "$APP_DIR/Tensile.app" 2>/dev/null || true
  say "Installed the app: $APP_DIR/Tensile.app"
}

install_app_linux() {
  name="Tensile-$PLAT.AppImage"
  fetch "$name"; verify "$name"
  mkdir -p "$APP_DIR" "$BIN_DIR" "$(dirname "$DESKTOP_ENTRY")"
  install -m 755 "$TMP/$name" "$APP_DIR/Tensile.AppImage"
  ln -sf "$APP_DIR/Tensile.AppImage" "$BIN_DIR/tensile-desktop"
  icon=""
  if curl -fsSL --retry 2 -o "$APP_DIR/tensile.png" "$(url_for Tensile-icon.png)" 2>/dev/null; then icon="$APP_DIR/tensile.png"; fi
  cat > "$DESKTOP_ENTRY" <<EOF
[Desktop Entry]
Type=Application
Name=Tensile
Comment=Build API requests and find the load at which they break
Exec=$APP_DIR/Tensile.AppImage
Icon=${icon:-utilities-terminal}
Categories=Development;
Terminal=false
EOF
  say "Installed the app: $APP_DIR/Tensile.AppImage (launch it from your applications menu, or run tensile-desktop)"
  say "If it does not start, your system may need FUSE: sudo apt install libfuse2"
}

# ---------- command-line tool ----------
install_cli() {
  name="tensile-$PLAT.tar.gz"
  fetch "$name"; verify "$name"
  mkdir -p "$TMP/cli" "$BIN_DIR"
  tar -xzf "$TMP/$name" -C "$TMP/cli"
  [ -f "$TMP/cli/tensile" ] || die "The download did not contain the tensile program."
  install -m 755 "$TMP/cli/tensile" "$BIN_DIR/tensile"
  say "Installed the command-line tool: $BIN_DIR/tensile"
  case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *) say "Add it to your PATH:  export PATH=\"$BIN_DIR:\$PATH\"   (put that line in ~/.zshrc or ~/.bashrc)" ;;
  esac
}

if [ "$WANT_APP" = 1 ]; then
  if [ "$OS" = Darwin ]; then install_app_macos; else install_app_linux; fi
fi
if [ "$WANT_CLI" = 1 ]; then install_cli; fi

say ""
say "Done."
if [ "$WANT_APP" = 1 ] && [ "$OS" = Darwin ]; then say "Open Tensile any time from your Applications folder, or run:  open \"$APP_DIR/Tensile.app\""; fi
if [ "$WANT_CLI" = 1 ]; then say "Try the command line:  tensile --help"; fi
say "Uninstall any time with:  curl -fsSL https://raw.githubusercontent.com/$REPO/main/install.sh | sh -s -- --uninstall"

if [ "$WANT_APP" = 1 ] && [ "$OPEN_APP" = 1 ]; then
  if [ "$OS" = Darwin ]; then
    say ""; say "Opening Tensile..."
    open "$APP_DIR/Tensile.app" || say "Could not open it automatically; open Tensile from your Applications folder."
  elif [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
    say ""; say "Opening Tensile..."
    nohup "$APP_DIR/Tensile.AppImage" >/dev/null 2>&1 &
  fi
fi
