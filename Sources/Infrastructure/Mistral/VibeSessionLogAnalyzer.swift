import Foundation
import Domain

/// Analyzes Vibe session log files to produce daily usage reports.
/// Reads from ~/.vibe/logs/session/session_YYYYMMDD_*/metadata.json
public struct VibeSessionLogAnalyzer: DailyUsageAnalyzing, Sendable {
    private let vibeSessionsDir: URL
    private let calendar: Calendar
    private let now: @Sendable () -> Date

    /// Devstral pricing: $0.40 per million input tokens
    private static let inputPricePerMToken: Decimal = 0.40
    /// Devstral pricing: $2.00 per million output tokens
    private static let outputPricePerMToken: Decimal = 2.00

    public init(
        vibeSessionsDir: URL = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".vibe/logs/session"),
        calendar: Calendar = .current,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.vibeSessionsDir = vibeSessionsDir
        self.calendar = calendar
        self.now = now
    }

    public func analyzeToday() async throws -> DailyUsageReport {
        let currentDate = now()
        let todayStart = calendar.startOfDay(for: currentDate)
        let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart)!

        let sessions = loadSessions()
        AppLog.probes.info("VibeSessionLogAnalyzer: found \(sessions.count) sessions")

        let todaySessions = sessions.filter { session in
            session.date >= todayStart && session.date < todayStart.addingTimeInterval(86400)
        }
        let yesterdaySessions = sessions.filter { session in
            session.date >= yesterdayStart && session.date < todayStart
        }

        let todayStat = aggregate(sessions: todaySessions, date: todayStart)
        let yesterdayStat = aggregate(sessions: yesterdaySessions, date: yesterdayStart)

        AppLog.probes.info("VibeSessionLogAnalyzer: today=\(todayStat.formattedCost)/\(todayStat.formattedTokens), yesterday=\(yesterdayStat.formattedCost)/\(yesterdayStat.formattedTokens)")

        return DailyUsageReport(today: todayStat, previous: yesterdayStat)
    }

    // MARK: - Private

    private struct ParsedSession {
        let date: Date
        let promptTokens: Int
        let completionTokens: Int
        let workingTime: TimeInterval
    }

    private func loadSessions() -> [ParsedSession] {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(
            at: vibeSessionsDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var sessions: [ParsedSession] = []

        for entry in contents {
            // Only process directories matching session_YYYYMMDD_* pattern
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: entry.path, isDirectory: &isDir), isDir.boolValue else { continue }

            let name = entry.lastPathComponent
            guard name.hasPrefix("session_"), name.count > 16 else { continue }

            // Extract date from directory name: session_YYYYMMDD_suffix
            let parts = name.split(separator: "_", maxSplits: 2)
            guard parts.count >= 2 else { continue }
            let dateStr = String(parts[1])
            guard let sessionDate = parseSessionDate(dateStr) else {
                AppLog.probes.debug("VibeSessionLogAnalyzer: skipping dir with unparseable date: \(name)")
                continue
            }

            let metadataURL = entry.appendingPathComponent("metadata.json")
            guard fileManager.fileExists(atPath: metadataURL.path) else { continue }

            guard let data = try? Data(contentsOf: metadataURL) else { continue }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            guard let metadata = try? decoder.decode(VibeSessionMetadata.self, from: data) else {
                AppLog.probes.debug("VibeSessionLogAnalyzer: skipping malformed metadata at \(metadataURL.path)")
                continue
            }

            let workingTime = computeWorkingTime(
                startTime: metadata.startTime,
                endTime: metadata.endTime
            )

            sessions.append(ParsedSession(
                date: sessionDate,
                promptTokens: metadata.stats.sessionPromptTokens,
                completionTokens: metadata.stats.sessionCompletionTokens,
                workingTime: workingTime
            ))
        }

        return sessions
    }

    private func parseSessionDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.timeZone = calendar.timeZone
        return formatter.date(from: dateString)
    }

    private func computeWorkingTime(startTime: String?, endTime: String?) -> TimeInterval {
        let isoFormatter = ISO8601DateFormatter()
        guard
            let startStr = startTime,
            let endStr = endTime,
            let start = isoFormatter.date(from: startStr),
            let end = isoFormatter.date(from: endStr),
            end > start
        else { return 0 }
        return end.timeIntervalSince(start)
    }

    private func aggregate(sessions: [ParsedSession], date: Date) -> DailyUsageStat {
        guard !sessions.isEmpty else { return .empty(for: date) }

        var totalCost: Decimal = 0
        var totalTokens = 0
        var totalWorkingTime: TimeInterval = 0

        for session in sessions {
            let promptCost = Decimal(session.promptTokens) * Self.inputPricePerMToken / 1_000_000
            let completionCost = Decimal(session.completionTokens) * Self.outputPricePerMToken / 1_000_000
            totalCost += promptCost + completionCost
            totalTokens += session.promptTokens + session.completionTokens
            totalWorkingTime += session.workingTime
        }

        return DailyUsageStat(
            date: date,
            totalCost: totalCost,
            totalTokens: totalTokens,
            workingTime: totalWorkingTime,
            sessionCount: sessions.count
        )
    }
}

// MARK: - Internal Decodable Types

private struct VibeSessionMetadata: Decodable {
    let stats: VibeSessionStats
    let startTime: String?
    let endTime: String?
}

private struct VibeSessionStats: Decodable {
    let sessionPromptTokens: Int
    let sessionCompletionTokens: Int
}
