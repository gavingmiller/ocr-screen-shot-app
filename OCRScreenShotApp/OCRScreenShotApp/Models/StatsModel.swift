import Foundation

struct StatsModel {
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

    init(pairs: [(String, String)]) {
        let dict = Dictionary(uniqueKeysWithValues: pairs.map { ($0.0.lowercased(), $0.1) })
        var hadError = false

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

        if let value = StatsModel.validateDigitsLetter(dict["reroll shards earned"] ?? "", prefixDollar: false) {
            self.rerollShardsEarned = value
        } else {
            self.rerollShardsEarned = ""
            hadError = true
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
}

