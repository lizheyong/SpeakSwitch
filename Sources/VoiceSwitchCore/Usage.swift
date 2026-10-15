import Foundation

public enum UsageMode: String, Codable, Sendable {
    case dictation
    case translation
}

/// Keeps names and icon locations available after an app is removed from the list.
public struct UsageProvider: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let bundleIDs: [String]
    public let appNames: [String]
    public let appPath: String?

    public init(_ provider: Provider) {
        id = provider.id
        name = provider.name
        bundleIDs = provider.bundleIDs
        appNames = provider.appNames
        appPath = provider.appPath
    }
}

public struct UsageSession: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let provider: UsageProvider
    public let mode: UsageMode
    public let startedAt: Date
    public var endedAt: Date?

    public init(id: UUID = UUID(), provider: UsageProvider, mode: UsageMode, startedAt: Date, endedAt: Date? = nil) {
        self.id = id
        self.provider = provider
        self.mode = mode
        self.startedAt = startedAt
        self.endedAt = endedAt
    }

    public var duration: TimeInterval? {
        endedAt.map { max(0, $0.timeIntervalSince(startedAt)) }
    }
}

public enum UsagePeriod: String, CaseIterable, Identifiable, Sendable {
    case today, week, month, all

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .today: return "今天"
        case .week: return "近 7 天"
        case .month: return "近 30 天"
        case .all: return "全部"
        }
    }

    fileprivate var dayCount: Int? {
        switch self {
        case .today: return 1
        case .week: return 7
        case .month: return 30
        case .all: return nil
        }
    }
}

public struct UsageProviderSummary: Identifiable, Sendable {
    public var id: String { provider.id }
    public let provider: UsageProvider
    public let starts: Int
    public let completed: Int
    public let incomplete: Int
    public let active: Int
    public let dictations: Int
    public let translations: Int
    public let duration: TimeInterval
    public var averageDuration: TimeInterval { completed > 0 ? duration / Double(completed) : 0 }
    public fileprivate(set) var share: Double = 0

    fileprivate init(sessions: [UsageSession], activeID: UUID?) {
        provider = sessions.last!.provider
        starts = sessions.count
        completed = sessions.filter { $0.endedAt != nil }.count
        active = sessions.filter { $0.id == activeID }.count
        incomplete = starts - completed - active
        dictations = sessions.filter { $0.mode == .dictation }.count
        translations = sessions.filter { $0.mode == .translation }.count
        duration = sessions.compactMap(\.duration).reduce(0, +)
    }
}

public struct UsageDay: Identifiable, Sendable {
    public var id: Date { date }
    public let date: Date
    public let starts: Int
    public let duration: TimeInterval
}

public struct UsageSummary: Sendable {
    public let providers: [UsageProviderSummary]
    public let days: [UsageDay]
    public var starts: Int { providers.reduce(0) { $0 + $1.starts } }
    public var completed: Int { providers.reduce(0) { $0 + $1.completed } }
    public var incomplete: Int { providers.reduce(0) { $0 + $1.incomplete } }
    public var active: Int { providers.reduce(0) { $0 + $1.active } }
    public var duration: TimeInterval { providers.reduce(0) { $0 + $1.duration } }
    public var averageDuration: TimeInterval { completed > 0 ? duration / Double(completed) : 0 }
}

/// Pairs One Fn commands. It estimates usage; it cannot observe an app's recorder.
public struct UsageHistory: Sendable {
    public private(set) var sessions: [UsageSession]
    public private(set) var activeSessionID: UUID?

    /// Persist sessions only. A launch begins with no active pairing, so an
    /// unfinished session cannot accrue time across an app restart.
    public init(sessions: [UsageSession] = []) {
        self.sessions = sessions
        activeSessionID = nil
    }

    public mutating func pulse(provider: UsageProvider, mode: UsageMode, at date: Date) {
        if let index = sessions.firstIndex(where: { $0.id == activeSessionID }),
           sessions[index].provider.id == provider.id {
            sessions[index].endedAt = date
            activeSessionID = nil
        } else {
            let session = UsageSession(provider: provider, mode: mode, startedAt: date)
            sessions.append(session)
            activeSessionID = session.id
        }
    }

    public mutating func interrupt() {
        activeSessionID = nil
    }

    /// A session belongs to its start date, including its entire paired duration.
    /// The all-time summary keeps its activity strip to the latest 30 local days.
    public func summary(for period: UsagePeriod, now: Date = Date(), calendar: Calendar = .current) -> UsageSummary {
        let today = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: today)!
        let start = period.dayCount.map { calendar.date(byAdding: .day, value: 1 - $0, to: today)! }
        let selected = sessions.filter { session in
            session.startedAt < end && (start.map { session.startedAt >= $0 } ?? true)
        }
        var providers = Dictionary(grouping: selected, by: { $0.provider.id }).values.map {
            UsageProviderSummary(sessions: $0, activeID: activeSessionID)
        }
        let duration = providers.reduce(0) { $0 + $1.duration }
        for index in providers.indices {
            providers[index].share = duration > 0 ? providers[index].duration / duration : 0
        }
        providers.sort {
            if $0.duration != $1.duration { return $0.duration > $1.duration }
            if $0.starts != $1.starts { return $0.starts > $1.starts }
            return $0.provider.name < $1.provider.name
        }

        let byDay = Dictionary(grouping: selected, by: { calendar.startOfDay(for: $0.startedAt) })
        let dayCount = period.dayCount ?? 30
        let days = (0..<dayCount).map { offset in
            let date = calendar.date(byAdding: .day, value: offset - dayCount + 1, to: today)!
            let sessions = byDay[date] ?? []
            return UsageDay(date: date, starts: sessions.count, duration: sessions.compactMap(\.duration).reduce(0, +))
        }
        return UsageSummary(providers: providers, days: days)
    }
}
