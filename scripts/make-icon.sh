#!/bin/sh
# Regenerates Resources/AppIcon.icns (and docs/icon.png for the README) from make-icon.swift.
set -e
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
swift scripts/make-icon.swift "$tmp/icon.png"
set_dir="$tmp/AppIcon.iconset"
mkdir -p "$set_dir" Resources docs
for s in 16 32 128 256 512; do
  sips -z $s $s "$tmp/icon.png" --out "$set_dir/icon_${s}x${s}.png" >/dev/null
  sips -z $((s * 2)) $((s * 2)) "$tmp/icon.png" --out "$set_dir/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$set_dir" -o Resources/AppIcon.icns
sips -z 256 256 "$tmp/icon.png" --out docs/icon.png >/dev/null
rm -rf "$tmp"
echo "Wrote Resources/AppIcon.icns and docs/icon.png"
