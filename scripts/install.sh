#!/bin/bash
# SwitchingMac を /Applications へ導入する。
# 配布 zip を展開したフォルダで実行すること。
set -euo pipefail

readonly APP_NAME="SwitchingMac.app"
readonly SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SOURCE_APP="$SOURCE_DIR/$APP_NAME"
# 導入先。検証時などに INSTALL_DIR で変更できる。
readonly INSTALL_DIR="${INSTALL_DIR:-/Applications}"
readonly DEST_APP="$INSTALL_DIR/$APP_NAME"

if [ ! -d "$SOURCE_APP" ]; then
    echo "エラー: このスクリプトと同じフォルダに $APP_NAME が見つかりません。" >&2
    echo "       zip を展開したフォルダの中で実行してください。" >&2
    exit 1
fi

echo "SwitchingMac を導入します。"

# 旧バージョンが動いていれば終了させる
if pgrep -f "$APP_NAME/Contents/MacOS/SwitchingMac" >/dev/null 2>&1; then
    echo "  起動中のアプリを終了しています..."
    pkill -f "$APP_NAME/Contents/MacOS/SwitchingMac" || true
    sleep 2
fi

echo "  $INSTALL_DIR へコピーしています..."
rm -rf "$DEST_APP"
# ditto はコード署名や拡張属性を保ったままコピーする
ditto "$SOURCE_APP" "$DEST_APP"

# ダウンロードや受け渡しで付いた隔離属性を外す
echo "  隔離属性を解除しています..."
xattr -dr com.apple.quarantine "$DEST_APP" 2>/dev/null || true

# 受け渡しで署名が壊れていた場合のみ、この Mac 上で署名し直す
if ! codesign --verify --strict "$DEST_APP" >/dev/null 2>&1; then
    echo "  署名を付け直しています..."
    for framework in "$DEST_APP/Contents/Frameworks/"*.framework; do
        [ -e "$framework" ] || continue
        codesign --force --sign - "$framework"
    done
    codesign --force --sign - "$DEST_APP"
fi

echo "  起動しています..."
open "$DEST_APP"

cat <<'MESSAGE'

導入が完了しました。メニューバー右側にスイッチのアイコンが表示されます。

  - 設定はアイコンをクリックして「設定…」から行えます
  - ログイン時の自動起動は、設定の「一般」タブで有効にできます
MESSAGE
