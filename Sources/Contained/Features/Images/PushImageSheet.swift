import SwiftUI
import ContainedCore

/// Push an image to its registry (must be logged in), streaming progress. Errors (e.g. not logged
/// in) surface in the console.
struct PushImageSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    let reference: String

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Push image", subtitle: Format.shortImage(reference),
                        cancelHelp: "Close", onCancel: { dismiss() })
            if let client = app.client {
                StreamConsole(stream: { client.streamPush(reference) })
                    .padding(.horizontal, Tokens.Space.l)
                    .padding(.bottom, Tokens.Space.l)
            }
        }
        .frame(Tokens.SheetSize.console)
        .background(.regularMaterial)
    }
}
