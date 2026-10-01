#!/bin/bash
# 构建可分发的 TypeAny：打包 librime 依赖 → Developer ID 签名（hardened runtime）→ 公证 → staple → DMG + ZIP
#
# 需要的环境变量（与 Spotcat / Termany 相同）：
#   APPLE_SIGNING_IDENTITY  如 "Developer ID Application: Name (TEAMID)"，证书需在钥匙串中
#   APPLE_ID                Apple ID 邮箱
#   APPLE_PASSWORD          App 专用密码（appleid.apple.com 生成）
#   APPLE_TEAM_ID           开发者团队 ID
#
# 用法：
#   ./scripts/release.sh             产物输出到 dist/
#   ./scripts/release.sh --publish   另外发布 GitHub Release v<版本> 并上传产物（需要 gh 已登录）；
#                                    版本号带 "-"（如 0.3.0-beta.1）时标记为预发布
#
# 版本号取自 Sources/TypeAny/Resources/Info.plist 的 CFBundleShortVersionString。
# 构建依赖 Homebrew 的 librime / opencc（brew install librime opencc），产物为 Apple silicon（arm64）。
set -euo pipefail
cd "$(dirname "$0")/.."

: "${APPLE_SIGNING_IDENTITY:?set APPLE_SIGNING_IDENTITY}"
: "${APPLE_ID:?set APPLE_ID}"
: "${APPLE_PASSWORD:?set APPLE_PASSWORD}"
: "${APPLE_TEAM_ID:?set APPLE_TEAM_ID}"

PUBLISH="${1:-}"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Sources/TypeAny/Resources/Info.plist)
APP=".build/TypeAny.app"
ENTITLEMENTS="Sources/TypeAny/Resources/TypeAny.entitlements"
DIST="dist"
ZIP="$DIST/TypeAny-$VERSION.zip"
DMG="$DIST/TypeAny-$VERSION.dmg"

notarize() {
  xcrun notarytool submit "$1" \
    --apple-id "$APPLE_ID" --password "$APPLE_PASSWORD" --team-id "$APPLE_TEAM_ID" --wait
}

sign() {
  codesign --force --options runtime --timestamp --sign "$APPLE_SIGNING_IDENTITY" "$@"
}

echo "==> [1/7] Build release app (v$VERSION)"
make build VARIANT=release SIGN_IDENTITY=-

echo "==> [2/7] Bundle librime and its plugins"
./scripts/bundle-libs.sh "$APP"

echo "==> [3/7] Sign with Developer ID (hardened runtime), libraries first"
find "$APP/Contents/Frameworks" -name '*.dylib' -print0 | while IFS= read -r -d '' lib; do sign "$lib"; done
sign --entitlements "$ENTITLEMENTS" "$APP"
codesign --verify --strict --verbose=2 "$APP"
"$APP/Contents/MacOS/TypeAny" --self-test

echo "==> [4/7] Notarize and staple the app"
rm -rf "$DIST" && mkdir -p "$DIST"
ditto -c -k --keepParent "$APP" "$DIST/notarize.zip"
notarize "$DIST/notarize.zip"
rm "$DIST/notarize.zip"
xcrun stapler staple "$APP"

echo "==> [5/7] Package ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> [6/7] Package, sign, notarize and staple DMG"
# No Applications link: opening TypeAny from the DMG installs it into ~/Library/Input Methods
STAGING=$(mktemp -d)
cp -R "$APP" "$STAGING/"
hdiutil create -volname "TypeAny $VERSION" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGING"
codesign --force --timestamp --sign "$APPLE_SIGNING_IDENTITY" "$DMG"
notarize "$DMG"
xcrun stapler staple "$DMG"

echo "==> [7/7] Verify"
spctl --assess --type execute --verbose "$APP"
spctl --assess --type open --context context:primary-signature --verbose "$DMG"
(cd "$DIST" && shasum -a 256 "$(basename "$ZIP")" "$(basename "$DMG")" > SHA256SUMS.txt)
ls -lh "$DIST"

if [ "$PUBLISH" = "--publish" ]; then
  if gh release view "v$VERSION" >/dev/null 2>&1; then
    echo "==> Upload to existing GitHub Release v$VERSION"
    gh release upload "v$VERSION" "$DMG" "$ZIP" "$DIST/SHA256SUMS.txt" --clobber
  else
    echo "==> Publish GitHub Release v$VERSION"
    PRERELEASE=()
    [[ "$VERSION" == *-* ]] && PRERELEASE=(--prerelease)
    gh release create "v$VERSION" "$DMG" "$ZIP" "$DIST/SHA256SUMS.txt" \
      --title "TypeAny v$VERSION" --generate-notes ${PRERELEASE[@]+"${PRERELEASE[@]}"}
  fi
fi
