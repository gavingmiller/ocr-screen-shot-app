import Foundation

/// Simple persistence layer for keeping a local history of parsed stats.
/// The database stores an array of `StatsModel` records in a JSON file
/// within the application's documents directory.
final class StatsDatabase: ObservableObject {
    static let shared = StatsDatabase()

    @Published private(set) var entries: [StatsModel] = []

    private let saveURL: URL

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.saveURL = docs.appendingPathComponent("stats.json")
        load()
    }

    private func load() {
        guard let data = try? Data(contentsOf: saveURL) else { return }
        if let decoded = try? JSONDecoder().decode([StatsModel].self, from: data) {
            entries = decoded
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: saveURL)
    }

    /// Determine whether the database already contains a record matching the
    /// provided ``StatsModel`` according to the duplicate detection rules.
    func isDuplicate(_ stats: StatsModel) -> Bool {
        entries.contains { $0.isDuplicate(of: stats) }
    }

    /// Add a new stats record to the database and persist the change.
    ///
    /// If the provided ``StatsModel`` contains a parsing error or it matches an
    /// existing entry based on duplicate detection criteria the entry is not
    /// stored. The return value indicates whether the stats were added.
    @discardableResult
    func add(_ stats: StatsModel) -> Bool {
        guard !stats.hasParsingError else { return false }
        guard !isDuplicate(stats) else { return false }
        entries.append(stats)
        save()
        return true
    }

    /// Remove the provided stats from the database and persist the change.
    func remove(_ stats: StatsModel) {
        entries.removeAll { $0 == stats }
        save()
    }
}
