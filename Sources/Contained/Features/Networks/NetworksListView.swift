import SwiftUI
import ContainedCore

// The Networks list is folded into the Containers page (each network is a collapsible group of the
// containers attached to it). Only the shared create-network sheet lives here now.

/// Minimal create-network sheet: name + optional subnet + host-only toggle.
struct CreateNetworkSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onCreate: (String, String?, Bool) async -> Void
    @State private var name = ""
    @State private var subnet = ""
    @State private var internalOnly = false
    @State private var busy = false

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "New network", onCancel: { dismiss() }) {
                GlassCircleButton(systemName: "checkmark", prominent: true, help: "Create") { submit() }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || busy)
            }
            Form {
                TextField("Name", text: $name, prompt: Text("my-network"))
                TextField("Subnet", text: $subnet, prompt: Text("optional, e.g. 10.0.0.0/24"))
                Toggle("Host-only (internal)", isOn: $internalOnly)
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(Tokens.SheetSize.small)
        .sheetMaterial()
    }

    private func submit() {
        busy = true
        Task {
            await onCreate(name.trimmingCharacters(in: .whitespaces),
                           subnet.trimmingCharacters(in: .whitespaces).isEmpty ? nil : subnet, internalOnly)
            dismiss()
        }
    }
}
