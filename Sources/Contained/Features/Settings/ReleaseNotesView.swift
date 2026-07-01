import SwiftUI
import WebKit

struct ReleaseNotesView: View {
    var title: String
    var html: String
    var onClose: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                if let onClose {
                    Button("Done") { onClose() }
                }
            }
            .padding()
            Divider()
            HTMLView(html: html)
        }
        .frame(width: 620, height: 520)
    }
}

private struct HTMLView: NSViewRepresentable {
    var html: String

    func makeNSView(context: Context) -> WKWebView {
        WKWebView()
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let document = """
        <!doctype html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <style>
            body { font: -apple-system-body; margin: 24px; color: text; }
            h2 { font: -apple-system-title2; margin-top: 22px; margin-bottom: 10px; }
            h3 { font: -apple-system-headline; margin-top: 18px; }
            h4 { font: -apple-system-subheadline; margin-top: 14px; margin-bottom: 4px; }
            li { margin: 6px 0; }
          </style>
        </head>
        <body>\(html)</body>
        </html>
        """
        webView.loadHTMLString(document, baseURL: nil)
    }
}
