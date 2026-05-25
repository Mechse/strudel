#!/usr/bin/env bash
# Installer for saft — Apple Intelligence powered git commit message generator.
# https://github.com/Mechse/saft
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Mechse/saft/master/install.sh | bash
#
# Or, to install a specific version:
#   curl -fsSL https://raw.githubusercontent.com/Mechse/saft/master/install.sh | bash -s -- v0.1.2

set -euo pipefail

REPO="Mechse/saft"
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

# Resolve version: explicit arg, or fetch latest release from GitHub.
if [ -z "${1:-}" ]; then
    VERSION=$(curl -fsSL "https://api.github.com/repos/${REPO}/tags" \
    | grep '"name":' \
    | head -1 \
    | sed -E 's/.*"([^"]+)".*/\1/')
    [ -z "$VERSION" ] && die "could not determine latest release. Pass a version: bash install.sh v0.1.2"
else
    VERSION="$1"
fi

say()  { printf "%s==>%s %s\n" "$green" "$reset" "$*"; }
warn() { printf "%s==> warning:%s %s\n" "$red" "$reset" "$*" >&2; }
die()  { printf "%s==> error:%s %s\n" "$red" "$reset" "$*" >&2; exit 1; }

# --- preflight checks ---

[[ "$(uname)" == "Darwin" ]] || die "saft only runs on macOS"
[[ "$(uname -m)" == "arm64" ]] || die "saft requires an Apple Silicon Mac"

# Bare-minimum tool check. Builds need swift + odin + make.
for tool in swift odin make tar curl; do
    command -v "$tool" >/dev/null 2>&1 || die "missing required tool: $tool"
done

# --- work in a temp dir, always clean it up ---

TMPDIR="$(mktemp -d -t saft-install)"
trap 'rm -rf "$TMPDIR"' EXIT

say "Downloading saft ${bold}${VERSION}${reset}..."
url="https://github.com/${REPO}/archive/refs/tags/${VERSION}.tar.gz"
curl -fsSL "$url" | tar -xz -C "$TMPDIR" || die "download or extract failed"

# Find the extracted directory. GitHub strips leading 'v' from the dirname.
src="${TMPDIR}/saft-${VERSION#v}"
[[ -d "$src" ]] || die "expected directory not found: $src"

say "Building..."
(cd "$src" && make build) || die "build failed"

say "Installing to ${bold}${PREFIX}${reset} (may prompt for sudo)..."
(cd "$src" && make install PREFIX="$PREFIX") || die "install failed"

say "${green}saft installed.${reset}"
printf "\n"
printf "  Try it: cd into a git repo, stage some changes, and run:\n"
printf "    %ssaft%s\n\n" "$bold" "$reset"
printf "  Make sure Apple Intelligence is enabled:\n"
printf "    System Settings → Apple Intelligence %s& Siri\n\n" "&"
