#!/usr/bin/env bash
#
# Assemble a LiveContainer "Tweaks" folder for EeveeSpotify.
#
# LiveContainer loads a tweak .dylib via dlopen, but the EeveeSpotify dylib depends
# on @rpath/SwiftProtobuf.framework and @rpath/Orion.framework (which itself weakly
# links @rpath/CydiaSubstrate.framework). Those frameworks must sit next to the
# dylib in the Tweaks folder or dlopen fails with "Library not loaded: @rpath/...".
#
# This builds the .deb if needed, then drops the dylib + all three frameworks
# (ad-hoc signed) into ./dist/lc-spot/. Copy the CONTENTS of that folder into your
# LiveContainer Tweaks subfolder, e.g. .../Documents/Tweaks/spot/.
#
# Usage:
#   ./build-lc.sh
#
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"
export THEOS="${THEOS:-$HOME/theos}"

INJ="$PROJECT_DIR/Tools/injection"
OUT="$PROJECT_DIR/dist/lc-spot"

# 1. Ensure a tweak .deb exists.
DEB="$(ls -t "$PROJECT_DIR"/packages/*_iphoneos-arm.deb 2>/dev/null | head -1 || true)"
if [ -z "$DEB" ]; then
    echo "==> No tweak .deb found, building with: make package"
    make package
    DEB="$(ls -t "$PROJECT_DIR"/packages/*_iphoneos-arm.deb 2>/dev/null | head -1 || true)"
fi
[ -n "$DEB" ] || { echo "error: no .deb produced (run ./setup-local-build.sh first)" >&2; exit 1; }

command -v ldid >/dev/null 2>&1 || { echo "error: ldid not found (brew install ldid)" >&2; exit 1; }

# 2. Fresh output dir.
rm -rf "$OUT"; mkdir -p "$OUT"

# 3. Extract the dylib AND SwiftProtobuf.framework from the SAME .deb.
#    Critical: the SwiftProtobuf the tweak was linked against is bundled inside the
#    .deb (via the Makefile internal-stage step). Shipping any other SwiftProtobuf
#    build causes "Symbol not found" at load time, because Swift symbol sets differ
#    between SwiftProtobuf builds/compilers.
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
( cd "$tmp" && ar -x "$DEB" && { tar --lzma -xf data.tar.* 2>/dev/null || tar -xf data.tar.*; } )
DY="$(find "$tmp" -name 'EeveeSpotify.dylib' -path '*DynamicLibraries*' | head -1)"
SP_FW="$(find "$tmp" -name SwiftProtobuf.framework -type d | head -1)"
BUNDLE="$(find "$tmp" -name 'EeveeSpotify.bundle' -type d | head -1)"
[ -n "$DY" ]    || { echo "error: EeveeSpotify.dylib not found in $DEB" >&2; exit 1; }
[ -n "$SP_FW" ] || { echo "error: SwiftProtobuf.framework not found in $DEB" >&2; exit 1; }
[ -n "$BUNDLE" ] || { echo "error: EeveeSpotify.bundle not found in $DEB" >&2; exit 1; }
cp "$DY" "$OUT/EeveeSpotify.dylib"
cp -r "$SP_FW" "$OUT/SwiftProtobuf.framework"
# Resource bundle with localizations — BundleHelper finds it next to the dylib.
cp -r "$BUNDLE" "$OUT/EeveeSpotify.bundle"

# 4. Orion is a HARD dependency of the tweak (@rpath/Orion.framework/Orion, not
#    weak) and LiveContainer does NOT provide it, so it must ship here.
#    Do NOT bundle CydiaSubstrate: Orion only weak-links it, and LiveContainer
#    already provides a substrate runtime — a second CydiaSubstrate conflicts and
#    crashes the app on launch.
cp -r "$INJ/Orion.framework" "$OUT/Orion.framework"

# 6. Ad-hoc sign so LiveContainer can load it.
ldid -S "$OUT/EeveeSpotify.dylib"
ldid -S "$OUT/SwiftProtobuf.framework/SwiftProtobuf"
ldid -S "$OUT/Orion.framework/Orion"

# 7. Also zip it for easy transfer to the device (AirDrop / Files).
ZIP="$PROJECT_DIR/dist/lc-spot.zip"
rm -f "$ZIP"
( cd "$OUT" && zip -qry "$ZIP" . )

echo ""
echo "Done. LiveContainer tweak folder:"
echo "    $OUT"
ls -1 "$OUT"
echo ""
echo "Zip (one file to AirDrop): $ZIP"
echo ""
echo "Copy the contents into your LiveContainer Tweaks subfolder, e.g.:"
echo "    .../Documents/Tweaks/spot/"
