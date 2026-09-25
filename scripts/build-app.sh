#!/bin/sh
# Builds UsageBar.app into ./build (ad-hoc signed, needs no permissions).
# VERSION (e.g. v1.2.3, from the release tag in CI) sets the bundle version; defaults to dev.
# With ZIP=1 it also writes dist/UsageBar-$VERSION-macos-arm64.zip.
set -e
cd "$(dirname "$0")/.."
VERSION=${VERSION:-dev}
short=${VERSION#v}
# CFBundleVersion must be numeric; non-release builds get 0.
case "$short" in
  [0-9]*.[0-9]*.[0-9]*) build=$short ;;
  *) build=0 ;;
esac

swift build -c release
app=build/UsageBar.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp .build/release/UsageBar "$app/Contents/MacOS/UsageBar"
cat > "$app/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>UsageBar</string>
  <key>CFBundleIdentifier</key><string>local.usagebar</string>
  <key>CFBundleName</key><string>UsageBar</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$short</string>
  <key>CFBundleVersion</key><string>$build</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
EOF
codesign --force --sign - "$app"
echo "Built $app ($short)"

if [ "${ZIP:-0}" = 1 ]; then
  # ditto keeps the bundle's signature and metadata intact where zip -r would not.
  mkdir -p dist
  zip="dist/UsageBar-$VERSION-macos-arm64.zip"
  rm -f "$zip"
  ditto -c -k --sequesterRsrc --keepParent "$app" "$zip"
  ls -la "$zip"
fi
