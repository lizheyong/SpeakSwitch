import Foundation
import Testing
@testable import VoiceSwitchCore

struct UsageTests {
    private let first = UsageProvider(Provider.catalog[0])
    private let second = UsageProvider(Provider.catalog[1])
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }
    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }

    @Test func translationEndedByOrdinaryFnKeepsItsOriginalMode() {
        let start = date("2026-10-15T09:00:00Z")
        var history = UsageHistory()
        history.pulse(provider: first, mode: .translation, at: start)
        let running = history.summary(for: .today, now: start.addingTimeInterval(3_600), calendar: calendar)
        #expect(running.starts == 1)
        #expect(running.active == 1)
        #expect(running.incomplete == 0)
        #expect(running.duration == 0)

        history.pulse(provider: first, mode: .dictation, at: start.addingTimeInterval(45))
        let finished = history.summary(for: .today, now: start, calendar: calendar)
        #expect(finished.starts == 1)
        #expect(finished.completed == 1)
        #expect(finished.active == 0)
        #expect(finished.duration == 45)
        #expect(finished.averageDuration == 45)
        #expect(finished.providers.first?.dictations == 0)
        #expect(finished.providers.first?.translations == 1)
    }

    @Test func interruptionRetainsStartButNeverAddsIdleTime() {
        let start = date("2026-10-15T09:00:00Z")
        var history = UsageHistory()
        history.pulse(provider: first, mode: .dictation, at: start)
        history.interrupt()
        history.interrupt()
        history.pulse(provider: first, mode: .dictation, at: start.addingTimeInterval(3_600))
        history.pulse(provider: first, mode: .dictation, at: start.addingTimeInterval(3_620))

        let summary = history.summary(for: .today, now: start, calendar: calendar)
        #expect(summary.starts == 2)
        #expect(summary.completed == 1)
        #expect(summary.incomplete == 1)
        #expect(summary.active == 0)
        #expect(summary.duration == 20)
        #expect(summary.averageDuration == 20)
        #expect(history.sessions.first?.endedAt == nil)
    }

    @Test func switchingProviderCannotPairTwoDifferentApps() {
        let start = date("2026-10-15T09:00:00Z")
        var history = UsageHistory()
        history.pulse(provider: first, mode: .dictation, at: start)
        history.pulse(provider: second, mode: .translation, at: start.addingTimeInterval(600))
        history.pulse(provider: second, mode: .dictation, at: start.addingTimeInterval(630))

        let summary = history.summary(for: .today, now: start, calendar: calendar)
        #expect(summary.starts == 2)
        #expect(summary.incomplete == 1)
        #expect(summary.duration == 30)
        #expect(summary.providers.map(\.id) == [second.id, first.id])
        #expect(summary.providers.first?.share == 1)
        #expect(summary.providers.last?.share == 0)
    }

    @Test func restartingPreservesHistoryWithoutResumingAnOpenSession() throws {
        let start = date("2026-10-15T09:00:00Z")
        var original = UsageHistory()
        original.pulse(provider: first, mode: .translation, at: start)
        let saved = try JSONEncoder().encode(original.sessions)
        var restarted = UsageHistory(sessions: try JSONDecoder().decode([UsageSession].self, from: saved))
        #expect(restarted.activeSessionID == nil)
        #expect(restarted.sessions.first?.provider.name == first.name)
        restarted.pulse(provider: first, mode: .dictation, at: start.addingTimeInterval(3_600))
        restarted.pulse(provider: first, mode: .dictation, at: start.addingTimeInterval(3_615))

        let summary = restarted.summary(for: .today, now: start, calendar: calendar)
        #expect(summary.starts == 2)
        #expect(summary.incomplete == 1)
        #expect(summary.duration == 15)
        #expect(summary.averageDuration == 15)
    }

    @Test func crossMidnightSessionBelongsEntirelyToItsStartDay() {
        let now = date("2026-10-15T12:00:00Z")
        let sessions = [
            UsageSession(provider: first, mode: .dictation, startedAt: date("2026-10-14T23:59:50Z"), endedAt: date("2026-10-15T00:00:20Z")),
            UsageSession(provider: first, mode: .dictation, startedAt: date("2026-10-15T08:00:00Z"), endedAt: date("2026-10-15T08:01:00Z")),
            UsageSession(provider: second, mode: .dictation, startedAt: date("2026-10-09T00:00:00Z"), endedAt: date("2026-10-09T00:00:10Z")),
            UsageSession(provider: second, mode: .dictation, startedAt: date("2026-10-08T23:59:59Z"), endedAt: date("2026-10-09T00:00:09Z"))
        ]
        let history = UsageHistory(sessions: sessions)
        let today = history.summary(for: .today, now: now, calendar: calendar)
        #expect(today.starts == 1)
        #expect(today.duration == 60)
        #expect(today.days.count == 1)
        let week = history.summary(for: .week, now: now, calendar: calendar)
        #expect(week.starts == 3)
        #expect(week.duration == 100)
        #expect(week.days.count == 7)
        #expect(week.days[5].duration == 30)
        #expect(week.days[6].duration == 60)
        #expect(week.providers.first?.share == 0.9)
        #expect(week.providers.first?.averageDuration == 45)
    }

    @Test func monthAndAllTimeKeepTheirOwnTotalsWithThirtyDayActivity() {
        let now = date("2026-10-15T12:00:00Z")
        let history = UsageHistory(sessions: [
            .init(provider: first, mode: .dictation, startedAt: date("2026-09-15T23:59:59Z")),
            .init(provider: first, mode: .dictation, startedAt: date("2026-09-16T00:00:00Z")),
            .init(provider: first, mode: .dictation, startedAt: date("2026-10-15T00:00:00Z"))
        ])
        let month = history.summary(for: .month, now: now, calendar: calendar)
        let all = history.summary(for: .all, now: now, calendar: calendar)
        #expect(month.starts == 2)
        #expect(month.days.count == 30)
        #expect(month.days.first?.starts == 1)
        #expect(month.days.last?.starts == 1)
        #expect(all.starts == 3)
        #expect(all.days.reduce(0) { $0 + $1.starts } == 2)
        #expect(all.incomplete == 3)
    }

    @Test func dailyBucketsFollowLocalCalendarAcrossDaylightSaving() {
        var local = calendar
        local.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let now = date("2026-03-09T12:00:00-07:00")
        let history = UsageHistory(sessions: [
            .init(provider: first, mode: .dictation, startedAt: date("2026-03-03T00:00:00-08:00")),
            .init(provider: first, mode: .dictation, startedAt: date("2026-03-02T23:59:59-08:00")),
            .init(provider: first, mode: .translation, startedAt: date("2026-03-08T23:59:59-07:00"))
        ])
        let week = history.summary(for: .week, now: now, calendar: local)
        #expect(week.starts == 2)
        #expect(week.days.count == 7)
        #expect(week.days[5].starts == 1)
        #expect(week.days[6].date.timeIntervalSince(week.days[5].date) == 23 * 3_600)
    }
}
