import Foundation
import Testing
@testable import SwitchingMacCore

@Suite("カスタムコマンド定義の検証")
struct CustomCommandSpecTests {
    @Test("ON/OFF コマンドが空なら不正")
    func emptyCommandsAreInvalid() {
        let spec = CustomCommandSpec(onCommand: "", offCommand: "echo off")

        #expect(throws: SwitchError.self) { try spec.validate() }
    }

    @Test("状態を記憶する方式では状態取得コマンドが空でもよい")
    func rememberedAllowsEmptyStateCommand() throws {
        let spec = CustomCommandSpec(
            onCommand: "echo on",
            offCommand: "echo off",
            stateCommand: "",
            stateDetection: .remembered
        )

        try spec.validate()
    }

    @Test("状態取得が必要な方式で状態取得コマンドが空なら不正", arguments: [
        ShellStateDetection.exitCodeZeroMeansOn,
        ShellStateDetection.outputEquals("on"),
    ])
    func stateCommandRequired(detection: ShellStateDetection) {
        let spec = CustomCommandSpec(
            onCommand: "echo on",
            offCommand: "echo off",
            stateCommand: "  ",
            stateDetection: detection
        )

        #expect(throws: SwitchError.self) { try spec.validate() }
    }

    @Test("コマンドが長すぎる場合は不正")
    func tooLongCommandIsInvalid() {
        let spec = CustomCommandSpec(
            onCommand: String(repeating: "a", count: CustomCommandSpec.maxCommandLength + 1),
            offCommand: "echo off"
        )

        #expect(throws: SwitchError.self) { try spec.validate() }
    }
}
