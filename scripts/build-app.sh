#!/bin/sh
# Builds UsageBar.app into ./build (ad-hoc signed, needs no permissions).
# VERSION (e.g. v1.2.3, from the release tag in CI) sets the bundle version; defaults to dev.
# UNIVERSAL=1 builds arm64 + x86_64 (needs full Xcode, as on CI); otherwise the host arch only.
# With ZIP=1 it also writes dist/UsageBar-$VERSION-macos-<arch>.zip.
set -e
cd "$(dirname "$0")/.."
VERSION=${VERSION:-dev}
short=${VERSION#v}
# The bundle version keys want dotted numerics, so anything that is not a release reports
# 0.0.0 there; the full VERSION and the commit go in UBBuildVersion/UBBuildCommit for the UI.
case "$short" in
  [0-9]*.[0-9]*.[0-9]*) ;;
  *) short=0.0.0 ;;
esac
commit=${GITHUB_SHA:-$(git rev-parse HEAD 2>/dev/null || echo unknown)}
commit=$(printf '%.7s' "$commit")
if [ -z "$GITHUB_SHA" ] && [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  commit="$commit-dirty"
fi

if [ "${UNIVERSAL:-0}" = 1 ]; then
  set -- --arch arm64 --arch x86_64
  arch=universal
else
  set --
  arch=$(uname -m)
fi
swift build -c release "$@"
bin=$(swift build -c release "$@" --show-bin-path)
app=build/UsageBar.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin/UsageBar" "$app/Contents/MacOS/UsageBar"
# The status line helper the app installs into ~/.claude/usagebar. Signed on its own first:
# it is copied out of the bundle, and arm64 will not run an unsigned binary.
cp "$bin/usagebar-hook" "$app/Contents/MacOS/usagebar-hook"
codesign --force --sign - "$app/Contents/MacOS/usagebar-hook"
# Regenerate with scripts/make-icon.sh after editing scripts/make-icon.swift.
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
cat > "$app/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>UsageBar</string>
  <key>CFBundleIdentifier</key><string>local.usagebar</string>
  <key>CFBundleName</key><string>UsageBar</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$short</string>
  <key>CFBundleVersion</key><string>$short</string>
  <key>UBBuildVersion</key><string>$VERSION</string>
  <key>UBBuildCommit</key><string>$commit</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
EOF
codesign --force --sign - "$app"
echo "Built $app ($VERSION, $commit, $(lipo -archs "$app/Contents/MacOS/UsageBar"))"

if [ "${ZIP:-0}" = 1 ]; then
  # ditto keeps the bundle's signature and metadata intact where zip -r would not.
  mkdir -p dist
  zip="dist/UsageBar-$VERSION-macos-$arch.zip"
  rm -f "$zip"
  ditto -c -k --sequesterRsrc --keepParent "$app" "$zip"
  ls -la "$zip"
fi
