import Foundation

public enum ProviderCycle {
    /// Keep catalog order while skipping providers the user has stopped or excluded.
    public static func next(in providers: [Provider], currentID: String?, runningIDs: Set<String>, excludedIDs: Set<String>) -> Provider? {
        let eligible = providers.filter { $0.isConfigured && runningIDs.contains($0.id) && !excludedIDs.contains($0.id) }
        guard !eligible.isEmpty else { return nil }
        guard let currentIndex = providers.firstIndex(where: { $0.id == currentID }) else { return eligible.first }
        let ordered = Array(providers.dropFirst(currentIndex + 1)) + Array(providers.prefix(currentIndex + 1))
        let eligibleIDs = Set(eligible.map(\.id))
        return ordered.first { eligibleIDs.contains($0.id) }
    }
}
