import Foundation
import CoreGraphics
import ConversionCore

/// Observable state for one wheel: its style, formats, tools, current step and size estimates.
@MainActor
final class WheelModel: ObservableObject {
    let style: MenuStyle
    let formats: [FileFormat]
    let tools: [ToolKind]
    let fileCount: Int
    @Published private(set) var step: WheelStep
    @Published var selected: Int? {
        didSet { if selected != oldValue { selectionChanged() } }
    }
    @Published private(set) var estimates: [FileFormat: Int] = [:]
    /// Total source size; known up front for tests, otherwise resolved off the main thread after init.
    @Published private(set) var sourceBytes: Int?
    let outcome: WheelOutcomeSource
    private var sizeTask: Task<Void, Never>?
    private var inFlight: [FileFormat: Task<Void, Never>] = [:]
    private var failed: Set<FileFormat> = []
    private let startsAtRoot: Bool

    init(style: MenuStyle, formats: [FileFormat], tools: [ToolKind], fileCount: Int,
         outcome: WheelOutcomeSource = WheelOutcomeSource()) {
        self.outcome = outcome
        self.sourceBytes = outcome.sourceBytes
        self.style = style
        self.formats = formats
        self.tools = tools
        self.fileCount = fileCount
        if style == .twoSteps {
            switch (formats.isEmpty, tools.isEmpty) {
            case (false, false): step = .root; startsAtRoot = true
            case (true, false): step = .category(.tools); startsAtRoot = false
            default: step = .category(.convert); startsAtRoot = false
            }
        } else {
            step = .root
            startsAtRoot = false
        }
        if outcome.sourceBytes == nil, let provider = outcome.sourceBytesProvider {
            sizeTask = Task { [weak self] in
                let bytes = await provider()
                guard !Task.isCancelled, let self else { return }
                self.sourceBytes = bytes
                self.sizeTask = nil
            }
        }
    }

    /// Stops every in-flight size/estimate task; call when the wheel is dismissed or replaced.
    func cancelWork() {
        sizeTask?.cancel()
        sizeTask = nil
        cancelEstimates(except: nil)
    }

    private func cancelEstimates(except keep: FileFormat?) {
        for (format, task) in inFlight where format != keep {
            task.cancel()
            inFlight[format] = nil
        }
    }

    var items: [WheelItem] { WheelLayout.items(style: style, step: step, formats: formats, tools: tools) }
    var panelSize: CGSize { WheelLayout.panelSize(style: style, formats: formats, tools: tools) }

    var selectedEntry: WheelEntry? {
        guard let selected, items.indices.contains(selected) else { return nil }
        return items[selected].entry
    }

    func move(_ direction: PickerMove) {
        if let next = WheelNavigator.next(from: selected, direction: direction, items: items) { selected = next }
    }

    func enter(_ category: WheelCategory) {
        guard style == .twoSteps else { return }
        step = .category(category)
        selected = nil
    }

    @discardableResult
    func back() -> Bool {
        guard startsAtRoot, step != .root else { return false }
        step = .root
        selected = nil
        return true
    }

    func handle(keyCode: UInt16) -> PickerKeyResult {
        switch keyCode {
        case 123: move(.left); return .handled
        case 124: move(.right); return .handled
        case 125: move(.down); return .handled
        case 126: move(.up); return .handled
        case 36, 76:
            switch selectedEntry {
            case .category(let category)?: enter(category); return .handled
            case .action(let action)?: return .choose(action)
            case nil: return .handled
            }
        case 53:
            return back() ? .handled : .close
        default:
            return .ignored
        }
    }

    private func selectionChanged() {
        if case .action(.format(let format))? = selectedEntry {
            cancelEstimates(except: format)
            requestEstimate(for: format)
        } else {
            cancelEstimates(except: nil)
        }
    }

    @discardableResult
    func requestEstimate(for format: FileFormat) -> Task<Void, Never>? {
        if let running = inFlight[format] { return running }
        guard estimates[format] == nil, !failed.contains(format), let estimate = outcome.estimate else { return nil }
        let task = Task { [weak self] in
            let bytes = await estimate(format)
            guard !Task.isCancelled, let self else { return }
            if let bytes { self.estimates[format] = bytes } else { self.failed.insert(format) }
            self.inFlight[format] = nil
            self.objectWillChange.send()
        }
        inFlight[format] = task
        return task
    }

    var hubTitle: String {
        if let entry = selectedEntry {
            switch entry {
            case .action(.format(let format)): return format.displayName
            case .action(.tool(let tool)): return tool.title
            case .category(let category): return Self.title(of: category)
            }
        }
        if case .category(let category) = step { return Self.title(of: category) }
        return outcome.sourceFormat?.displayName ?? "Shapeshift"
    }

    var hubDetail: String {
        switch selectedEntry {
        case .action(.format(let format))?:
            if let bytes = estimates[format] { return "~" + Self.sizeText(bytes) }
            if inFlight[format] != nil { return "…" }
            return sourceText
        case .action(.tool)?:
            return "Edit"
        default:
            return sourceText
        }
    }

    private var sourceText: String {
        let count = fileCount == 1 ? "1 file" : "\(fileCount) files"
        guard let bytes = sourceBytes else { return count }
        return fileCount > 1 ? Self.sizeText(bytes) + " · " + count : Self.sizeText(bytes)
    }

    static func sizeText(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    private static func title(of category: WheelCategory) -> String {
        category == .convert ? "Convert" : "Tools"
    }
}
