import SwiftUI

/// 情報タブ。
struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "switch.2")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            VStack(spacing: 4) {
                Text(AppInfo.displayName)
                    .font(.title2.bold())
                Text("バージョン \(AppInfo.version)（\(AppInfo.build)）")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("メニューバーから、よく使う機能を自由にスイッチとして並べて切り替えられます。")
                .font(.callout)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)

            Link("GitHub リポジトリ", destination: AppInfo.repositoryURL)
                .font(.callout)

            Spacer()
        }
        .padding(.top, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
