import SwiftUI

#if DEBUG
struct DevServerBanner: View {
    @EnvironmentObject private var appState: AppState
    @State private var statusText = "检测后端…"
    @State private var isOK = false
    @State private var showEditor = false
    @State private var draftURL = APIConfig.baseURLString

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(isOK ? Color.green : Color.orange)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(statusText)
                    .font(.caption.weight(.semibold))
                Text(APIConfig.baseURLString)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button("改地址") { showEditor = true }
                .font(.caption)
            Button("重试") {
                Task { await ping() }
            }
            .font(.caption)
        }
        .padding(10)
        .background(RoomTheme.card.opacity(0.9))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isOK ? RoomTheme.mint.opacity(0.5) : RoomTheme.softWarn.opacity(0.5), lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .task { await ping() }
        .sheet(isPresented: $showEditor) {
            NavigationStack {
                Form {
                    TextField("API Base URL", text: $draftURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("模拟器请用 http://127.0.0.1:8000/api/v1；真机改为 Mac 的局域网 IP。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .navigationTitle("联调地址")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { showEditor = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            APIConfig.baseURLString = draftURL.trimmingCharacters(in: .whitespacesAndNewlines)
                            appState.api.baseURL = APIConfig.baseURL
                            showEditor = false
                            Task { await ping() }
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    private func ping() async {
        statusText = "检测后端…"
        isOK = false
        do {
            let ok = try await appState.api.healthCheck()
            isOK = ok
            statusText = ok ? "后端已连通" : "后端无响应"
        } catch {
            isOK = false
            statusText = "后端未连通"
        }
    }
}
#endif
