import SwiftUI
import ConversionCore

/// Merge tool UI: reorder the inputs, then merge them into one PDF.
struct PDFMergeView: View {
    let runJob: (@escaping PDFJob) -> Void
    let onCancel: () -> Void
    @StateObject private var model: PDFMergeModel

    init(urls: [URL], runJob: @escaping (@escaping PDFJob) -> Void, onCancel: @escaping () -> Void) {
        self.runJob = runJob
        self.onCancel = onCancel
        _model = StateObject(wrappedValue: PDFMergeModel(urls: urls))
    }

    var body: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Drag to set the order. Files are merged top to bottom.")
                    .font(.caption).foregroundStyle(.secondary)
                List {
                    ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: 10) {
                            Image(systemName: "line.3.horizontal").foregroundStyle(.secondary)
                            Text(item.name).lineLimit(1).truncationMode(.middle)
                            Spacer()
                            Text("\(item.pageCount) page\(item.pageCount == 1 ? "" : "s")")
                                .font(.caption).foregroundStyle(.secondary)
                            Button { model.remove(at: index) } label: { Image(systemName: "xmark.circle.fill") }
                                .buttonStyle(.borderless)
                                .help("Remove from the merge")
                        }
                    }
                    .onMove { model.move(from: $0, to: $1) }
                }
                .scrollContentBackground(.hidden)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frostedCard(cornerRadius: 20)

            HStack(spacing: 12) {
                Text("\(model.items.count) files").font(.callout).foregroundStyle(.secondary)
                Spacer()
                Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction)
                Button("Merge") {
                    let urls = model.urls
                    runJob { [try PDFOperations.save(try PDFOperations.merge(urls), nextTo: urls[0], label: "merged")] }
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
