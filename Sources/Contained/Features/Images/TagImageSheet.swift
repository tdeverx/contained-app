import SwiftUI
import ContainedCore

/// Add a new tag (reference) to an existing image.
struct TagImageSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    let source: String
    @State private var target = ""
    @State private var busy = false

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Tag image", onCancel: { dismiss() }) {
                GlassCircleButton(systemName: "checkmark", prominent: true, help: "Tag") { submit() }
                    .disabled(target.trimmingCharacters(in: .whitespaces).isEmpty || busy)
            }
            Form {
                LabeledContent("Source", value: Format.shortImage(source))
                TextField("New reference", text: $target, prompt: Text("e.g. myrepo/app:v1"))
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(Tokens.SheetSize.small)
        .sheetMaterial()
    }

    private func submit() {
        guard let client = app.client else { return }
        busy = true
        Task {
            do {
                _ = try await client.tagImage(source: source, target: target.trimmingCharacters(in: .whitespaces))
                await app.refreshResource(.images)
                dismiss()
            } catch let error as CommandError { app.flash(error.userMessage); busy = false }
            catch { app.flash(error.localizedDescription); busy = false }
        }
    }
}
