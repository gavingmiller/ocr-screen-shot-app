import UIKit
import Vision
import Foundation

struct OCRResultFields {
    var tier: String = ""
    var wave: String = ""
    var realTime: String = ""
    var coins: String = ""
    var cells: String = ""
    var shards: String = ""
}

/// Represents a unique label/value pair parsed from the OCR text.
struct LabelValuePair: Hashable {
    let label: String
    let value: String
}

class OCRProcessor {
    static let shared = OCRProcessor()

    func recognizeText(in image: UIImage, completion: @escaping (String) -> Void) {
        guard let cgImage = image.cgImage else {
            completion("")
            return
        }

        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { request, error in
            guard error == nil else {
                completion("")
                return
            }
            let text = request.results?
                .compactMap { ($0 as? VNRecognizedTextObservation)?.topCandidates(1).first?.string }
                .joined(separator: "\n") ?? ""
            completion(text)
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try requestHandler.perform([request])
            } catch {
                completion("")
            }
        }
    }

    func extractFields(from text: String) -> OCRResultFields {
        func match(for label: String) -> String {
            // Values like "0h 0m 0s" can appear for the time fields. The
            // previous regex only captured digits and colons which caused the
            // letters to be dropped resulting in an invalid time string. This
            // regex includes the possible "d", "h", "m" and "s" units along with
            // digits, colons and whitespace so the full value is captured.
            let pattern = "\(label)\\s*([0-9dhms:\\s]+)"
            if let range = text.range(of: pattern, options: .regularExpression) {
                return String(text[range])
                    .replacingOccurrences(of: label, with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
            return ""
        }

        var result = OCRResultFields()
        result.tier = match(for: "tier")
        result.wave = match(for: "wave")
        result.realTime = match(for: "real time")
        result.coins = match(for: "coins earned")
        result.cells = match(for: "cells earned")
        result.shards = match(for: "reroll shards earned")
        return result
    }

    /// Remove the text section that starts with "Combat" and continues until
    /// the last line before a line containing any digits.
    private func removeCombatSection(from text: String) -> String {
        var lines = text.components(separatedBy: .newlines)
        guard let startIndex = lines.firstIndex(where: { $0.range(of: "combat", options: .caseInsensitive) != nil }) else {
            return text
        }

        var endIndex = startIndex
        for i in (startIndex + 1)..<lines.count {
            if lines[i].rangeOfCharacter(from: .decimalDigits) != nil {
                break
            }
            endIndex = i
        }

        lines.removeSubrange(startIndex...endIndex)
        return lines.joined(separator: "\n")
    }

    /// Parse generic key/value pairs from OCR'd text where each line contains a
    /// label on the left and a value on the right separated by whitespace.
    func parsePairs(from text: String) -> [(label: String, value: String)] {
        var results: [(String, String)] = []
        var seenLabels = Set<String>()

        // Remove any text before "Battle Report" to avoid extraneous lines
        let trimmedText: String
        if let range = text.range(of: "battle report", options: .caseInsensitive) {
            trimmedText = String(text[range.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            trimmedText = text
        }

        let cleanedText = removeCombatSection(from: trimmedText)
        let lines = cleanedText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        let numberOfFields = 11
        
        for i in 0..<numberOfFields {
            let label = lines[i]
            let value = lines[i + numberOfFields]
            guard !seenLabels.contains(label) else { continue }
            seenLabels.insert(label)
            results.append((label, value))
        }
        // Only include the first 11 unique label/value pairs
        return results
    }
}
