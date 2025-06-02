import SwiftUI

// Provides access to `StatsDatabase` for persisting stats locally
struct StatsView: View {
    @Binding var photoData: PhotoData

    @State private var isAdded = false
    @State private var isEditing = false
    @State private var editPairs: [(String, String)] = []
    @ObservedObject private var db = StatsDatabase.shared

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }()

    private static let integerEfficiencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        formatter.roundingMode = .floor
        return formatter
    }()

    private static let decimalEfficiencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        formatter.roundingMode = .floor
        return formatter
    }()

    private static let durationFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        formatter.roundingMode = .floor
        return formatter
    }()

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
            var result: [(String, String)] = []
            if let date = model.photoDate {
                let formatted = StatsView.dateFormatter.string(from: date)
                result.append(("Photo Date", formatted))
            }
            result.append(contentsOf: [
                ("Game Time", model.gameTime),
                ("Real Time", model.realTime),
                (
                    "Duration",
                    (Self.durationFormatter.string(from: NSNumber(value: model.duration)) ?? "0") + "s"
                ),
                ("Tier", model.tier),
                ("Wave", model.wave),
                ("Killed By", model.killedBy),
                ("Coins Earned", model.coinsEarned),
                ("Coin Efficiency", Self.integerEfficiencyFormatter.string(from: NSNumber(value: model.coinEfficiency)) ?? "0"),
                ("Cash Earned", model.cashEarned),
                ("Interest Earned", model.interestEarned),
                ("Gem Blocks Tapped", model.gemBlocksTapped),
                ("Cells Earned", model.cellsEarned),
                ("Cell Efficiency", Self.decimalEfficiencyFormatter.string(from: NSNumber(value: model.cellEfficiency)) ?? "0.00"),
                ("Reroll Shards Earned", model.rerollShardsEarned),
                ("Shard Efficiency", Self.decimalEfficiencyFormatter.string(from: NSNumber(value: model.shardEfficiency)) ?? "0.00")
            ])
            return result
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
                                if pair.0.contains("Efficiency") {
                                    Text(pair.1)
                                        .foregroundColor(Color(red: 0.9, green: 0.72, blue: 0.0))
                                } else {
                                    Text(pair.1)
                                }
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
                    photoData.statsModel = StatsModel(pairs: pairs, photoDate: photoData.creationDate)
                }
                if photoData.statsModel == nil {
                    startEditing()
                }
            }
            checkIfAdded()
        }
        .onChange(of: photoData.statsModel) { _ in
            checkIfAdded()
        }
        .onReceive(db.$entries) { _ in
            checkIfAdded()
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
                    .buttonStyle(.borderedProminent)
                Button("Discard", role: .destructive) { isEditing = false }
                    .buttonStyle(.bordered)
            }
            .padding(.top, 8)
        }
    }

    private func startEditing() {
        if editPairs.isEmpty {
            if !displayPairs.isEmpty {
                let nonEditable = ["Photo Date", "Duration", "Coin Efficiency", "Cell Efficiency", "Shard Efficiency"]
                editPairs = displayPairs.filter { !nonEditable.contains($0.0) }
            } else {
                editPairs = parsedPairs
            }
        }
        isEditing = true
    }

    private func saveEdits() {
        // Automatically prefix cash and interest values with "$" if missing
        for index in editPairs.indices {
            let label = editPairs[index].0
            var value = editPairs[index].1.trimmingCharacters(in: .whitespaces)
            if (label == "Cash Earned" || label == "Interest Earned") &&
                !value.isEmpty && !value.hasPrefix("$") {
                value = "$" + value
            }
            editPairs[index].1 = value
        }

        let text = editPairs.map { "\($0.0)\n\($0.1)" }.joined(separator: "\n")
        photoData.ocrText = text
        photoData.statsModel = StatsModel(pairs: editPairs, photoDate: photoData.creationDate)
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

    private func checkIfAdded() {
        if let model = photoData.statsModel {
            isAdded = db.entries.contains(model)
        } else {
            isAdded = false
        }
    }
}

