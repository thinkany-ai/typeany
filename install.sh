#!/bin/bash
set -e

echo "🎙️  TypeAny Installer"
echo "===================="

# Check macOS version
OS_VERSION=$(sw_vers -productVersion | cut -d. -f1)
if [ "$OS_VERSION" -lt 14 ]; then
  echo "❌ Requires macOS 14 or later (you have $(sw_vers -productVersion))"
  exit 1
fi

# Check if already installed
if [ -d "/Applications/TypeAny.app" ]; then
  echo "⚠️  TypeAny is already installed. Updating..."
fi

# Check Swift / Xcode CLT
if ! command -v swift &> /dev/null; then
  echo "📦 Installing Xcode Command Line Tools..."
  xcode-select --install
  echo "   Please re-run this script after installation completes."
  exit 1
fi

# Clone or update repo
TMPDIR=$(mktemp -d)
echo "📥 Cloning TypeAny..."
git clone --depth=1 https://github.com/thinkany-ai/typeany.git "$TMPDIR/typeany"

# Build
cd "$TMPDIR/typeany"
echo "🔨 Building TypeAny..."
make build

# Install
echo "📂 Installing to /Applications..."
cp -R ".build/TypeAny.app" "/Applications/"

# Cleanup
rm -rf "$TMPDIR"

echo ""
echo "✅ TypeAny installed successfully!"
echo ""
echo "👉 Launch: open /Applications/TypeAny.app"
echo "   Or find it in Launchpad / Spotlight"
echo ""
echo "⚙️  First launch: grant Microphone, Speech Recognition & Accessibility permissions"
