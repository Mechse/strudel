#!/usr/bin/env bash
# Installer for strudel — Apple Intelligence powered git commit message generator.
# https://github.com/<you>/strudel
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/<you>/strudel/main/install.sh | bash
#
# Or, to install a specific version:
#   curl -fsSL https://raw.githubusercontent.com/<you>/strudel/main/install.sh | bash -s -- v0.1.0

set -euo pipefail

VERSION="${1:-v0.1.0}"
REPO="Mechse/strudel"
PREFIX="${PREFIX:-/usr/local}"

# Color output if we're attached to a terminal.
if [ -t 1 ]; then
    bold=$'\033[1m'
    dim=$'\033[2m'
    red=$'\033[31m'
    green=$'\033[32m'
    reset=$'\033[0m'
else
    bold='' dim='' red='' green='' reset=''
fi

say()  { printf "%s==>%s %s\n" "$green" "$reset" "$*"; }
warn() { printf "%s==> warning:%s %s\n" "$red" "$reset" "$*" >&2; }
die()  { printf "%s==> error:%s %s\n" "$red" "$reset" "$*" >&2; exit 1; }

# --- preflight checks ---

[[ "$(uname)" == "Darwin" ]] || die "strudel only runs on macOS"
[[ "$(uname -m)" == "arm64" ]] || die "strudel requires an Apple Silicon Mac"

# Bare-minimum tool check. Builds need swift + odin + make.
for tool in swift odin make tar curl; do
    command -v "$tool" >/dev/null 2>&1 || die "missing required tool: $tool"
done

# --- work in a temp dir, always clean it up ---

TMPDIR="$(mktemp -d -t strudel-install)"
trap 'rm -rf "$TMPDIR"' EXIT

say "Downloading strudel ${bold}${VERSION}${reset}..."
url="https://github.com/${REPO}/archive/refs/tags/${VERSION}.tar.gz"
curl -fsSL "$url" | tar -xz -C "$TMPDIR" || die "download or extract failed"

# Find the extracted directory. GitHub strips leading 'v' from the dirname.
src="${TMPDIR}/strudel-${VERSION#v}"
[[ -d "$src" ]] || die "expected directory not found: $src"

say "Building..."
(cd "$src" && make build) || die "build failed"

say "Installing to ${bold}${PREFIX}${reset} (may prompt for sudo)..."
(cd "$src" && make install PREFIX="$PREFIX") || die "install failed"

say "${green}strudel installed.${reset}"
printf "\n"
printf "  Try it: cd into a git repo, stage some changes, and run:\n"
printf "    %sstrudel%s\n\n" "$bold" "$reset"
printf "  Make sure Apple Intel
