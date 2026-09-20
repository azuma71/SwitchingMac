#!/bin/bash
# 配布用の Release ビルドを作り、dist/ に zip を出力する。
set -euo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly DIST_DIR="$PROJECT_ROOT/dist"
readonly DERIVED_DATA="$PROJECT_ROOT/.build/release"
readonly STAGING_NAME="SwitchingMac"

cd "$PROJECT_ROOT"

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "エラー: XcodeGen が必要です。brew install xcodegen を実行してください。" >&2
    exit 1
fi

# project.yml の MARKETING_VERSION を配布物の版数として使う
VERSION="$(sed -n 's/.*MARKETING_VERSION: *"\(.*\)".*/\1/p' project.yml | head -1)"
if [ -z "$VERSION" ]; then
    echo "エラー: project.yml からバージョンを取得できませんでした。" >&2
    exit 1
fi

echo "SwitchingMac $VERSION の配布物を作成します。"

echo "  Xcode プロジェクトを生成しています..."
xcodegen generate >/dev/null

echo "  Release 構成でビルドしています..."
rm -rf "$DERIVED_DATA" "$DIST_DIR"
xcodebuild build \
    -project SwitchingMac.xcodeproj \
    -scheme SwitchingMac \
    -configuration Release \
    -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED_DATA" \
    >/dev/null

readonly BUILT_APP="$DERIVED_DATA/Build/Products/Release/SwitchingMac.app"
if [ ! -d "$BUILT_APP" ]; then
    echo "エラー: ビルド結果が見つかりません: $BUILT_APP" >&2
    exit 1
fi

echo "  署名を検証しています..."
codesign --verify --strict "$BUILT_APP"

echo "  配布フォルダを組み立てています..."
readonly STAGING="$DIST_DIR/$STAGING_NAME"
mkdir -p "$STAGING"
ditto "$BUILT_APP" "$STAGING/SwitchingMac.app"
# 拡張属性を落としておく（zip 内に AppleDouble が混ざると展開後の署名検証が失敗する）
xattr -cr "$STAGING/SwitchingMac.app"
codesign --verify --strict "$STAGING/SwitchingMac.app"
cp "$PROJECT_ROOT/scripts/install.sh" "$STAGING/install.sh"
cp "$PROJECT_ROOT/scripts/INSTALL.txt" "$STAGING/INSTALL.txt"
chmod +x "$STAGING/install.sh"

readonly ARCHIVE="$DIST_DIR/SwitchingMac-$VERSION.zip"
echo "  zip を作成しています..."
ditto -c -k --sequesterRsrc --keepParent "$STAGING" "$ARCHIVE"
rm -rf "$STAGING"

echo
echo "完成しました:"
echo "  $ARCHIVE"
echo "  サイズ: $(du -h "$ARCHIVE" | cut -f1)"
echo
echo "この zip を AirDrop や iCloud Drive で別の Mac へ渡し、"
echo "同梱の INSTALL.txt の手順に従って導入してください。"
