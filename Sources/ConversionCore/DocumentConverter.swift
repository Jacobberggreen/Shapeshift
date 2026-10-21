import AppKit

/// Word-processor, RTF, HTML and plain-text documents to a paginated A4 PDF,
/// using AppKit's own document readers and text layout.
public struct DocumentConverter: Converter {
    public init() {}

    static let documentTypes: [FileFormat: NSAttributedString.DocumentType] = [
        .docx: .officeOpenXML, .doc: .docFormat, .odt: .openDocument,
        .rtf: .rtf, .html: .html, .txt: .plain,
    ]

    /// True for word-processor, RTF, HTML and text sources converted to PDF.
    public func supports(from: FileFormat, to: FileFormat) -> Bool {
        to == .pdf && Self.documentTypes[from] != nil
    }

    /// Lays the document out on A4 pages and writes a PDF to `output`. Runs on the main actor for AppKit.
    public func convert(input: URL, from: FileFormat, to: FileFormat, output: URL, options: ConversionOptions) async throws {
        guard supports(from: from, to: to) else {
            throw ConversionError.unsupportedConversion(from: from, to: to)
        }
        try await MainActor.run {
            let text = try Self.readText(input: input, from: from)
            try Self.renderPDF(text, output: output)
        }
    }

    @MainActor
    private static func readText(input: URL, from: FileFormat) throws -> NSAttributedString {
        guard let type = documentTypes[from] else { throw ConversionError.unsupportedConversion(from: from, to: .pdf) }
        var options: [NSAttributedString.DocumentReadingOptionKey: Any] = [.documentType: type]
        if from == .html || from == .txt {
            options[.characterEncoding] = String.Encoding.utf8.rawValue
        }
        let text: NSAttributedString
        do {
            text = try NSAttributedString(url: input, options: options, documentAttributes: nil)
        } catch {
            throw ConversionError.unreadable(input)
        }
        if from != .txt, text.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ConversionError.unreadable(input)
        }
        return text
    }

    private static let pageWidth: CGFloat = 595.28
    private static let pageHeight: CGFloat = 841.89
    private static let margin: CGFloat = 56

    @MainActor
    private static func renderPDF(_ text: NSAttributedString, output: URL) throws {
        let contentWidth = pageWidth - 2 * margin
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: contentWidth, height: pageHeight))
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = .zero
        guard let container = textView.textContainer, let layoutManager = textView.layoutManager else {
            throw ConversionError.failed("Could not lay out the document.")
        }
        container.containerSize = NSSize(width: contentWidth, height: .greatestFiniteMagnitude)
        container.widthTracksTextView = false
        textView.textStorage?.setAttributedString(text)
        layoutManager.ensureLayout(for: container)
        let used = layoutManager.usedRect(for: container)
        textView.setFrameSize(NSSize(width: contentWidth, height: max(ceil(used.height), pageHeight)))

        guard let info = NSPrintInfo.shared.copy() as? NSPrintInfo else {
            throw ConversionError.failed("Could not create PDF file.")
        }
        info.jobDisposition = .save
        info.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = output
        info.paperSize = NSSize(width: pageWidth, height: pageHeight)
        info.topMargin = margin
        info.bottomMargin = margin
        info.leftMargin = margin
        info.rightMargin = margin
        info.isHorizontallyCentered = false
        info.isVerticallyCentered = false

        let operation = NSPrintOperation(view: textView, printInfo: info)
        operation.showsPrintPanel = false
        operation.showsProgressPanel = false
        guard operation.run() else {
            throw ConversionError.failed("Could not write PDF file.")
        }
    }
}
