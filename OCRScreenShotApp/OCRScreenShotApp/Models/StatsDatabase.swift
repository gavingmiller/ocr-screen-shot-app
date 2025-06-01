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

    /// Add a new stats record to the database and persist the change.
    ///
    /// If the provided ``StatsModel`` contains a parsing error the entry is
    /// ignored to prevent invalid data from polluting the history.
    func add(_ stats: StatsModel) {
        guard !stats.hasParsingError else { return }
        entries.append(stats)
        save()
    }
}
