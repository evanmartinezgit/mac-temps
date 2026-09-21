#!/bin/zsh
set -eu
cd "$(dirname "$0")"
./build.sh
mkdir -p dist .build/package
# Disable relocation so an existing copy elsewhere does not redirect installation.
cat > .build/package/components.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><array><dict>
<key>RootRelativeBundlePath</key><string>Mac Temps.app</string>
<key>BundleIsRelocatable</key><false/>
<key>BundleIsVersionChecked</key><true/>
<key>BundleHasStrictIdentifier</key><true/>
<key>BundleOverwriteAction</key><string>upgrade</string>
</dict></array></plist>
PLIST
stage=$(mktemp -d "$PWD/.build/package/root.XXXXXX")
trap 'rm -rf "$stage"' EXIT
ditto "Mac Temps.app" "$stage/Mac Temps.app"
pkgbuild --root "$stage" --component-plist .build/package/components.plist \
    --identifier local.evans.mac-temps.installer --version 1.0.0 \
    --install-location /Applications .build/package/component.pkg
cat > .build/package/Distribution.xml <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
<title>Mac Temps</title>
<options customize="never" require-scripts="false" hostArchitectures="arm64"/>
<allowed-os-versions><os-version min="14.0"/></allowed-os-versions>
<domains enable_anywhere="false" enable_currentUserHome="false" enable_localSystem="true"/>
<choices-outline><line choice="default"/></choices-outline>
<choice id="default" visible="false"><pkg-ref id="local.evans.mac-temps.installer"/></choice>
<pkg-ref id="local.evans.mac-temps.installer" version="1.0.0" onConclusion="none">component.pkg</pkg-ref>
</installer-gui-script>
XML
productbuild --distribution .build/package/Distribution.xml --package-path .build/package dist/Mac-Temps-Apple-Silicon.pkg
(cd dist && shasum -a 256 Mac-Temps-Apple-Silicon.pkg > SHA256SUMS.txt)
echo "Installer ready: dist/Mac-Temps-Apple-Silicon.pkg"
