import Foundation
import IOKit.pwr_mgt

/// システムスリープと画面オフを抑止する。
///
/// IOKit の電源アサーションを保持している間だけ有効で、
/// アプリを終了すると OS 側で自動的に解除される。
public actor SleepPreventionProvider: SwitchProvider {
    /// アサーションの説明（「バッテリー」設定などに表示される）
    private static let assertionReason = "SwitchingMac のスリープ防止スイッチが ON です"

    private var assertionID: IOPMAssertionID?

    public init() {}

    public nonisolated var kind: SwitchKind { .preventSleep }

    public nonisolated var availability: ProviderAvailability { .sandboxSafe }

    public func readState(_ context: SwitchContext) async -> SwitchState {
        .from(isOn: assertionID != nil)
    }

    public func apply(isOn: Bool, context: SwitchContext) async throws {
        isOn ? try createAssertion() : releaseAssertion()
    }

    // MARK: - 内部

    private func createAssertion() throws {
        guard assertionID == nil else { return }

        var identifier = IOPMAssertionID(0)
        let status = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            Self.assertionReason as CFString,
            &identifier
        )
        guard status == kIOReturnSuccess else {
            throw SwitchError.unavailable(
                reason: "電源アサーションを作成できませんでした（コード \(status)）。"
            )
        }
        assertionID = identifier
    }

    private func releaseAssertion() {
        guard let assertionID else { return }
        IOPMAssertionRelease(assertionID)
        self.assertionID = nil
    }
}
