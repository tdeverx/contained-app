import SwiftUI
import ContainedCore

/// Pull an image, showing live `--progress plain` output. Two phases: reference input, then console.
struct PullImageSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    var prefill: String = ""

    @State private var ref = ""
    @State private var platform = ""
    @State private var started = false
    @State private var succeeded = false

    @State private var hubQuery = ""
    @State private var hubResults: [HubSearchResult] = []
    @State private var searching = false
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Pull image").font(.headline)
                Spacer()
                GlassCircleButton(systemName: "xmark", help: started ? "Close" : "Cancel", isCancel: true) { finish() }
                if !started {
                    GlassCircleButton(systemName: "arrow.down.circle.fill", prominent: true, help: "Pull") {
                        started = true
                    }
                    .disabled(ref.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(Tokens.Space.l)

            if started, let client = app.client {
                StreamConsole(stream: {
                    client.streamPull(ref.trimmingCharacters(in: .whitespaces),
                                      platform: platform.isEmpty ? nil : platform)
                }, onComplete: { ok in
                    succeeded = ok
                    if ok { Task { await app.refreshImagesIfStale(force: true) } }
                })
                .padding(.horizontal, Tokens.Space.l)
                .padding(.bottom, Tokens.Space.l)
            } else {
                Form {
                    Section {
                        TextField("Reference", text: $ref, prompt: Text("e.g. nginx:latest"))
                            .fieldInfo("repo:tag to pull from a registry.")
                        TextField("Platform", text: $platform, prompt: Text("optional, e.g. linux/arm64"))
                    }
                    Section("Search Docker Hub") {
                        HStack {
                            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                            TextField("Search images…", text: $hubQuery)
                                .textFieldStyle(.plain)
                                .onSubmit { runSearch() }
                            if searching { ProgressView().controlSize(.small) }
                        }
                        ForEach(hubResults) { result in
                            Button { ref = result.pullReference } label: { hubRow(result) }
                                .buttonStyle(.plain)
                        }
                    }
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
            }
        }
        .frame(width: Tokens.SheetSize.console.width, height: started ? Tokens.SheetSize.console.height : 460)
        .sheetMaterial()
        .onAppear { if ref.isEmpty { ref = prefill } }
        .onChange(of: hubQuery) { _, _ in scheduleSearch() }
    }

    private func hubRow(_ result: HubSearchResult) -> some View {
        HStack(spacing: Tokens.Space.s) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(result.repoName).font(.callout.weight(.medium)).lineLimit(1)
                    if result.isOfficial {
                        Image(systemName: "checkmark.seal.fill").font(.caption2).foregroundStyle(.blue)
                    }
                }
                if let desc = result.shortDescription, !desc.isEmpty {
                    Text(desc).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            Label("\(result.starCount)", systemImage: "star.fill")
                .font(.caption).foregroundStyle(.secondary).labelStyle(.titleAndIcon)
        }
        .contentShape(Rectangle())
    }

    /// Debounce typing, then search.
    private func scheduleSearch() {
        searchTask?.cancel()
        let query = hubQuery
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled, query == hubQuery else { return }
            runSearch()
        }
    }

    private func runSearch() {
        guard let url = HubSearch.url(query: hubQuery) else { hubResults = []; return }
        searching = true
        Task {
            defer { searching = false }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let decoded = try JSONDecoder().decode(HubSearchResponse.self, from: data)
                if !Task.isCancelled { hubResults = decoded.results }
            } catch {
                if !Task.isCancelled { hubResults = [] }
            }
        }
    }

    private func finish() {
        if succeeded { Task { await app.refreshImagesIfStale(force: true) } }
        dismiss()
    }
}
