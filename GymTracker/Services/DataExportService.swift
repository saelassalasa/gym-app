import Foundation
import SwiftData

enum DataExportService {

    // MARK: - Export Models

    struct ExportData: Codable {
        let exportDate: String
        let totalSessions: Int
        let totalSets: Int
        let sessions: [SessionExport]
    }

    struct SessionExport: Codable {
        let date: String
        let templateName: String?
        let durationSeconds: TimeInterval
        let notes: String
        let sets: [SetExport]
    }

    struct SetExport: Codable {
        let exerciseName: String
        let setNumber: Int
        let weight: Double
        let reps: Int
        let rpe: Int?
        let isCompleted: Bool
    }

    // MARK: - ISO Formatter

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    // MARK: - Export

    @MainActor
    static func exportJSON(context: ModelContext) -> Data? {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { $0.isCompleted },
            sortBy: [SortDescriptor(\WorkoutSession.date, order: .reverse)]
        )

        guard let sessions = try? context.fetch(descriptor) else {
            debugLog("Export: failed to fetch sessions")
            return nil
        }

        let sessionExports: [SessionExport] = sessions.map { session in
            let orderedSets = (session.sets ?? [])
                .sorted { $0.setNumber < $1.setNumber }

            let setExports: [SetExport] = orderedSets.map { set in
                SetExport(
                    exerciseName: set.exercise?.name ?? "Unknown",
                    setNumber: set.setNumber,
                    weight: set.weight,
                    reps: set.reps,
                    rpe: set.rpe,
                    isCompleted: set.isCompleted
                )
            }

            return SessionExport(
                date: isoFormatter.string(from: session.date),
                templateName: session.template?.displayName,
                durationSeconds: session.duration,
                notes: session.notes,
                sets: setExports
            )
        }

        let totalSets = sessionExports.reduce(0) { $0 + $1.sets.count }

        let exportData = ExportData(
            exportDate: isoFormatter.string(from: Date()),
            totalSessions: sessionExports.count,
            totalSets: totalSets,
            sessions: sessionExports
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let data = try encoder.encode(exportData)
            debugLog("Export: encoded \(sessionExports.count) sessions, \(totalSets) sets")
            return data
        } catch {
            debugLog("Export: encoding failed — \(error)")
            return nil
        }
    }

    /// Write JSON data to a temp file and return the URL
    @MainActor
    static func exportToFile(context: ModelContext) -> URL? {
        guard let data = exportJSON(context: context) else { return nil }

        let fileName = "GymTracker_Export_\(formattedFileDate()).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try data.write(to: url, options: .atomic)
            debugLog("Export: wrote file to \(url.lastPathComponent)")
            return url
        } catch {
            debugLog("Export: file write failed — \(error)")
            return nil
        }
    }

    // MARK: - CSV Export

    @MainActor
    static func exportCSV(context: ModelContext) -> Data? {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { $0.isCompleted },
            sortBy: [SortDescriptor(\WorkoutSession.date, order: .reverse)]
        )

        guard let sessions = try? context.fetch(descriptor) else {
            debugLog("CSV Export: failed to fetch sessions")
            return nil
        }

        var csv = "Date,Template,Duration(s),Exercise,Set#,Weight(kg),Reps,RPE,Completed\n"

        for session in sessions {
            let dateStr = isoFormatter.string(from: session.date)
            let templateName = (session.template?.displayName ?? "").replacingOccurrences(of: ",", with: ";")
            let duration = String(format: "%.0f", session.duration)

            let orderedSets = (session.sets ?? []).sorted { $0.setNumber < $1.setNumber }

            for set in orderedSets {
                let exerciseName = (set.exercise?.name ?? "Unknown").replacingOccurrences(of: ",", with: ";")
                let rpeStr = set.rpe.map { String($0) } ?? ""
                let completed = set.isCompleted ? "YES" : "NO"

                csv += "\(dateStr),\(templateName),\(duration),\(exerciseName),\(set.setNumber),\(set.weight),\(set.reps),\(rpeStr),\(completed)\n"
            }
        }

        return csv.data(using: .utf8)
    }

    @MainActor
    static func exportCSVToFile(context: ModelContext) -> URL? {
        guard let data = exportCSV(context: context) else { return nil }

        let fileName = "GymTracker_Export_\(formattedFileDate()).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try data.write(to: url, options: .atomic)
            debugLog("CSV Export: wrote file to \(url.lastPathComponent)")
            return url
        } catch {
            debugLog("CSV Export: file write failed — \(error)")
            return nil
        }
    }

    // MARK: - Helpers

    private static func formattedFileDate() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd_HHmmss"
        return f.string(from: Date())
    }
}
