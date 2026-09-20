import Foundation

/// スイッチの現在状態。
///
/// 状態の取得に失敗する場合があるため、真偽値ではなく明示的な状態として表現する。
public enum SwitchState: Sendable, Hashable {
    /// ON
    case on
    /// OFF
    case off
    /// この環境では利用できない（例: Wi-Fi インターフェースが存在しない）
    case unavailable(reason: String)
    /// 状態を判定できなかった
    case unknown

    /// UI のトグルに表示する真偽値。判定できない場合は OFF 扱いとする。
    public var isOn: Bool {
        self == .on
    }

    /// ユーザーが操作できる状態かどうか。
    public var isOperable: Bool {
        switch self {
        case .on, .off, .unknown:
            return true
        case .unavailable:
            return false
        }
    }

    /// 真偽値から状態を生成する。
    public static func from(isOn: Bool) -> SwitchState {
        isOn ? .on : .off
    }
}
