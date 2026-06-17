import SwiftUI

/// 译本管理:已安装译本(内置 cuv 不可删)+ 可下载译本(带进度、校验、删除)。
struct TranslationsView: View {
    let manager: TranslationManager

    @State private var installError: String?

    var body: some View {
        List {
            Section("已安装") {
                ForEach(manager.installed) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(manager.displayName(for: item.id))
                            Text(item.id.uppercased())
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if item.isBuiltIn {
                            Text("内置").font(.caption).foregroundStyle(.secondary)
                        } else {
                            Button(role: .destructive) {
                                delete(item.id)
                            } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }

            Section("可下载") {
                if let error = manager.catalogError {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(error).foregroundStyle(.secondary)
                        Button("重试") { Task { await manager.fetchCatalog() } }
                    }
                } else if manager.available.isEmpty {
                    Text("没有更多可下载的译本。").foregroundStyle(.secondary)
                } else {
                    ForEach(manager.available) { remote in
                        downloadRow(remote)
                    }
                }
            }

            if let installError {
                Section { Text(installError).foregroundStyle(.red) }
            }
        }
        .navigationTitle("译本管理")
        .task { await manager.fetchCatalog() }
    }

    @ViewBuilder
    private func downloadRow(_ remote: RemoteTranslation) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(remote.nameZH)
                Text("\(remote.nameEN) · \(byteText(remote.bytes))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let progress = manager.downloadProgress[remote.id] {
                ProgressView(value: progress).frame(width: 80)
            } else {
                Button("下载") { download(remote) }
                    .buttonStyle(.borderless)
            }
        }
    }

    private func download(_ remote: RemoteTranslation) {
        installError = nil
        Task {
            do {
                try await manager.install(remote)
                await manager.fetchCatalog()
            } catch TranslationInstallError.checksumMismatch {
                installError = "\(remote.nameZH) 下载校验失败,请重试。"
            } catch {
                installError = "下载失败:\(error.localizedDescription)"
            }
        }
    }

    private func delete(_ id: String) {
        do {
            try manager.delete(id)
            Task { await manager.fetchCatalog() }
        } catch {
            installError = "删除失败:\(error.localizedDescription)"
        }
    }

    private func byteText(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}
