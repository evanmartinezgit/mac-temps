#!/bin/zsh
set -eu
cd "$(dirname "$0")"
APP="$PWD/Mac Temps.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" .build/AppIcon.iconset
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" Assets/AppIcon.png --out ".build/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
    doubled=$((size * 2))
    sips -z "$doubled" "$doubled" Assets/AppIcon.png --out ".build/AppIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns .build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
xcrun swiftc -O -parse-as-library SensorCatalog.swift Sensors.swift App.swift -o "$APP/Contents/MacOS/MacTemps" -framework SwiftUI -framework AppKit -framework IOKit
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>MacTemps</string>
<key>CFBundleIdentifier</key><string>local.evans.mac-temps</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleName</key><string>Mac Temps</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
