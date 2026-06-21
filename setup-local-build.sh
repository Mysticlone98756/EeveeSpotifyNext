#!/usr/bin/env bash
#
# One-time local-build setup for EeveeSpotify.
#
# Why this exists:
#   The tweak depends on SwiftProtobuf and Orion. Orion ships resilient
#   .swiftinterface files, so `import Orion` works with any Swift compiler.
#   SwiftProtobuf, however, is normally shipped as a prebuilt binary .swiftmodule
#   tied to one specific Swift version (6.0.3 in CI). If your local Xcode/Swift is
#   newer (e.g. 6.3.x), `make package` fails with:
#       module compiled with Swift 6.0.3 cannot be imported by the Swift 6.3.2 compiler
#
#   This script builds SwiftProtobuf from source with YOUR local Swift toolchain,
#   emitting a resilient .swiftinterface, and installs it into $THEOS/lib. After
#   running it once, `make package` works locally with no further hassle.
#
# Usage:
#   export THEOS=~/theos        # if not already set
#   ./setup-local-build.sh
#   make package                # now works
#
set -euo pipefail

SWIFTPROTOBUF_VERSION="1.29.0"
DEPLOYMENT_TARGET="14.0"

: "${THEOS:=$HOME/theos}"
if [ ! -d "$THEOS" ]; then
    echo "error: THEOS not found at '$THEOS'. Set THEOS to your theos install." >&2
    exit 1
fi

# The Orion preprocessor builds via SwiftPM, which refuses bare cache repos unless
# this is set. Harmless global git setting recommended by git itself.
git config --global safe.bareRepository all 2>/dev/null || true

# Pick the iOS SDK shipped with theos.
SDK="$(ls -d "$THEOS"/sdks/iPhoneOS*.sdk 2>/dev/null | sort -V | tail -1 || true)"
if [ -z "$SDK" ]; then
    echo "error: no iPhoneOS SDK found under $THEOS/sdks" >&2
    exit 1
fi
echo "==> Using SDK: $SDK"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"

echo "==> Fetching SwiftProtobuf $SWIFTPROTOBUF_VERSION source"
curl -fsSL "https://github.com/apple/swift-protobuf/archive/refs/tags/${SWIFTPROTOBUF_VERSION}.tar.gz" -o sp.tgz
tar -xzf sp.tgz
cd "swift-protobuf-${SWIFTPROTOBUF_VERSION}"

echo "==> Compiling SwiftProtobuf for arm64-apple-ios${DEPLOYMENT_TARGET} with your local Swift"
mkdir -p out
swiftc \
    -sdk "$SDK" \
    -target "arm64-apple-ios${DEPLOYMENT_TARGET}" \
    -module-name SwiftProtobuf \
    -O -wmo \
    -enable-library-evolution \
    -emit-module -emit-module-path out/SwiftProtobuf.swiftmodule \
    -emit-module-interface -emit-module-interface-path out/SwiftProtobuf.swiftinterface \
    -emit-library -o out/SwiftProtobuf \
    -Xlinker -install_name -Xlinker @rpath/SwiftProtobuf.framework/SwiftProtobuf \
    Sources/SwiftProtobuf/*.swift

echo "==> Assembling SwiftProtobuf.framework"
FW="out/SwiftProtobuf.framework"
rm -rf "$FW"
mkdir -p "$FW/Modules/SwiftProtobuf.swiftmodule"
cp out/SwiftProtobuf "$FW/SwiftProtobuf"
cat > "$FW/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>org.swift.protobuf</string>
<key>CFBundleExecutable</key><string>SwiftProtobuf</string>
<key>CFBundleName</key><string>SwiftProtobuf</string>
<key>CFBundlePackageType</key><string>FMWK</string>
<key>MinimumOSVersion</key><string>14.0</string>
</dict></plist>
PLIST
for n in arm64-apple-ios arm64; do
    cp out/SwiftProtobuf.swiftmodule    "$FW/Modules/SwiftProtobuf.swiftmodule/$n.swiftmodule"
    cp out/SwiftProtobuf.swiftinterface "$FW/Modules/SwiftProtobuf.swiftmodule/$n.swiftinterface"
    cp out/SwiftProtobuf.swiftdoc       "$FW/Modules/SwiftProtobuf.swiftmodule/$n.swiftdoc"
done

echo "==> Installing into \$THEOS/lib (rootful + rootless)"
rm -rf "$THEOS/lib/SwiftProtobuf.framework" "$THEOS/lib/iphone/rootless/SwiftProtobuf.framework"
cp -r "$FW" "$THEOS/lib/"
mkdir -p "$THEOS/lib/iphone/rootless"
cp -r "$FW" "$THEOS/lib/iphone/rootless/"

echo ""
echo "Done. SwiftProtobuf built with your local Swift and installed."
echo "You can now build locally:"
echo "    make package                                  # rootful (.deb)"
echo "    make package THEOS_PACKAGE_SCHEME=rootless     # rootless (.deb)"
