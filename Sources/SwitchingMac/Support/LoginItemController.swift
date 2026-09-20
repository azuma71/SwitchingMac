import Foundation
import Observation
import ServiceManagement

/// ログイン時の自動起動の設定。
///
/// `SMAppService` は署名済みアプリバンドルからの実行を前提とするため、
/// Xcode から直接起動した場合などは登録に失敗することがある。
@MainActor
@Observable
public final class LoginItemController {
    /// 現在登録されているか
    public private(set) var isEnabled: Bool
    /// 直近のエラー
    public private(set) var errorMessage: String?

    public init() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    /// 自動起動の登録 / 解除を行う。
    public func setEnabled(_ newValue: Bool) {
        errorMessage = nil
        do {
            if newValue {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            errorMessage = "ログイン項目を更新できませんでした。\n\(error.localizedDescription)"
        }
        refresh()
    }

    /// システム側の状態を読み直す。
    public func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    public func dismissError() {
        errorMessage = nil
    }
}
