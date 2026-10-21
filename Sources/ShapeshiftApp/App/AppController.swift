import AppKit
import SwiftUI
import ConversionCore
import EditCore

/// Owns the menu bar item, the drag monitor and every running job.
@MainActor
final class AppController {
    let settings = SettingsStore()
    let service = ConversionService.makeDefault()
    private var statusItem: StatusItemController!
    private let monitor: DragMonitor
    private let panel = FormatPanel()
    private let toolPanel = FormatPanel()
    private let finderPanel = KeyPanel()
    private var finderModel: ActionPickerModel?
    private var finderURLs: [URL] = []
    private var finderKeyMonitor: Any?
    private var toolModel: ToolPickerModel?
    private var editor: ImageEditorController?
    private var pdfTool: PDFToolController?
    private let framePresets = FramePresetStore()
    private var shownURLs: [URL] = []
    private var suppressedUntilDragEnds = false
    private var hideGeneration = 0
    private var keyMonitor: Any?
    private var pickerModel: PickerModel?
    private var wheelModel: WheelModel?
    private var finderWheel: WheelModel?
    private var jobs: [UUID: Task<Void, Never>] = [:]
    private let notifier = Notifier()
    private var settingsWindow: NSWindow?
    private let ffmpegPath = FFmpegLocator.locate()?.path

    var hasRunningJobs: Bool { !jobs.isEmpty }

    init() {
        monitor = DragMonitor(settings: settings)
        let settings = self.settings
        statusItem = StatusItemController(onSettings: { [weak self] in self?.openSettings() },
                                          ffmpegAvailable: service.hasFFmpeg,
                                          triggerSymbols: { "\(settings.triggers.convert.symbols) (convert) or \(settings.triggers.tools.symbols) (image tools)" })
        monitor.onFileDrag = { [weak self] urls, location, intent in
            self?.showPicker(urls: urls, at: location, intent: intent)
        }
        monitor.onDragEnded = { [weak self] in self?.dragEnded() }
        notifier.setUp()
        monitor.start()
    }

    func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView(settings: settings, ffmpegPath: ffmpegPath)
            let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable, .miniaturizable, .resizable],
                                  backing: .buffered, defer: false)
            window.title = "Shapeshift Settings"
            window.isReleasedWhenClosed = false
            GlassWindow.install(view, in: window, size: NSSize(width: 560, height: 560))
            let titleInset = window.frame.height - window.contentLayoutRect.height
            window.contentMinSize = NSSize(width: 520, height: 380 + titleInset)
            let hasSavedFrame = UserDefaults.standard.object(forKey: "NSWindow Frame ShapeshiftSettings") != nil
            window.setFrameAutosaveName("ShapeshiftSettings")
            if !hasSavedFrame { window.center() }
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func showPicker(urls: [URL], at location: NSPoint, intent: DragIntent) {
        hideFinderPicker()
        hideGeneration += 1
        if suppressedUntilDragEnds { return }
        let style = settings.menuStyle
        if style != .classicGrid {
            // Cheap re-show guard for the 30 Hz drag ticks, before any planner work. The wheel's panel is
            // fixed by the URLs for the combined styles (either panel being visible means it is the one),
            // and by the intent for Two steps (convert uses `panel`, tools uses `toolPanel`).
            let wouldUse: Bool = style == .twoSteps ? (intent == .convert ? panel.isVisible : toolPanel.isVisible)
                                                    : (panel.isVisible || toolPanel.isVisible)
            if wouldUse && urls == shownURLs { return }
            let formats = service.commonTargets(for: urls)
            guard let content = WheelContentPlanner.plan(style: style, intent: intent, formats: formats,
                                                         tools: ToolKind.available(for: urls)) else { return }
            let target = content.formats.isEmpty ? toolPanel : panel
            let other = content.formats.isEmpty ? panel : toolPanel
            if target.isVisible && urls == shownURLs { return }
            if other.isVisible { hidePicker() }
            shownURLs = urls
            let model = WheelModel(style: style, formats: content.formats, tools: content.tools, fileCount: urls.count,
                                   outcome: OutcomeEstimator.source(for: urls, quality: settings.quality))
            wheelModel?.cancelWork()
            wheelModel = model
            target.present(content: WheelPickerView(model: model) { [weak self] in self?.choosePickerAction($0) },
                           centeredAt: location)
            startKeyMonitor()
            return
        }
        switch intent {
        case .convert:
            if panel.isVisible && urls == shownURLs { return }
            if toolPanel.isVisible { hidePicker() }
            let formats = service.commonTargets(for: urls)
            guard !formats.isEmpty else { return }
            shownURLs = urls
            let model = PickerModel(formats: formats, fileCount: urls.count)
            panel.present(model: model, at: location) { [weak self] format in
                self?.dropped(on: format)
            }
            pickerModel = model
            startKeyMonitor()
        case .tools:
            if toolPanel.isVisible && urls == shownURLs { return }
            if panel.isVisible { hidePicker() }
            let tools = ToolKind.available(for: urls)
            guard !tools.isEmpty else { return }
            shownURLs = urls
            let model = ToolPickerModel(tools: tools, fileCount: urls.count)
            toolPanel.present(content: ToolPickerView(model: model) { [weak self] tool in
                self?.toolDropped(tool)
            }, at: location)
            toolModel = model
            startKeyMonitor()
        }
    }

    /// The drop lands on the panel at the same moment the button is released,
    /// so hiding is delayed; a drop hides it immediately.
    private func dragEnded() {
        suppressedUntilDragEnds = false
        hideGeneration += 1
        let generation = hideGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self, self.hideGeneration == generation else { return }
            self.hidePicker()
        }
    }

    private func hidePicker() {
        stopKeyMonitor()
        panel.dismiss()
        toolPanel.dismiss()
        shownURLs = []
        pickerModel = nil
        toolModel = nil
        wheelModel?.cancelWork()
        wheelModel = nil
    }

    private func choosePickerAction(_ action: PickerAction) {
        switch action {
        case .format(let format): dropped(on: format)
        case .tool(let tool): toolDropped(tool)
        }
    }

    /// Entry point for the Finder Service: one popup with formats and, for images, tools.
    func showFinderPicker(urls: [URL]) {
        hidePicker()
        hideFinderPicker()
        let formats = service.commonTargets(for: urls)
        let tools = ToolKind.available(for: urls)
        guard !formats.isEmpty || !tools.isEmpty else {
            notifier.post(title: "Nothing to do", body: "Shapeshift can't convert these files.", reveal: nil)
            return
        }
        finderURLs = urls
        finderPanel.onResignKey = { [weak self] in self?.hideFinderPicker() }
        if settings.menuStyle != .classicGrid {
            let wheel = WheelModel(style: settings.menuStyle, formats: formats, tools: tools, fileCount: urls.count,
                                   outcome: OutcomeEstimator.source(for: urls, quality: settings.quality))
            finderWheel?.cancelWork()
            finderWheel = wheel
            finderPanel.presentKey(content: WheelPickerView(model: wheel) { [weak self] in self?.finderChose($0) },
                                   centeredAt: NSEvent.mouseLocation)
        } else {
            let model = ActionPickerModel(formats: formats, tools: tools, fileCount: urls.count)
            finderModel = model
            finderPanel.presentKey(content: ActionPickerView(model: model) { [weak self] action in
                self?.finderChose(action)
            }, at: NSEvent.mouseLocation)
        }
        finderKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let result: PickerKeyResult
            if let wheel = self.finderWheel { result = wheel.handle(keyCode: event.keyCode) }
            else if let model = self.finderModel { result = model.handle(keyCode: event.keyCode) }
            else { return event }
            switch result {
            case .ignored: return event
            case .handled: return nil
            case .close: self.hideFinderPicker(); return nil
            case .choose(let action): self.finderChose(action); return nil
            }
        }
    }

    private func finderChose(_ action: PickerAction) {
        let urls = finderURLs
        hideFinderPicker()
        switch action {
        case .format(let format): startConversion(urls: urls, format: format)
        case .tool(let tool): open(tool, urls: urls)
        }
    }

    /// Idempotent: the panel's resign-key callback calls this again while it is dismissed.
    private func hideFinderPicker() {
        guard finderModel != nil || finderWheel != nil else { return }
        finderModel = nil
        finderWheel?.cancelWork()
        finderWheel = nil
        finderURLs = []
        if let finderKeyMonitor { NSEvent.removeMonitor(finderKeyMonitor) }
        finderKeyMonitor = nil
        finderPanel.onResignKey = nil
        finderPanel.dismiss()
    }

    private func startKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            MainActor.assumeIsolated { self?.handleKey(event.keyCode) }
        }
    }

    private func stopKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    private func handleKey(_ keyCode: UInt16) {
        if let wheel = wheelModel {
            switch wheel.handle(keyCode: keyCode) {
            case .choose(let action):
                suppressedUntilDragEnds = (NSEvent.pressedMouseButtons & 1) != 0
                choosePickerAction(action)
            case .close:
                suppressedUntilDragEnds = (NSEvent.pressedMouseButtons & 1) != 0
                hidePicker()
            case .handled, .ignored:
                break
            }
            return
        }
        if let tools = toolModel {
            switch keyCode {
            case 123: tools.move(.left)
            case 124: tools.move(.right)
            case 125: tools.move(.down)
            case 126: tools.move(.up)
            case 36, 76:                  // return, keypad enter
                if let tool = tools.selectedTool {
                    suppressedUntilDragEnds = (NSEvent.pressedMouseButtons & 1) != 0
                    toolDropped(tool)
                }
            case 53:                      // escape
                suppressedUntilDragEnds = (NSEvent.pressedMouseButtons & 1) != 0
                hidePicker()
            default: break
            }
            return
        }
        guard let model = pickerModel else { return }
        switch keyCode {
        case 123: model.move(.left)
        case 124: model.move(.right)
        case 125: model.move(.down)
        case 126: model.move(.up)
        case 36, 76:                      // return, keypad enter
            if let format = model.selectedFormat {
                suppressedUntilDragEnds = (NSEvent.pressedMouseButtons & 1) != 0   // only while a drag is still in progress
                dropped(on: format)
            }
        case 53:                          // escape
            suppressedUntilDragEnds = (NSEvent.pressedMouseButtons & 1) != 0
            hidePicker()
        default: break
        }
    }

    private func dropped(on format: FileFormat) {
        let urls = shownURLs
        hidePicker()
        startConversion(urls: urls, format: format)
    }

    private func toolDropped(_ tool: ToolKind) {
        let urls = shownURLs
        hidePicker()
        open(tool, urls: urls)
    }

    private func open(_ tool: ToolKind, urls: [URL]) {
        switch tool {
        case .image(let tool): openEditor(urls: urls, tool: tool)
        case .pdf(let tool): openPDFTool(urls: urls, tool: tool)
        }
    }

    func openPDFTool(urls: [URL], tool: PDFTool) {
        pdfTool?.close()
        let controller = PDFToolController(urls: urls, tool: tool) { [weak self] work in self?.startPDFJob(urls: urls, work) }
        controller.onClose = { [weak self, weak controller] in
            if self?.pdfTool === controller { self?.pdfTool = nil }
        }
        pdfTool = controller
        controller.show()
    }

    /// Runs PDF work off the main thread; the closure returns the files it wrote.
    func startPDFJob(urls: [URL], _ work: @escaping PDFJob) {
        let id = UUID()
        let input = urls[0]
        let task = Task.detached {
            let result: Result<URL, ConversionError>
            do {
                guard let output = try work().first else { throw ConversionError.failed("Nothing was written.") }
                result = .success(output)
            } catch let error as ConversionError {
                result = .failure(error)
            } catch {
                result = .failure(.failed(error.localizedDescription))
            }
            await MainActor.run {
                self.jobs[id] = nil
                self.statusItem.setBusy(self.jobs.count)
                self.finished([ConversionResult(input: input, result: result)])
            }
        }
        jobs[id] = task
        statusItem.setBusy(jobs.count)
    }

    func openEditor(urls: [URL], tool: EditTool) {
        editor?.close()
        let controller = ImageEditorController(urls: urls, initialTool: tool, presets: framePresets,
                                               baseQuality: settings.quality,
                                               transparencyPreview: settings.transparencyPreview) { [weak self] plan, urls in
            self?.startEdit(urls: urls, plan: plan)
        }
        controller.onClose = { [weak self, weak controller] in
            if self?.editor === controller { self?.editor = nil }
        }
        editor = controller
        controller.show()
    }

    func startEdit(urls: [URL], plan: EditorPlan) {
        let id = UUID()
        let task = Task {
            let results = await EditJobRunner().run(inputs: urls, plan: plan)
            await MainActor.run {
                self.jobs[id] = nil
                self.statusItem.setBusy(self.jobs.count)
                self.finished(results)
            }
        }
        jobs[id] = task
        statusItem.setBusy(jobs.count)
    }

    func startConversion(urls: [URL], format: FileFormat) {
        let id = UUID()
        let options = ConversionOptions(quality: settings.quality)
        let task = Task { [service] in
            let results = await service.convert(urls, to: format, options: options)
            await MainActor.run {
                self.jobs[id] = nil
                self.statusItem.setBusy(self.jobs.count)
                self.finished(results)
            }
        }
        jobs[id] = task
        statusItem.setBusy(jobs.count)
    }

    /// Cancels every running conversion (terminating ffmpeg, removing temp files) and waits for them to finish.
    func cancelAllJobs() async {
        let running = Array(jobs.values)
        for task in running { task.cancel() }
        for task in running { await task.value }
    }

    private func finished(_ results: [ConversionResult]) {
        if results.allSatisfy({ if case .failure(.cancelled) = $0.result { return true } else { return false } }) { return }
        let successes = results.compactMap { try? $0.result.get() }
        let failures = results.compactMap { r -> String? in
            if case .failure(let error) = r.result {
                return "\(r.input.lastPathComponent): \(error.localizedDescription)"
            }
            return nil
        }
        if failures.isEmpty, let first = successes.first {
            notifier.post(title: successes.count == 1 ? "Done" : "Done — \(successes.count) files",
                          body: first.lastPathComponent, reveal: first)
        } else if !failures.isEmpty {
            notifier.post(title: successes.isEmpty ? "Failed" : "Some files failed",
                          body: failures.joined(separator: "\n"), reveal: successes.first)
        }
    }
}
