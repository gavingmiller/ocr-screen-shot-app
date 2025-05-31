import SwiftUI

struct StatsView: View {
    @Binding var photoData: PhotoData

    private var fields: OCRResultFields {
        if let text = photoData.ocrText {
            return OCRProcessor.shared.extractFields(from: text)
        }
        return OCRResultFields()
    }

    private var parsedPairs: [(String, String)] {
        if let text = photoData.ocrText {
            return OCRProcessor.shared.parsePairs(from: text)
        }
        return []
    }

    private var statusText: String {
        switch photoData.postStatus {
        case .none:
            return "Pending"
        case .success:
            return "Uploaded"
        case .failure:
            return "Failed"
        }
    }

    var body: some View {
        ScrollView {
            if let image = photoData.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Status: \(statusText)")
                    .font(.headline)

                if !fields.tier.isEmpty { Text("Tier: \(fields.tier)") }
                if !fields.wave.isEmpty { Text("Wave: \(fields.wave)") }
                if !fields.realTime.isEmpty { Text("Real Time: \(fields.realTime)") }
                if !fields.coins.isEmpty { Text("Coins: \(fields.coins)") }
                if !fields.cells.isEmpty { Text("Cells: \(fields.cells)") }
                if !fields.shards.isEmpty { Text("Shards: \(fields.shards)") }

                if !parsedPairs.isEmpty {
                    Text("\nStats:")
                        .font(.headline)
                    ForEach(parsedPairs.indices, id: \.self) { index in
                        let pair = parsedPairs[index]
                        Text("\(pair.0): \(pair.1)")
                    }
                } else if let text = photoData.ocrText {
                    Text("\nRecognized Text:")
                        .font(.headline)
                    Text(text)
                        .font(.footnote)
                        .padding(.top, 2)
                }
            }
            .padding()
        }
        .navigationTitle("Stats")
    }
}

