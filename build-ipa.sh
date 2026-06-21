#!/usr/bin/env bash
#
# Build an installable EeveeSpotify IPA from a decrypted Spotify IPA.
#
# It (1) builds the tweak .deb locally if one isn't present, then (2) injects it
# (plus SwiftProtobuf + Orion, vendored in Tools/injection/) into a copy of your
# decrypted Spotify IPA using cyan (pyzule-rw), and writes the result to ./dist/.
#
# We use cyan rather than ivinject because ivinject (NativeAOT .NET) crashes on
# recent/beta macOS. Local .deb building needs a one-time `./setup-local-build.sh`.
#
# Usage:
#   ./build-ipa.sh <decrypted-spotify.ipa>
#   ./build-ipa.sh                      # auto-picks newest *Spotify*.ipa in ~/Downloads
#
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

export THEOS="${THEOS:-$HOME/theos}"
INJ="$PROJECT_DIR/Tools/injection"
DIST="$PROJECT_DIR/dist"
mkdir -p "$DIST"

# ---- 1. Resolve the input decrypted IPA -------------------------------------
INPUT_IPA="${1:-}"
if [ -z "$INPUT_IPA" ]; then
    # Newest *decrypted* Spotify IPA in Downloads (filenames may contain odd
    # unicode chars). Exclude our own already-injected EeveeSpotify outputs so we
    # never inject on top of an injected build.
    INPUT_IPA="$(ls -t "$HOME"/Downloads/*[Ss]potify*.ipa 2>/dev/null | grep -v EeveeSpotify | head -1 || true)"
fi
if [ -z "$INPUT_IPA" ] || [ ! -f "$INPUT_IPA" ]; then
    echo "error: no input IPA. Pass it as an argument:" >&2
    echo "       ./build-ipa.sh /path/to/decrypted-spotify.ipa" >&2
    exit 1
fi
echo "==> Input IPA: $INPUT_IPA"

# ---- 2. Ensure a tweak .deb exists (build if missing) -----------------------
DEB="$(ls -t "$PROJECT_DIR"/packages/*_iphoneos-arm.deb 2>/dev/null | head -1 || true)"
if [ -z "$DEB" ]; then
    echo "==> No .deb found, building with: make package"
    make package
    DEB="$(ls -t "$PROJECT_DIR"/packages/*_iphoneos-arm.deb 2>/dev/null | head -1 || true)"
fi
if [ -z "$DEB" ]; then
    echo "error: build produced no .deb. Run ./setup-local-build.sh first." >&2
    exit 1
fi
echo "==> Tweak .deb: $DEB"

# ---- 3. Dependencies --------------------------------------------------------
# SwiftProtobuf MUST be the exact build the tweak was linked against — it's bundled
# inside the .deb itself. Using any other SwiftProtobuf causes a runtime
# "Symbol not found" crash. Extract it from the .deb we're injecting.
ORION_FW="$INJ/Orion.framework"
[ -d "$ORION_FW" ] || { echo "error: missing $ORION_FW" >&2; exit 1; }

SP_TMP="$(mktemp -d)"; trap 'rm -rf "$SP_TMP"' EXIT
( cd "$SP_TMP" && ar -x "$DEB" && { tar --lzma -xf data.tar.* 2>/dev/null || tar -xf data.tar.*; } )
SP_FW="$(find "$SP_TMP" -name SwiftProtobuf.framework -type d | head -1)"
[ -n "$SP_FW" ] || { echo "error: SwiftProtobuf.framework not found inside $DEB" >&2; exit 1; }

# ---- 4. Inject with cyan ----------------------------------------------------
if ! command -v cyan >/dev/null 2>&1; then
    echo "error: 'cyan' (pyzule-rw) not found in PATH." >&2
    exit 1
fi

VERSION="$(awk -F'\"' '/static let version =/{print $2; exit}' Sources/EeveeSpotify/Tweak.x.swift 2>/dev/null || echo "dev")"
OUTPUT="$DIST/EeveeSpotify-${VERSION}.ipa"

# cyan can't read the original in place if its name has odd chars; stage a copy.
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
cp "$INPUT_IPA" "$WORK/spotify.ipa"

echo "==> Injecting with cyan..."
cyan -i "$WORK/spotify.ipa" -o "$OUTPUT" \
    -f "$DEB" "$SP_FW" "$ORION_FW" \
    -u -w -d -s -q -e --overwrite -c 6

echo ""
echo "Done. IPA written to:"
echo "    $OUTPUT"
echo "Sideload it with Sideloadly / ksign (it is only fakesigned)."
