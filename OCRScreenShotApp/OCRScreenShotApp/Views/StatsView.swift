import SwiftUI

// Provides access to `StatsDatabase` for persisting stats locally
struct StatsView: View {
    @Binding var photoData: PhotoData

    @State private var isAdded = false
    @State private var isEditing = false
    @State private var editPairs: [(String, String)] = []

    private var parsedPairs: [(String, String)] {
        if let text = photoData.ocrText,
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return OCRProcessor.shared.parsePairs(from: text)
        }
        return []
    }

    private var statsModel: StatsModel? {
        photoData.statsModel
    }

    private var displayPairs: [(String, String)] {
        if let model = statsModel {
            return [
                ("Game Time", model.gameTime),
                ("Real Time", model.realTime),
                ("Tier", model.tier),
                ("Wave", model.wave),
                ("Killed By", model.killedBy),
                ("Coins Earned", model.coinsEarned),
                ("Cash Earned", model.cashEarned),
                ("Interest Earned", model.interestEarned),
                ("Gem Blocks Tapped", model.gemBlocksTapped),
                ("Cells Earned", model.cellsEarned),
                ("Reroll Shards Earned", model.rerollShardsEarned)
            ]
        }
        return parsedPairs
    }
    var body: some View {
        ScrollView {
            if let image = photoData.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }

            VStack(alignment: .leading, spacing: 8) {

                if isEditing {
                    editingView
                } else if !displayPairs.isEmpty {
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                        ForEach(displayPairs.indices, id: \.self) { index in
                            let pair = displayPairs[index]
                            GridRow {
                                Text(pair.0)
                                Text(pair.1)
                            }
                            Divider().gridCellColumns(2)
                        }
                    }

                    HStack {
                        analysisButton
                        Button("Edit Stats") { startEditing() }
                            .padding(.leading)
                    }
                } else if let text = photoData.ocrText,
                          !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("\nRecognized Text:")
                        .font(.headline)
                    Text(text)
                        .font(.footnote)
                        .padding(.top, 2)
                    Button("Edit Stats") { startEditing() }
                        .padding(.top, 8)
                } else {
                    Text("Invalid image")
                        .font(.headline)
                        .padding(.top, 8)
                }
            }
            .padding()
        }
        .onAppear {
            if photoData.statsModel == nil,
               let text = photoData.ocrText,
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let pairs = OCRProcessor.shared.parsePairs(from: text)
                if !pairs.isEmpty {
                    photoData.statsModel = StatsModel(pairs: pairs)
                }
                if photoData.statsModel == nil {
                    startEditing()
                }
            }
        }
    }

    private var editingView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                ForEach(editPairs.indices, id: \.self) { index in
                    GridRow {
                        TextField("Label", text: $editPairs[index].0)
                        TextField("Value", text: $editPairs[index].1)
                    }
                    Divider().gridCellColumns(2)
                }
            }
            HStack {
                Button("Save") { saveEdits() }
                Button("Cancel") { isEditing = false }
            }
            .padding(.top, 8)
        }
    }

    private func startEditing() {
        if editPairs.isEmpty {
            editPairs = !displayPairs.isEmpty ? displayPairs : parsedPairs
        }
        isEditing = true
    }

    private func saveEdits() {
        let text = editPairs.map { "\($0.0)\n\($0.1)" }.joined(separator: "\n")
        photoData.ocrText = text
        photoData.statsModel = StatsModel(pairs: editPairs)
        editPairs.removeAll()
        isEditing = false
    }

    private var analysisButton: some View {
        Button(action: addToDatabase) {
            if isAdded {
                Text("Added \u{2705}")
            } else if statsModel?.hasParsingError == true {
                Text("Parsing error cannot add")
            } else {
                Text("Add to Analysis Database")
            }
        }
        .buttonStyle(.bordered)
        .disabled(isAdded || statsModel == nil || statsModel?.hasParsingError == true)
        .padding(.top, 8)
    }

    private func addToDatabase() {
        guard let stats = statsModel, !stats.hasParsingError else { return }
        StatsDatabase.shared.add(stats)
        isAdded = true
    }
}

