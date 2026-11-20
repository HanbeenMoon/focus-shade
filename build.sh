#!/bin/sh
set -eu
source_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
bundle=${1:?Pass an unused output path ending in .app}
if [ -e "$bundle" ]; then
    printf '%s\n' "Output path is already in use: $bundle" >&2
    exit 1
fi
scratch=$(mktemp -d "${TMPDIR:-/tmp}/focus-shade.XXXXXXXX")
trap 'rm -rf -- "$scratch"' EXIT HUP INT TERM
stage="$scratch/Shade.app"
mkdir -p "$stage/Contents/MacOS" "$stage/Contents/Resources" "$scratch/Shade.iconset"
cp "$source_dir/Info.plist" "$stage/Contents/"
xcrun swift "$source_dir/make-icon.swift" "$scratch/Shade.iconset"
iconutil -c icns "$scratch/Shade.iconset" -o "$stage/Contents/Resources/Shade.icns"
xcrun swiftc -warnings-as-errors -O -target "$(uname -m)-apple-macos13.0" \
    "$source_dir/main.swift" "$source_dir/ShadeGeometry.swift" -o "$stage/Contents/MacOS/FocusShade"
plutil -lint "$stage/Contents/Info.plist"
codesign --sign - "$stage"
codesign --verify --strict "$stage"
mv -n "$stage" "$bundle"
test ! -e "$stage"
