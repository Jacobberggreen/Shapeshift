import SwiftUI

/// Shell for the four PDF tools. Each tool view gets the input files and `runJob`
/// (which starts the work in the background and closes the window).
struct PDFToolRootView: View {
    let tool: PDFTool
    let urls: [URL]
    let runJob: (@escaping PDFJob) -> Void
    let onCancel: () -> Void

    var body: some View {
        Group {
            switch tool {
            case .pages: PDFPagesView(urls: urls, runJob: runJob, onCancel: onCancel)
            case .split: PDFSplitView(urls: urls, runJob: runJob, onCancel: onCancel)
            case .merge: PDFMergeView(urls: urls, runJob: runJob, onCancel: onCancel)
            case .redact: PDFRedactView(urls: urls, runJob: runJob, onCancel: onCancel)
            }
        }
        .padding(16)
    }
}
