#!/bin/bash
# Taphouse Release Build Script
# Usage: ./scripts/build-release.sh

set -e

# Configuration
APP_NAME="Taphouse"
TEAM_ID="CN8K2J7G4H"
CERT_NAME="Developer ID Application: ATHANASIOS CHONIAS (CN8K2J7G4H)"
KEYCHAIN_PROFILE="notarytool-profile"
SPARKLE_BIN="$HOME/Downloads/Sparkle-2.8.1/bin"

# Paths
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build/release"
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"

echo "🔨 Building $APP_NAME for release..."

# Clean and create build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Generate Xcode project
echo "📦 Generating Xcode project..."
cd "$PROJECT_DIR"
xcodegen generate

# Archive
echo "📦 Archiving..."
xcodebuild archive \
    -project "$APP_NAME.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$CERT_NAME" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    OTHER_CODE_SIGN_FLAGS="--timestamp --options=runtime" \
    | grep -E "(Archive|error:|warning:)" || true

# Export
echo "📤 Exporting..."
cat > "$BUILD_DIR/ExportOptions.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>$TEAM_ID</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>Developer ID Application</string>
</dict>
</plist>
EOF

xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" \
    | grep -E "(Export|error:|warning:)" || true

# Re-sign embedded frameworks (Sparkle)
echo "🔏 Signing embedded frameworks..."
APP_PATH="$EXPORT_PATH/$APP_NAME.app"

codesign --force --options runtime --timestamp --sign "$CERT_NAME" \
    "$APP_PATH/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Downloader.xpc"
codesign --force --options runtime --timestamp --sign "$CERT_NAME" \
    "$APP_PATH/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Installer.xpc"
codesign --force --options runtime --timestamp --sign "$CERT_NAME" \
    "$APP_PATH/Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app"
codesign --force --options runtime --timestamp --sign "$CERT_NAME" \
    "$APP_PATH/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate"
codesign --force --options runtime --timestamp --sign "$CERT_NAME" \
    "$APP_PATH/Contents/Frameworks/Sparkle.framework"
codesign --force --options runtime --timestamp --sign "$CERT_NAME" \
    --entitlements "$PROJECT_DIR/Taphouse/Taphouse.entitlements" \
    "$APP_PATH"

# Create ZIP for notarization
echo "📦 Creating ZIP for notarization..."
cd "$EXPORT_PATH"
ditto -c -k --keepParent "$APP_NAME.app" "$APP_NAME.zip"

# Notarize
echo "🍎 Notarizing (this may take a few minutes)..."
xcrun notarytool submit "$APP_NAME.zip" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait

# Staple
echo "📎 Stapling..."
xcrun stapler staple "$APP_PATH"

# Create DMG
echo "💿 Creating DMG..."
mkdir -p dmg_contents
cp -R "$APP_NAME.app" dmg_contents/
ln -s /Applications dmg_contents/Applications
hdiutil create -volname "$APP_NAME" -srcfolder dmg_contents -ov -format UDZO "$DMG_PATH"
rm -rf dmg_contents "$APP_NAME.zip"

# Notarize DMG
echo "🍎 Notarizing DMG..."
xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait

# Staple DMG
xcrun stapler staple "$DMG_PATH"

# Create Sparkle update archive
echo "✨ Creating Sparkle update archive..."
APPCAST_DIR="$BUILD_DIR/appcast"
mkdir -p "$APPCAST_DIR"

# Create a ZIP for Sparkle updates (separate from notarization zip)
cd "$EXPORT_PATH"
ditto -c -k --keepParent "$APP_NAME.app" "$APPCAST_DIR/$APP_NAME.zip"

# Sign the update with Sparkle EdDSA key
echo "🔐 Signing update for Sparkle..."
SIGNATURE=$("$SPARKLE_BIN/sign_update" "$APPCAST_DIR/$APP_NAME.zip")
echo "Sparkle signature: $SIGNATURE"

# Get version from the app
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$APP_PATH/Contents/Info.plist")

# Generate appcast entry
echo "📝 Generating appcast entry..."
cat > "$APPCAST_DIR/appcast-entry.xml" << EOF
<!-- Add this item to your appcast.xml -->
<item>
    <title>Version $VERSION</title>
    <sparkle:version>$BUILD</sparkle:version>
    <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
    <pubDate>$(date -R)</pubDate>
    <enclosure url="https://taphouse.multimodalsolutions.gr/downloads/Taphouse.zip"
               $SIGNATURE
               type="application/octet-stream"/>
</item>
EOF

echo ""
echo "✅ Build complete!"
echo ""
echo "📍 DMG for distribution: $DMG_PATH"
echo "📦 DMG Size: $(du -h "$DMG_PATH" | cut -f1)"
echo ""
echo "📍 Sparkle update ZIP: $APPCAST_DIR/$APP_NAME.zip"
echo "📝 Appcast entry: $APPCAST_DIR/appcast-entry.xml"
echo ""
echo "📋 Next steps:"
echo "   1. Upload DMG to your website for new users"
echo "   2. Upload Taphouse.zip to https://taphouse.multimodalsolutions.gr/downloads/"
echo "   3. Update appcast.xml with the entry from appcast-entry.xml"
