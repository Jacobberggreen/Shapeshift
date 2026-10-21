import SwiftUI
import PDFKit
import ConversionCore

/// Split tool UI: split every page or by the ranges entered.
struct PDFSplitView: View {
    let runJob: (@escaping PDFJob) -> Void
    let onCancel: () -> Void
    @StateObject private var model: PDFSplitModel

    init(urls: [URL], runJob: @escaping (@escaping PDFJob) -> Void, onCancel: @escaping () -> Void) {
        self.runJob = runJob
        self.onCancel = onCancel
        _model = StateObject(wrappedValue: PDFSplitModel(url: urls[0]))
    }

    var body: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                Text(model.url.lastPathComponent).font(.headline).lineLimit(1).truncationMode(.middle)
                Text("\(model.pageCount) pages").font(.caption).foregroundStyle(.secondary)
                Picker("", selection: $model.mode) {
                    Text("Every page").tag(PDFSplitModel.Mode.everyPage)
                    Text("Page ranges").tag(PDFSplitModel.Mode.ranges)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                if model.mode == .ranges {
                    TextField("1-3, 4-10", text: $model.rangeText).textFieldStyle(.roundedBorder)
                    if let error = model.errorMessage {
                        Text(error).font(.caption).foregroundStyle(.red)
                    }
                }
                Text(model.summary).font(.callout).foregroundStyle(.secondary)
                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .frostedCard(cornerRadius: 20)

            HStack(spacing: 12) {
                Spacer()
                Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction)
                Button("Split") {
                    guard let ranges = model.ranges else { return }
                    let url = model.url
                    runJob {
                        guard let document = PDFDocument(url: url) else {
                            throw ConversionError.failed("Could not open \(url.lastPathComponent)")
                        }
                        let parts = try PDFOperations.split(document, ranges: ranges)
                        return [try PDFOperations.savePartsFolder(parts, nextTo: url)]
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!model.canSave)
            }
            .padding(12)
            .frostedCard(cornerRadius: 18)
        }
    }
}
