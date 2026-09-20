import CoreWLAN
import Foundation

/// Wi-Fi インターフェースの電源操作の抽象。テストではフェイクに差し替える。
public protocol WiFiControlling: Sendable {
    /// 電源が入っているか
    /// - Throws: `SwitchError.unavailable` インターフェースが存在しない場合
    func isPoweredOn() throws -> Bool

    /// 電源を切り替える
    /// - Throws: `SwitchError` 操作できなかった場合
    func setPower(_ isOn: Bool) throws
}

/// CoreWLAN による実装。
public struct CoreWLANWiFiController: WiFiControlling {
    private static let missingInterfaceReason = "Wi-Fi インターフェースが見つかりません。"

    public init() {}

    public func isPoweredOn() throws -> Bool {
        try withInterface { $0.powerOn() }
    }

    public func setPower(_ isOn: Bool) throws {
        try withInterface { interface in
            do {
                try interface.setPower(isOn)
            } catch {
                throw SwitchError.permissionDenied(
                    reason: "Wi-Fi の電源を変更できませんでした: \(error.localizedDescription)"
                )
            }
        }
    }

    private func withInterface<T>(_ body: (CWInterface) throws -> T) throws -> T {
        guard let interface = CWWiFiClient.shared().interface() else {
            throw SwitchError.unavailable(reason: Self.missingInterfaceReason)
        }
        return try body(interface)
    }
}

/// Wi-Fi の電源スイッチ。
public struct WiFiProvider: SwitchProvider {
    private let controller: any WiFiControlling

    public init(controller: any WiFiControlling = CoreWLANWiFiController()) {
        self.controller = controller
    }

    public var kind: SwitchKind { .wifi }

    public var availability: ProviderAvailability {
        .requiresFullAccess(reason: "Wi-Fi の電源操作に対応する権限がサンドボックスでは取得できません。")
    }

    public func readState(_ context: SwitchContext) async -> SwitchState {
        do {
            return .from(isOn: try controller.isPoweredOn())
        } catch let error as SwitchError {
            if case let .unavailable(reason) = error {
                return .unavailable(reason: reason)
            }
            return .unknown
        } catch {
            return .unknown
        }
    }

    public func apply(isOn: Bool, context: SwitchContext) async throws {
        try controller.setPower(isOn)
    }
}
