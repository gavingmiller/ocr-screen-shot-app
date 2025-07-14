import SwiftUI

// Provides access to `StatsDatabase` for persisting stats locally
struct StatsView: View {
    @Binding var photoItems: [PhotoData]
    let indices: [Int]
    @State private var currentIndex: Int
    var onParseSuccess: (() -> Void)? = nil

    @State private var isAdded = false
    @State private var isDuplicate = false
    @State private var isEditing = false
    @State private var editPairs: [(String, String)] = []
    @ObservedObject private var db = StatsDatabase.shared
    @Environment(\.dismiss) private var dismiss
    init(photoItems: Binding<[PhotoData]>, indices: [Int], startIndex: Int, onParseSuccess: (() -> Void)? = nil) {
        self._photoItems = photoItems
        self.indices = indices
        self._currentIndex = State(initialValue: startIndex)
        self.onParseSuccess = onParseSuccess
    }

    private var photoData: Binding<PhotoData> {
        Binding(get: { photoItems[indices[currentIndex]] },
                set: { photoItems[indices[currentIndex]] = $0 })
    }

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
        if let text = photoData.wrappedValue.ocrText,
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return OCRProcessor.shared.parsePairs(from: text)
        }
        return []
    }

    private var statsModel: StatsModel? {
        photoData.wrappedValue.statsModel
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
            if let image = photoData.wrappedValue.image {
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
                        if !isAdded && !isDuplicate {
                            Button("Edit Stats") { startEditing() }
                                .padding(.leading)
                        }
                        Spacer()
                        Button(action: deleteCurrent) {
                            Text("Delete")
                                .foregroundColor(.red)
                        }
                    }
                } else if let text = photoData.wrappedValue.ocrText,
                          !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("\nRecognized Text:")
                        .font(.headline)
                    Text(text)
                        .font(.footnote)
                        .padding(.top, 2)
                    if !isAdded && !isDuplicate {
                        Button("Edit Stats") { startEditing() }
                            .padding(.top, 8)
                    }
                } else {
                    Text("Invalid image")
                        .font(.headline)
                        .padding(.top, 8)
                }
            }
            .padding()
        }
        .onAppear {
            if photoData.wrappedValue.statsModel == nil,
               let text = photoData.wrappedValue.ocrText,
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let pairs = OCRProcessor.shared.parsePairs(from: text)
                if !pairs.isEmpty {
                    photoData.wrappedValue.statsModel = StatsModel(pairs: pairs, photoDate: photoData.wrappedValue.creationDate)
                }
                checkIfAdded()
                if photoData.wrappedValue.statsModel == nil && !isDuplicate {
                    startEditing()
                }
            } else {
                checkIfAdded()
                if photoData.wrappedValue.statsModel?.hasParsingError == true && !isDuplicate {
                    startEditing()
                }
            }
        }
        .onChange(of: photoData.wrappedValue.statsModel) { _ in
            checkIfAdded()
        }
        .onReceive(db.$entries) { _ in
            checkIfAdded()
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: previousItem) {
                    Image(systemName: "chevron.left")
                }
                .disabled(currentIndex == 0)
                Button(action: nextItem) {
                    Image(systemName: "chevron.right")
                }
                .disabled(currentIndex >= indices.count - 1)
            }
        }
    }

    private var editingView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                ForEach(editPairs.indices, id: \.self) { index in
                    GridRow {
                        Text(editPairs[index].0)
                        TextField("Value", text: $editPairs[index].1)
                    }
                    Divider().gridCellColumns(2)
                }
            }
            HStack {
                Button("Save") { saveEdits() }
                    .buttonStyle(.borderedProminent)
                Spacer()
                Button("Discard", role: .destructive) {
                    if statsModel == nil || statsModel?.hasParsingError == true {
                        deleteCurrent()
                    } else {
                        isEditing = false
                    }
                }
                    .buttonStyle(.bordered)
            }
            .padding(.top, 8)
        }
    }

    private func startEditing() {
        guard !isDuplicate else { return }
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
        photoData.wrappedValue.ocrText = text
        photoData.wrappedValue.statsModel = StatsModel(pairs: editPairs, photoDate: photoData.wrappedValue.creationDate)
        editPairs.removeAll()
        isEditing = false
        if let stats = photoData.wrappedValue.statsModel, stats.hasParsingError == false {
            let added = StatsDatabase.shared.add(stats)
            if added {
                isAdded = true
                photoData.wrappedValue.isAdded = true
            } else if StatsDatabase.shared.isDuplicate(stats) {
                isDuplicate = true
                photoData.wrappedValue.isDuplicate = true
            }
            onParseSuccess?()
            PhotoPersistence.shared.save(photoItems)
        }
    }

    private var analysisButton: some View {
        Button(action: addToDatabase) {
            if isDuplicate {
                Text("Duplicate \u{1F501}")
            } else if isAdded {
                Text("Added \u{2705}")
            } else if statsModel?.hasParsingError == true {
                Text("Parsing error cannot add")
            } else {
                Text("Add to Analysis Database")
            }
        }
        .buttonStyle(.bordered)
        .disabled(isAdded || isDuplicate || statsModel == nil || statsModel?.hasParsingError == true)
        .padding(.top, 8)
    }
    private func previousItem() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        isEditing = false
        editPairs.removeAll()
        checkIfAdded()
    }

    private func nextItem() {
        guard currentIndex < indices.count - 1 else { return }
        currentIndex += 1
        isEditing = false
        editPairs.removeAll()
        checkIfAdded()
    }

    private func deleteCurrent() {
        if let model = photoData.wrappedValue.statsModel {
            StatsDatabase.shared.remove(model)
        }
        let index = indices[currentIndex]
        dismiss()
        DispatchQueue.main.async {
            if photoItems.indices.contains(index) {
                photoItems.remove(at: index)
            }
            PhotoPersistence.shared.save(photoItems)
        }
    }

    private func addToDatabase() {
        guard let stats = statsModel, !stats.hasParsingError else { return }
        let added = StatsDatabase.shared.add(stats)
        if added {
            isAdded = true
            photoData.wrappedValue.isAdded = true
        } else if StatsDatabase.shared.isDuplicate(stats) {
            isDuplicate = true
            photoData.wrappedValue.isDuplicate = true
        }
        PhotoPersistence.shared.save(photoItems)
    }

    private func checkIfAdded() {
        guard currentIndex < indices.count else { return }
        let index = indices[currentIndex]
        guard photoItems.indices.contains(index) else { return }

        if let model = photoItems[index].statsModel {
            let added = db.entries.contains(model)
            let duplicate = db.isDuplicate(model) && !added
            isAdded = added
            isDuplicate = duplicate
            photoItems[index].isAdded = added
            photoItems[index].isDuplicate = duplicate
        } else {
            isAdded = false
            isDuplicate = false
            photoItems[index].isAdded = false
            photoItems[index].isDuplicate = false
        }
    }
}

