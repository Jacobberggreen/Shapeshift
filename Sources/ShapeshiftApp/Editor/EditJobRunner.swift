import Foundation
import ConversionCore
import EditCore

/// Applies an EditorPlan to each input file and returns one result per file.
struct EditJobRunner: Sendable {
    func run(inputs: [URL], plan: EditorPlan) async -> [ConversionResult] {
        var results: [ConversionResult] = []
        for (index, input) in inputs.enumerated() {
            if Task.isCancelled {
                results += inputs[index...].map { ConversionResult(input: $0, result: .failure(.cancelled)) }
                break
            }
            do {
                results.append(ConversionResult(input: input, result: .success(try runOne(input, plan: plan))))
            } catch let error as ConversionError {
                results.append(ConversionResult(input: input, result: .failure(error)))
            } catch is CancellationError {
                results.append(ConversionResult(input: input, result: .failure(.cancelled)))
            } catch {
                results.append(ConversionResult(input: input, result: .failure(.failed(error.localizedDescription))))
            }
        }
        return results
    }

    private func runOne(_ input: URL, plan: EditorPlan) throws -> URL {
        let ext = input.pathExtension
        guard plan.hasWork(forExtension: ext) else {
            throw ConversionError.failed("Nothing to do for \(input.lastPathComponent) with the selected tools.")
        }
        let settings = plan.exportSettings(forExtension: ext)
        let label = plan.label(forExtension: ext)
        let provisional = OutputPlanner.uniqueSibling(of: input, fileExtension: settings.format.fileExtension, label: label)
        let temp = OutputPlanner.temporarySibling(for: provisional)
        do {
            try Task.checkCancellation()
            do {
                try EditExporter.export(source: input, pipeline: plan.pipeline(), settings: settings, to: temp)
            } catch let error as EditError {
                throw ConversionError.failed(error.localizedDescription)
            }
            try Task.checkCancellation()
            return try OutputCommitter.commit(temp: temp, nextTo: input, label: label,
                                              fileExtension: settings.format.fileExtension)
        } catch {
            try? FileManager.default.removeItem(at: temp)
            throw error
        }
    }
}
