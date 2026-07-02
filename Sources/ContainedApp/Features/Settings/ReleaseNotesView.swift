import SwiftUI
import WebKit
import ContainedDesignSystem

struct ReleaseNotesView: View {
    var title: String
    var html: String
    var onClose: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: title, cancelHelp: AppText.done) {
                onClose?()
            }
            Divider()
            HTMLView(html: html)
        }
        .frame(DesignTokens.SheetSize.releaseNotes)
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
            :root { color-scheme: light dark; }
            body {
              font: -apple-system-body;
              margin: 24px;
              color: CanvasText;
              background: Canvas;
            }
            h2 { font: -apple-system-title2; margin: 4px 0 12px; }
            h3 { font: -apple-system-headline; margin: 20px 0 8px; }
            h4 { font: -apple-system-subheadline; margin: 14px 0 4px; }
            p { margin: 8px 0 12px; }
            ul { margin: 8px 0 16px; padding-left: 22px; }
            li { margin: 6px 0; }
          </style>
        </head>
        <body>\(html)</body>
        </html>
        """
        webView.loadHTMLString(document, baseURL: nil)
    }
}
