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

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                    GridRow {
                        Text("Field").bold()
                        Text("Value").bold()
                    }
                    Divider().gridCellColumns(2)

                    if !fields.tier.isEmpty {
                        GridRow { Text("Tier") ; Text(fields.tier) }
                        Divider().gridCellColumns(2)
                    }
                    if !fields.wave.isEmpty {
                        GridRow { Text("Wave") ; Text(fields.wave) }
                        Divider().gridCellColumns(2)
                    }
                    if !fields.realTime.isEmpty {
                        GridRow { Text("Real Time") ; Text(fields.realTime) }
                        Divider().gridCellColumns(2)
                    }
                    if !fields.coins.isEmpty {
                        GridRow { Text("Coins") ; Text(fields.coins) }
                        Divider().gridCellColumns(2)
                    }
                    if !fields.cells.isEmpty {
                        GridRow { Text("Cells") ; Text(fields.cells) }
                        Divider().gridCellColumns(2)
                    }
                    if !fields.shards.isEmpty {
                        GridRow { Text("Shards") ; Text(fields.shards) }
                        Divider().gridCellColumns(2)
                    }
                }

                if !parsedPairs.isEmpty {
                    Text("Stats:")
                        .font(.headline)
                        .padding(.top, 8)
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                        GridRow {
                            Text("Label").bold()
                            Text("Value").bold()
                        }
                        Divider().gridCellColumns(2)

                        ForEach(parsedPairs.indices, id: \.self) { index in
                            let pair = parsedPairs[index]
                            GridRow {
                                Text(pair.0)
                                Text(pair.1)
                            }
                            Divider().gridCellColumns(2)
                        }
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

