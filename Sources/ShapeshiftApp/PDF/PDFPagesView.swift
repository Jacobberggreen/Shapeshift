import SwiftUI
import PDFKit
import UniformTypeIdentifiers
import ConversionCore

/// Pages tool UI: a thumbnail grid for reordering, rotating and deleting pages.
struct PDFPagesView: View {
    let runJob: (@escaping PDFJob) -> Void
    let onCancel: () -> Void
    @StateObject private var model: PDFPagesModel
    @State private var dragging: Int?
    @State private var dropTarget: Int?

    private let columns = [GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 12)]

    init(urls: [URL], runJob: @escaping (@escaping PDFJob) -> Void, onCancel: @escaping () -> Void) {
        self.runJob = runJob
        self.onCancel = onCancel
        _model = StateObject(wrappedValue: PDFPagesModel(url: urls[0]))
    }

    var body: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Drag a page onto another to move it before that page.")
                    .font(.caption).foregroundStyle(.secondary)
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(Array(model.pages.enumerated()), id: \.element.sourceIndex) { index, edit in
                            PageCard(model: model, index: index, edit: edit, isDropTarget: dropTarget == index)
                                .opacity(dragging == index ? 0.4 : 1)
                                .onDrag {
                                    dragging = index
                                    return NSItemProvider(object: String(index) as NSString)
                                }
                                .onDrop(of: [.text], delegate: PageDropDelegate(
                                    target: index, model: model, dragging: $dragging, dropTarget: $dropTarget))
                        }
                    }
                    .padding(4)
                    // Dropping on empty space at the bottom sends the page to the end.
                    Color.clear.frame(height: 40)
                        .onDrop(of: [.text], delegate: PageDropDelegate(
                            target: model.pages.count, model: model, dragging: $dragging, dropTarget: $dropTarget))
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frostedCard(cornerRadius: 20)

            HStack(spacing: 12) {
                Text("\(model.pages.count) page\(model.pages.count == 1 ? "" : "s")")
                    .font(.callout).foregroundStyle(.secondary)
                Spacer()
                Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction)
                Button("Save") {
                    let url = model.url
                    let edits = model.edits
                    runJob {
                        guard let document = PDFDocument(url: url) else {
                            throw ConversionError.failed("Could not open \(url.lastPathComponent)")
                        }
                        return [try PDFOperations.save(try PDFOperations.rebuild(document, edits: edits),
                                                        nextTo: url, label: "edited")]
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!model.canSave || !model.isModified)
            }
            .padding(12)
            .frostedCard(cornerRadius: 18)
        }
    }
}

/// Drop delegate that reorders page cards in the grid.
private struct PageDropDelegate: DropDelegate {
    let target: Int
    let model: PDFPagesModel
    @Binding var dragging: Int?
    @Binding var dropTarget: Int?

    func dropEntered(info: DropInfo) { dropTarget = target }
    func dropExited(info: DropInfo) { if dropTarget == target { dropTarget = nil } }
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        defer { dragging = nil; dropTarget = nil }
        guard let from = dragging else { return false }
        withAnimation(.easeInOut(duration: 0.2)) { model.move(from: from, to: target) }
        return true
    }
}

/// Thumbnail card for one page, with rotate and delete buttons.
private struct PageCard: View {
    @ObservedObject var model: PDFPagesModel
    let index: Int
    let edit: PDFPageEdit
    let isDropTarget: Bool
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                if let image = model.thumbnail(forSource: edit.sourceIndex) {
                    let turned = edit.rotation % 180 != 0
                    Image(nsImage: image)
                        .resizable().scaledToFit()
                        .frame(width: turned ? 150 : 110, height: turned ? 110 : 150)
                        .rotationEffect(.degrees(Double(edit.rotation)))
                        .frame(width: 110, height: 150)
                        .shadow(radius: 2, y: 1)
                } else {
                    Rectangle().fill(.quaternary).frame(width: 110, height: 150)
                }
            }
            .frame(height: 150)
            .overlay(alignment: .bottom) {
                if hovering {
                    HStack(spacing: 6) {
                        cardButton("rotate.left", help: "Rotate left") { model.rotate(at: index, by: -90) }
                        cardButton("rotate.right", help: "Rotate right") { model.rotate(at: index, by: 90) }
                        cardButton("trash", help: "Delete page") { withAnimation { model.delete(at: index) } }
                    }
                    .padding(4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 4)
                }
            }
            Text("\(index + 1)").font(.caption).foregroundStyle(.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(hovering ? 0.10 : 0.04)))
        .overlay(alignment: .leading) {
            if isDropTarget {
                Capsule().fill(Color.accentColor).frame(width: 3).padding(.vertical, 4).offset(x: -8)
            }
        }
        .onHover { hovering = $0 }
    }

    private func cardButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).frame(width: 22, height: 22) }
            .buttonStyle(.borderless)
            .help(help)
    }
}
