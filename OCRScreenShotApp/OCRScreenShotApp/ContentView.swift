import SwiftUI
import PhotosUI
import UIKit

struct ContentView: View {
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var photoItems: [PhotoData] = []
    @State private var selectedTab: Tab = .analyzed

    private var errorCount: Int {
        photoItems.filter { $0.statsModel?.hasParsingError == true }.count
    }

    private enum Tab: Int, CaseIterable {
        case analyzed
        case errors

        var title: String {
            switch self {
            case .analyzed: return "Analyzed"
            case .errors: return "Errors"
            }
        }
    }

    private var tierAnalysis: (coins: String, cells: String, shards: String)? {
        let models = photoItems.compactMap { $0.statsModel }
        guard !models.isEmpty else { return nil }

        func bestTier(for keyPath: KeyPath<StatsModel, Double>) -> String {
            let groups = Dictionary(grouping: models, by: { $0.tier })
            var bestTier = ""
            var bestAverage = 0.0
            for (tier, items) in groups {
                let sum = items.reduce(0.0) { $0 + $1[keyPath: keyPath] }
                let average = sum / Double(items.count)
                if average > bestAverage {
                    bestAverage = average
                    bestTier = tier
                }
            }
            return bestTier
        }

        return (
            coins: bestTier(for: \StatsModel.coinEfficiency),
            cells: bestTier(for: \StatsModel.cellEfficiency),
            shards: bestTier(for: \StatsModel.shardEfficiency)
        )
    }

    private var analysisView: some View {
        let coins = (tierAnalysis?.coins).flatMap { $0.isEmpty ? nil : $0 } ?? "N/A"
        let cells = (tierAnalysis?.cells).flatMap { $0.isEmpty ? nil : $0 } ?? "N/A"
        let shards = (tierAnalysis?.shards).flatMap { $0.isEmpty ? nil : $0 } ?? "N/A"

        return HStack(spacing: 8) {
            tierBox(label: "Best Coins Tier", value: coins)
            tierBox(label: "Best Cells Tier", value: cells)
            tierBox(label: "Best Reroll Tier", value: shards)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color.black)
                .frame(height: 1),
            alignment: .top
        )
    }

    var body: some View {
        NavigationView {
            mainContent
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Tower Analysis")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        addButton
                    }
                }
        }
        .onChange(of: selectedItems) { _ in
            handleResults(selectedItems)
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            tabsPicker
            Spacer().frame(height: 5)
            if photoItems.isEmpty {
                Spacer()
                photosPickerView
                Spacer()
            } else {
                photosGridView
            }
            analysisView
        }
    }

    private var tabsPicker: some View {
        Picker("Tabs", selection: $selectedTab) {
            ForEach(Tab.allCases, id: \.self) { tab in
                if tab == .errors && errorCount > 0 {
                    Text("\(tab.title) (\(errorCount))").tag(tab)
                } else {
                    Text(tab.title).tag(tab)
                }
            }
        }
        .pickerStyle(.segmented)
        .padding([.top, .horizontal])
    }

    private var photosPickerView: some View {
        PhotosPicker(
            selection: $selectedItems,
            maxSelectionCount: nil,
            matching: .images,
            photoLibrary: .shared()
        ) {
            Text("Select Image from Library")
                .padding()
        }
    }

    private var photosGridView: some View {
        ScrollView {
            let columns = [GridItem(.adaptive(minimum: 100), spacing: 2)]
            let indices = filteredIndices()
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(indices, id: \.self) { index in
                    gridItem(for: $photoItems[index])
                }
            }
        }
    }

    @ViewBuilder
    private func gridItem(for item: Binding<PhotoData>) -> some View {
        if !item.wrappedValue.isProcessing, let image = item.wrappedValue.image {
            NavigationLink(destination: StatsView(photoData: item, onParseSuccess: {
                if errorCount == 0 {
                    selectedTab = .analyzed
                }
            })) {
                ZStack(alignment: .bottomTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(minWidth: 100, minHeight: 100)
                        .clipped()

                    if item.wrappedValue.isAdded {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .padding(4)
                    }
                }
            }
        }
    }

    private var addButton: some View {
        PhotosPicker(
            selection: $selectedItems,
            maxSelectionCount: nil,
            matching: .images,
            photoLibrary: .shared()
        ) {
            Image(systemName: "plus")
        }
    }

    private func handleResults(_ items: [PhotosPickerItem]) {
        Task {
            for item in items {
                var data = PhotoData(item: item)
                data.isProcessing = true
                let success = await data.loadImage()

                // Append the data and capture its index so subsequent updates
                // modify the value stored in the array instead of the local
                // copy.
                let index = await MainActor.run { () -> Int in
                    photoItems.append(data)
                    return photoItems.count - 1
                }

                if success {
                    OCRProcessor.shared.recognizeText(in: data.image!) { text in
                        DispatchQueue.main.async {
                            photoItems[index].ocrText = text
                            let pairs = OCRProcessor.shared.parsePairs(from: text)
                            let model = StatsModel(pairs: pairs, photoDate: photoItems[index].creationDate)
                            photoItems[index].statsModel = model
                            photoItems[index].isProcessing = false
                            photoItems[index].isAdded = StatsDatabase.shared.entries.contains(model)
                        }
                    }
                } else {
                    await MainActor.run {
                        photoItems[index].isProcessing = false
                    }
                }
            }
            await MainActor.run {
                selectedItems.removeAll()
            }
        }
    }

    private func tierBox(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption)
            Text(value)
                .font(.title3)
                .bold()
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary, lineWidth: 1)
        )
    }

    private func filteredIndices() -> [Int] {
        photoItems.indices.filter { index in
            let item = photoItems[index]
            guard !item.isProcessing else { return false }
            switch selectedTab {
            case .analyzed:
                return item.statsModel?.hasParsingError != true
            case .errors:
                return item.statsModel?.hasParsingError == true
            }
        }
    }

}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
