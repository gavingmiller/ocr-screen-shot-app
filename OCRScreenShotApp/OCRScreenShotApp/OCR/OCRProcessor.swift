import UIKit
import Vision

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
            if let range = text.range(of: "\(label\)\s*([0-9:]+)", options: .regularExpression) {
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
}
