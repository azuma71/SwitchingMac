# SwitchingMac

メニューバーから、よく使う機能をスイッチとして並べて ON / OFF できる macOS アプリです。
組込のスイッチに加えて、任意のシェルコマンドを登録した自分専用のスイッチを追加できます。

## 機能

### 組込スイッチ

| スイッチ | 内容 | 実現方法 |
|---|---|---|
| ダークモード | システム外観のライト / ダーク切替 | `defaults` で読み取り、システムイベントへの Apple Event で変更 |
| スリープ防止 | 放置によるスリープと画面オフを抑止 | IOKit の電源アサーション |
| 蓋を閉じてもスリープしない | システム全体のスリープを無効化 | `pmset -a disablesleep` を管理者権限で実行 |
| Wi-Fi | Wi-Fi インターフェースの電源 | CoreWLAN |
| 隠しファイルを表示 | Finder の隠しファイル表示 | `defaults write com.apple.finder AppleShowAllFiles` + Finder 再起動 |
| Dock を自動的に非表示 | Dock の自動非表示 | `defaults write com.apple.dock autohide` + Dock 再起動 |

> [!NOTE]
> 「スリープ防止」と「蓋を閉じてもスリープしない」は別の仕組みです。
> 前者（IOPMAssertion）は放置によるスリープを防ぎますが、蓋を閉じたときのスリープは防げません。
> 蓋を閉じたまま使う場合は、通気の確保にご注意ください。

### カスタムスイッチ

ON / OFF それぞれのコマンドを登録して、独自のスイッチを何個でも追加できます。
現在状態の判定方法は 3 通りから選べます。

- 状態を取得しない（最後の操作を記憶する）
- 状態取得コマンドの終了コードが 0 なら ON
- 状態取得コマンドの出力が指定文字列と一致したら ON

コマンドは `/bin/zsh -lc` で実行されます。アプリが外部入力をコマンド文字列へ連結することはなく、
実行されるのは設定画面で入力した内容のみです。

## 動作環境

- macOS 14.0 以降
- ビルドには Xcode 16 以降（開発時の確認は Xcode 26.6 / Swift 6.3）

## 導入（自分の別の Mac で使う）

配布用の zip を作成します。作成した zip は `dist/` に出力されます（Git 管理外）。

```sh
./scripts/build-release.sh
```

できた `dist/SwitchingMac-<version>.zip` を AirDrop や iCloud Drive で別の Mac へ渡し、
展開したフォルダで次を実行すると `/Applications` に導入されます。

```sh
bash install.sh
```

`install.sh` は、コピー・隔離属性の解除・（必要な場合のみ）ad-hoc 署名の付け直し・起動までを行います。
導入先を変えたい場合は `INSTALL_DIR=~/Applications bash install.sh` のように指定できます。
zip には利用者向けの `INSTALL.txt` が同梱されます。

> [!NOTE]
> 現在は Apple Developer Program の証明書を使わない ad-hoc 署名のため、
> 他の Mac へコピーすると Gatekeeper に止められます。`install.sh` がこれを解除します。
> 署名と公証（Notarization）を行えば、この手順は不要になります。

## ビルド

`.xcodeproj` は `project.yml` から生成する方式のため、リポジトリには含めていません。

```sh
brew install xcodegen
xcodegen generate
open SwitchingMac.xcodeproj
```

コマンドラインからのビルドとテストは次のとおりです。

```sh
xcodebuild build -project SwitchingMac.xcodeproj -scheme SwitchingMac -destination 'platform=macOS'
xcodebuild test  -project SwitchingMac.xcodeproj -scheme SwitchingMac -destination 'platform=macOS'
```

## 必要な許可

- **オートメーション**: ダークモードの切替に「システムイベント」の操作許可が必要です。
  初回操作時にダイアログが表示されます。許可しなかった場合は
  「システム設定 > プライバシーとセキュリティ > オートメーション」から変更できます。
- **管理者パスワード**: 「蓋を閉じてもスリープしない」の切り替えに必要です
  （`pmset` によるシステム全体の電源設定の変更のため）。状態の表示に権限は不要です。
- **ログイン時に起動**: 設定画面の「一般」タブから登録できます（`SMAppService`）。
  署名済みの `.app` として起動している必要があります。

## 構成

```
Sources/
  SwitchingMacCore/     UI に依存しないロジック層（テスト対象）
    Model/              スイッチ定義・設定・エラー
    Provider/           機能ごとの読み取り / 適用の実装
    Shell/              外部コマンド実行
    Store/              設定の永続化とアプリ状態
  SwitchingMac/         SwiftUI のメニューバーアプリ
    MenuBar/            メニューバーの表示
    Settings/           設定ウィンドウ
Tests/
  SwitchingMacCoreTests/
```

機能の追加は `SwitchProvider` を実装して `ProviderRegistry` に登録するだけで完結します。
UI 側の変更は不要です。

設定は `~/Library/Application Support/SwitchingMac/switches.json` に保存されます
（カスタムコマンドを含むため、所有者のみ読み書き可能な権限で保存します）。

## 配布方針

本アプリは **非サンドボックス** 版として開発しています。App Sandbox では
他アプリの環境設定の書き換え、Wi-Fi の電源操作、任意コマンドの実行がいずれも行えず、
本アプリの中心機能が成立しないためです。

将来 Mac App Store 版を用意する場合に備え、各 `SwitchProvider` は
サンドボックス下で動作するかどうかを `availability` として申告します。
`ProviderRegistry.makeSandboxSafe()` は対応する機能だけを登録したレジストリを返すため、
サンドボックス版ターゲットを追加する際はレジストリを差し替えるだけで済みます。

現時点でサンドボックス下でも動作するのは「スリープ防止」のみです。

## 今後の予定

- カスタムスイッチ編集画面でのコマンドのテスト実行
- 特権ヘルパー（`SMAppService` のデーモン）による、パスワード入力を伴わない電源設定の切替
- アプリアイコンの作成
- Developer ID 署名と公証（Notarization）、GitHub Releases での配布
