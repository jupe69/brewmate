#!/bin/bash

# Taphouse Project Generator
# This script generates the Xcode project using XcodeGen

set -e

echo "🍺 Taphouse Project Generator"
echo "=============================="

# Check if XcodeGen is installed
if ! command -v xcodegen &> /dev/null; then
    echo ""
    echo "❌ XcodeGen is not installed."
    echo ""
    echo "Install it using Homebrew:"
    echo "  brew install xcodegen"
    echo ""
    echo "Or using Mint:"
    echo "  mint install yonaskolb/XcodeGen"
    echo ""
    exit 1
fi

# Navigate to script directory
cd "$(dirname "$0")"

echo ""
echo "📦 Generating Xcode project..."

# Generate the project
xcodegen generate

echo ""
echo "✅ Project generated successfully!"
echo ""
echo "📂 Open the project:"
echo "  open Taphouse.xcodeproj"
echo ""
echo "🔧 Build and run:"
echo "  1. Open Taphouse.xcodeproj in Xcode"
echo "  2. Select the Taphouse scheme"
echo "  3. Press ⌘R to build and run"
echo ""
echo "⚠️  Note: The app requires Homebrew to be installed on your Mac."
echo "   Visit https://brew.sh to install Homebrew if needed."
echo ""
