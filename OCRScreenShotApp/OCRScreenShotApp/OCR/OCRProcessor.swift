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
            if let range = text.range(of: "\(label)\\s*([0-9:]+)", options: .regularExpression) {
                return String(text[range]).replacingOccurrences(of: label, with: "").trimmingCharacters(in: .whitespaces)
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

    /// Parse generic key/value pairs from OCR'd text where each line contains a
    /// label on the left and a value on the right separated by whitespace.
    func parsePairs(from text: String) -> [(label: String, value: String)] {
        let regex = try? NSRegularExpression(
            pattern: "^(.+?)\\s+([0-9][0-9.,]*[A-Za-z]*)$",
            options: [.anchorsMatchLines]
        )
        var results: [(String, String)] = []

        // Remove any text before "Battle Report" to avoid extraneous lines
        let trimmedText: String
        if let range = text.range(of: "battle report", options: .caseInsensitive) {
            trimmedText = String(text[range.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            trimmedText = text
        }

        trimmedText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .forEach { line in
                guard !line.isEmpty else { return }
                if let regex = regex,
                   let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..<line.endIndex, in: line)),
                   match.numberOfRanges == 3,
                   let labelRange = Range(match.range(at: 1), in: line),
                   let valueRange = Range(match.range(at: 2), in: line) {
                    let label = String(line[labelRange])
                    let value = String(line[valueRange])
                    results.append((label, value))
                } else if let range = line.range(of: "\\s+(\\S+)$", options: .regularExpression) {
                    let label = String(line[..<range.lowerBound])
                    let value = String(line[range.upperBound...])
                    results.append((label, value))
                }
            }

        return results
    }
}
