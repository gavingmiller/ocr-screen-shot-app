import Foundation

/// Model representing the parsed stats from a screenshot. Conforms to
/// ``Codable`` so entries can be persisted.
struct StatsModel: Codable, Equatable {
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
    /// Indicates at least one field failed validation when creating the model
    var hasParsingError: Bool = false

    /// The creation date of the screenshot this model was generated from
    var photoDate: Date? = nil

    // Computed values stored for analysis
    var duration: Double = 0
    var coinsValue: Double = 0
    var cellsValue: Double = 0
    var shardsValue: Double = 0
    var cellEfficiency: Double = 0
    var coinEfficiency: Double = 0
    var shardEfficiency: Double = 0

    init(pairs: [(String, String)], photoDate: Date? = nil) {
        let dict = Dictionary(uniqueKeysWithValues: pairs.map { ($0.0.lowercased(), $0.1) })
        var hadError = false

        self.photoDate = photoDate

        if let time = StatsModel.normalizeTime(dict["game time"] ?? "") {
            self.gameTime = time
        } else {
            self.gameTime = ""
            hadError = true
        }

        if let time = StatsModel.normalizeTime(dict["real time"] ?? "") {
            self.realTime = time
        } else {
            self.realTime = ""
            hadError = true
        }

        self.duration = StatsModel.timeToSeconds(self.realTime)

        if let value = StatsModel.validateRange(dict["tier"] ?? "", min: 1, max: 20) {
            self.tier = value
        } else {
            self.tier = ""
            hadError = true
        }

        if let value = StatsModel.validateRange(dict["wave"] ?? "", min: 1, max: 20000) {
            self.wave = value
        } else {
            self.wave = ""
            hadError = true
        }

        if let value = StatsModel.validateKilledBy(dict["killed by"] ?? "") {
            self.killedBy = value
        } else {
            self.killedBy = ""
            hadError = true
        }

        if let value = StatsModel.validateDigitsLetter(dict["coins earned"] ?? "", prefixDollar: false) {
            self.coinsEarned = value
        } else {
            self.coinsEarned = ""
            hadError = true
        }

        self.coinsValue = StatsModel.parseAbbreviatedNumber(self.coinsEarned)

        if let value = StatsModel.validateDigitsLetter(dict["cash earned"] ?? "", prefixDollar: true) {
            self.cashEarned = value
        } else {
            self.cashEarned = ""
            hadError = true
        }

        if let value = StatsModel.validateDigitsLetter(dict["interest earned"] ?? "", prefixDollar: true) {
            self.interestEarned = value
        } else {
            self.interestEarned = ""
            hadError = true
        }

        if let value = StatsModel.validateDigits(dict["gem blocks tapped"] ?? "") {
            self.gemBlocksTapped = value
        } else {
            self.gemBlocksTapped = ""
            hadError = true
        }

        if let value = StatsModel.validateDigitsLetter(dict["cells earned"] ?? "", prefixDollar: false) {
            self.cellsEarned = value
        } else {
            self.cellsEarned = ""
            hadError = true
        }

        self.cellsValue = StatsModel.parseAbbreviatedNumber(self.cellsEarned)

        if let value = StatsModel.validateDigitsLetter(dict["reroll shards earned"] ?? "", prefixDollar: false) {
            self.rerollShardsEarned = value
        } else {
            self.rerollShardsEarned = ""
            hadError = true
        }

        self.shardsValue = StatsModel.parseAbbreviatedNumber(self.rerollShardsEarned)

        if self.duration > 0 {
            self.cellEfficiency = self.cellsValue / self.duration
            self.coinEfficiency = self.coinsValue / self.duration
            self.shardEfficiency = self.shardsValue / self.duration
        } else {
            self.cellEfficiency = 0
            self.coinEfficiency = 0
            self.shardEfficiency = 0
        }

        self.hasParsingError = hadError
    }

    private static func normalizeTime(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        let pattern = "^(?:([0-9]+)d\\s*)?([0-9]+)h\\s*([0-9]+)m\\s*([0-9]{1,3})(?:s)?$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: trimmed.utf16.count)) else {
            return nil
        }

        let dayRange = match.range(at: 1)
        let hasDays = dayRange.location != NSNotFound && dayRange.length > 0
        let day = hasDays ? String(trimmed[Range(dayRange, in: trimmed)!]) : nil
        let hours = String(trimmed[Range(match.range(at: 2), in: trimmed)!])
        let minutes = String(trimmed[Range(match.range(at: 3), in: trimmed)!])
        var seconds = String(trimmed[Range(match.range(at: 4), in: trimmed)!])

        if seconds.count == 3 && seconds.hasSuffix("5") {
            seconds = String(seconds.prefix(2))
        }

        if let day = day {
            return "\(day)d \(hours)h \(minutes)m \(seconds)s"
        } else {
            return "\(hours)h \(minutes)m \(seconds)s"
        }
    }

    private static func validateRange(_ value: String, min: Int, max: Int) -> String? {
        guard let intVal = Int(value.trimmingCharacters(in: .whitespaces)), intVal >= min, intVal <= max else {
            return nil
        }
        return String(intVal)
    }

    private static func validateKilledBy(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        if trimmed.rangeOfCharacter(from: CharacterSet.decimalDigits) != nil { return nil }
        if trimmed.contains(".") { return nil }
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func validateDigitsLetter(_ value: String, prefixDollar: Bool) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        let prefix = prefixDollar ? "\\$" : ""
        let pattern = "^" + prefix + "[0-9]+(?:\\.[0-9]+)?[A-Za-z]$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(location: 0, length: trimmed.utf16.count)
        guard regex.firstMatch(in: trimmed, options: [], range: range) != nil else { return nil }
        return trimmed
    }

    private static func validateDigits(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        let pattern = "^[0-9]+$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              regex.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: trimmed.utf16.count)) != nil else {
            return nil
        }
        return trimmed
    }

    // MARK: - Value Conversion Helpers

    static func timeToSeconds(_ time: String) -> Double {
        let trimmed = time.trimmingCharacters(in: .whitespaces)
        let pattern = "^(?:([0-9]+)d\\s*)?([0-9]+)h\\s*([0-9]+)m\\s*([0-9]+)s$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: trimmed.utf16.count)) else {
            return 0
        }

        let dayRange = match.range(at: 1)
        let hasDays = dayRange.location != NSNotFound && dayRange.length > 0
        let days = hasDays ? Double(String(trimmed[Range(dayRange, in: trimmed)!])) ?? 0 : 0
        let hours = Double(String(trimmed[Range(match.range(at: 2), in: trimmed)!])) ?? 0
        let minutes = Double(String(trimmed[Range(match.range(at: 3), in: trimmed)!])) ?? 0
        let seconds = Double(String(trimmed[Range(match.range(at: 4), in: trimmed)!])) ?? 0

        return days * 24 * 3600 + hours * 3600 + minutes * 60 + seconds
    }

    private static let multipliers: [Character: Double] = [
        "k": 1_000,
        "m": 1_000_000,
        "b": 1_000_000_000,
        "t": 1_000_000_000_000,
        "q": 1_000_000_000_000_000
    ]

    static func parseAbbreviatedNumber(_ value: String) -> Double {
        let cleaned = value.replacingOccurrences(of: "$", with: "").lowercased()
        guard let suffix = cleaned.last,
              let multiplier = multipliers[suffix] else { return 0 }
        let numberPart = cleaned.dropLast()
        return (Double(String(numberPart)) ?? 0) * multiplier
    }

    func coins() -> Double { coinsValue }
    func cells() -> Double { cellsValue }
    func shards() -> Double { shardsValue }

    /// Determine if two stats entries represent the same screenshot based on
    /// a subset of fields used for duplicate detection.
    func isDuplicate(of other: StatsModel) -> Bool {
        return self.photoDate == other.photoDate &&
            self.wave == other.wave &&
            self.tier == other.tier &&
            self.duration == other.duration &&
            self.coinsEarned == other.coinsEarned &&
            self.rerollShardsEarned == other.rerollShardsEarned
    }
}

