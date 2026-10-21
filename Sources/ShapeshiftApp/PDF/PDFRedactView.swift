import SwiftUI
import AppKit
import PDFKit
import ConversionCore

/// Redact tool UI: draw boxes over the pages, then run the redaction.
struct PDFRedactView: View {
    let runJob: (@escaping PDFJob) -> Void
    let onCancel: () -> Void
    @StateObject private var model: RedactionModel

    init(urls: [URL], runJob: @escaping (@escaping PDFJob) -> Void, onCancel: @escaping () -> Void) {
        self.runJob = runJob
        self.onCancel = onCancel
        _model = StateObject(wrappedValue: RedactionModel(url: urls[0]))
    }

    var body: some View {
        VStack(spacing: 12) {
            toolbar
            pageArea
            footer
        }
        .frame(minWidth: 520, minHeight: 520)
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Button { model.previous() } label: { Image(systemName: "chevron.left") }
                .disabled(model.currentPage == 0)
            Text("Page \(model.currentPage + 1) of \(model.pageCount)").font(.callout).monospacedDigit()
            Button { model.next() } label: { Image(systemName: "chevron.right") }
                .disabled(model.currentPage >= model.pageCount - 1)
            Spacer()
            Text("Drag on the page to mark an area.").font(.caption).foregroundStyle(.secondary)
            Button("Undo") { model.undoLast() }.disabled(model.currentBoxes.isEmpty)
            Button("Clear page") { model.clearPage() }.disabled(model.currentBoxes.isEmpty)
        }
        .padding(12)
        .frostedCard(cornerRadius: 18)
    }

    private var pageArea: some View {
        Group {
            if let preview = model.preview(for: model.currentPage) {
                Image(decorative: preview.image, scale: 1)
                    .resizable().scaledToFit()
                    .overlay {   // shares the fitted image's frame, so normalised coords line up
                        RedactOverlay(boxes: model.currentBoxes, onAdd: { model.add($0) },
                                      onRemove: { model.remove(at: $0) })
                    }
                    .padding(16)
            } else {
                Text("This page can't be shown.").foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frostedCard(cornerRadius: 20)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Text("\(model.totalBoxes) box\(model.totalBoxes == 1 ? "" : "es") on \(model.pagesAffected) page\(model.pagesAffected == 1 ? "" : "s")")
                .font(.callout).foregroundStyle(.secondary)
            Spacer()
            Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction)
            Button("Redact…") { confirmAndRun() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!model.canSave)
        }
        .padding(12)
        .frostedCard(cornerRadius: 18)
    }

    private func confirmAndRun() {
        let alert = NSAlert()
        alert.messageText = "Redact \(model.pagesAffected) page\(model.pagesAffected == 1 ? "" : "s")?"
        alert.informativeText = "Redacted pages are flattened to images, so the text underneath is removed for good. The original file is not changed; the result is saved as a new file."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Redact")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let url = model.url, boxes = model.boxes
        runJob {
            guard let document = PDFDocument(url: url) else {
                throw ConversionError.failed("Could not open the PDF.")
            }
            return [try PDFOperations.save(try PDFOperations.redact(document, boxes: boxes), nextTo: url, label: "redacted")]
        }
    }
}

/// Mouse overlay for adding and removing redaction boxes on a page.
private struct RedactOverlay: View {
    let boxes: [CGRect]
    let onAdd: (CGRect) -> Void
    let onRemove: (Int) -> Void
    @State private var drag: CGRect?

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack(alignment: .topLeading) {
                Color.clear.contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 2, coordinateSpace: .local)
                        .onChanged { value in
                            drag = Self.normalised(value.startLocation, value.location, w, h)
                        }
                        .onEnded { value in
                            onAdd(Self.normalised(value.startLocation, value.location, w, h))
                            drag = nil
                        })
                ForEach(Array(boxes.enumerated()), id: \.offset) { index, box in
                    Rectangle().fill(Color.black.opacity(0.6))
                        .overlay(Rectangle().stroke(Color.red, lineWidth: 1.5))
                        .frame(width: box.width * w, height: box.height * h)
                        .offset(x: box.minX * w, y: box.minY * h)
                        .contextMenu { Button("Remove box") { onRemove(index) } }
                }
                if let drag {
                    Rectangle().fill(Color.red.opacity(0.2))
                        .overlay(Rectangle().stroke(Color.red, style: StrokeStyle(lineWidth: 1.5, dash: [4])))
                        .frame(width: drag.width * w, height: drag.height * h)
                        .offset(x: drag.minX * w, y: drag.minY * h)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    private static func normalised(_ a: CGPoint, _ b: CGPoint, _ w: CGFloat, _ h: CGFloat) -> CGRect {
        guard w > 0, h > 0 else { return .zero }
        let x0 = min(max(min(a.x, b.x) / w, 0), 1), x1 = min(max(max(a.x, b.x) / w, 0), 1)
        let y0 = min(max(min(a.y, b.y) / h, 0), 1), y1 = min(max(max(a.y, b.y) / h, 0), 1)
        return CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
    }
}
