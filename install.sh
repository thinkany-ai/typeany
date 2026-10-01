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
if [ -d "$HOME/Library/Input Methods/TypeAny.app" ]; then
  echo "⚠️  TypeAny is already installed. Updating..."
fi

# Check Swift / Xcode CLT
if ! command -v swift &> /dev/null; then
  echo "📦 Installing Xcode Command Line Tools..."
  xcode-select --install
  echo "   Please re-run this script after installation completes."
  exit 1
fi

# Pinyin engine
if ! command -v brew &> /dev/null; then
  echo "❌ Homebrew is required to install librime: https://brew.sh"
  exit 1
fi
echo "📦 Installing librime and OpenCC..."
brew install librime opencc

# Clone or update repo
TMPDIR=$(mktemp -d)
echo "📥 Cloning TypeAny..."
git clone --depth=1 https://github.com/thinkany-ai/typeany.git "$TMPDIR/typeany"

# Build
cd "$TMPDIR/typeany"
echo "🔨 Building and installing TypeAny..."
make install VARIANT=release

# Cleanup
rm -rf "$TMPDIR"

echo ""
echo "✅ TypeAny installed successfully!"
echo ""
echo "👉 Switch to「TypeAny 拼音」from the input menu in the menu bar"
echo "   (or System Settings → Keyboard → Input Sources → add TypeAny)"
echo ""
echo "⚙️  First use: grant Microphone, Speech Recognition & Accessibility permissions"
