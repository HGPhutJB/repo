#!/bin/bash
# Build Mochy iOS (Swift + UIKit) for iOS 12.2+ (arm64), then package:
#   dist/com.puc.mochyios_<version>_iphoneos-arm.deb   -> jailbreak (rootful, Chimera/Sileo)
#   dist/MochyiOS_<version>.ipa                          -> sideload (unsigned: sign with ESign / Sideloadly / AltStore)
# Runs on a macOS machine with Xcode (GitHub Actions: macos-latest). Needs: ldid, dpkg (brew install ldid dpkg).
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$(pwd)"

APP="MochyiOS"
BUNDLE_ID="com.puc.mochyios"
VERSION="$(tr -d '[:space:]' < VERSION)"
OUT="build"
DIST="dist"
APPDIR="$OUT/pkg/Applications/$APP.app"

rm -rf "$OUT" "$DIST"
mkdir -p "$APPDIR" "$DIST"

SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
echo "SDK: $SDK"
xcrun --sdk iphoneos swiftc --version

echo "==> Compiling Swift (arm64, iOS 12.2+)"
xcrun --sdk iphoneos swiftc \
  -target arm64-apple-ios12.2 \
  -sdk "$SDK" \
  -swift-version 5 \
  -O -whole-module-optimization \
  -parse-as-library \
  -module-name MochyiOS \
  Sources/*.swift \
  -o "$APPDIR/$APP"

echo "==> Binary info"
file "$APPDIR/$APP" || true
xcrun vtool -show-build "$APPDIR/$APP" 2>/dev/null | head -n 12 || true
otool -L "$APPDIR/$APP" | head -n 30 || true
otool -l "$APPDIR/$APP" | grep -A2 LC_RPATH || true

echo "==> Assembling bundle"
cp app/Info.plist "$APPDIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APPDIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$APPDIR/Info.plist"
cp -R app/Resources/. "$APPDIR/"
printf 'APPL????' > "$APPDIR/PkgInfo"

echo "==> Compiling launch screen"
if xcrun ibtool --errors --warnings --notices \
     --minimum-deployment-target 12.0 --target-device iphone \
     --output-format human-readable-text \
     --compile "$APPDIR/LaunchScreen.storyboardc" app/LaunchScreen.storyboard; then
  echo "LaunchScreen.storyboardc OK"
else
  echo "WARNING: ibtool failed, falling back to the PNG launch images"
  rm -rf "$APPDIR/LaunchScreen.storyboardc"
  /usr/libexec/PlistBuddy -c "Delete :UILaunchStoryboardName" "$APPDIR/Info.plist" || true
fi
find "$OUT" -name '.DS_Store' -delete

echo "==> Preparing the .ipa payload (before the jailbreak entitlements are applied)"
IPA_ROOT="$OUT/ipa"
mkdir -p "$IPA_ROOT/Payload"
cp -R "$APPDIR" "$IPA_ROOT/Payload/$APP.app"
# Pseudo-sign without private entitlements: ESign / Sideloadly / AltStore re-sign it with the user's certificate.
ldid -S "$IPA_ROOT/Payload/$APP.app/$APP"

echo "==> Pseudo-signing the .deb binary with ldid (jailbreak entitlements)"
ldid -Sapp/entitlements.plist "$APPDIR/$APP"

echo "==> Packaging .deb"
mkdir -p "$OUT/pkg/DEBIAN"
cp deb/DEBIAN/postinst deb/DEBIAN/postrm "$OUT/pkg/DEBIAN/"
sed "s/@VERSION@/$VERSION/" deb/DEBIAN/control > "$OUT/pkg/DEBIAN/control"
chmod 755 "$OUT/pkg/DEBIAN/postinst" "$OUT/pkg/DEBIAN/postrm"
find "$OUT/pkg/Applications" -type d -exec chmod 755 {} +
find "$OUT/pkg/Applications" -type f -exec chmod 644 {} +
chmod 755 "$APPDIR/$APP"

export COPYFILE_DISABLE=1
DEB="$DIST/${BUNDLE_ID}_${VERSION}_iphoneos-arm.deb"
dpkg-deb --root-owner-group -Zgzip -b "$OUT/pkg" "$DEB"

echo "==> Packaging .ipa"
find "$IPA_ROOT/Payload" -type d -exec chmod 755 {} +
find "$IPA_ROOT/Payload" -type f -exec chmod 644 {} +
chmod 755 "$IPA_ROOT/Payload/$APP.app/$APP"
(cd "$IPA_ROOT" && zip -qry "$ROOT/$DIST/${APP}_${VERSION}.ipa" Payload)

echo "==> Done"
ls -l "$DIST"
dpkg-deb -I "$DEB" | head -n 15
