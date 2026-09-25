#!/bin/sh
# Builds UsageBar.app into ./build (ad-hoc signed, sandbox-free but needs no permissions).
set -e
cd "$(dirname "$0")/.."
swift build -c release
app=build/UsageBar.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp .build/release/UsageBar "$app/Contents/MacOS/UsageBar"
cat > "$app/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>UsageBar</string>
  <key>CFBundleIdentifier</key><string>local.usagebar</string>
  <key>CFBundleName</key><string>UsageBar</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
EOF
codesign --force --sign - "$app"
echo "Built $app"
