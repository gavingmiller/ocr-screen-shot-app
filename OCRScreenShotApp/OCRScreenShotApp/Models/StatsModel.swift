import Foundation

/// Model representing the parsed stats from a screenshot. Conforms to
/// ``Codable`` so entries can be persisted.
struct StatsModel: Codable {
    var gameTime: String = ""
    var realTime: String = ""
    var tier: String = ""
    var wave: String = ""
    var killedBy: String = ""
    var coinsEarned: String = ""
    var cashEarned: String = ""
    var interestEarned: String = ""
    var gemBlocksTapped: String = ""
    var cellsEarned: String = ""
    var rerollShardsEarned: String = ""

    init(pairs: [(String, String)]) {
        let dict = Dictionary(uniqueKeysWithValues: pairs.map { ($0.0.lowercased(), $0.1) })
        self.gameTime = StatsModel.normalizeTime(dict["game time"] ?? "")
        self.realTime = StatsModel.normalizeTime(dict["real time"] ?? "")
        self.tier = dict["tier"] ?? ""
        self.wave = dict["wave"] ?? ""
        self.killedBy = dict["killed by"] ?? ""
        self.coinsEarned = dict["coins earned"] ?? ""
        self.cashEarned = dict["cash earned"] ?? ""
        self.interestEarned = dict["interest earned"] ?? ""
        self.gemBlocksTapped = dict["gem blocks tapped"] ?? ""
        self.cellsEarned = dict["cells earned"] ?? ""
        self.rerollShardsEarned = dict["reroll shards earned"] ?? ""
    }

    private static func normalizeTime(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        let pattern = "^(\\d+)h\\s*(\\d+)m\\s*([0-9]{1,3})(?:s)?$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: trimmed.utf16.count)) else {
            return value
        }
        let hoursRange = Range(match.range(at: 1), in: trimmed)!
        let minutesRange = Range(match.range(at: 2), in: trimmed)!
        var seconds = String(trimmed[Range(match.range(at: 3), in: trimmed)!])

        if seconds.count == 3 && seconds.hasSuffix("5") {
            seconds = String(seconds.prefix(2))
        }
        return "\(trimmed[hoursRange])h \(trimmed[minutesRange])m \(seconds)s"
    }
}

