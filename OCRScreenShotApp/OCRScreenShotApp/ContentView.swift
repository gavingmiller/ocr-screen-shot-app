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

    /// Analyze stored stats and determine the best tiers along with a
    /// recommended tier to refresh if data is stale.
    private var tierAnalysis: (coins: String, cells: String, shards: String, refresh: String?)? {
        let models = photoItems.compactMap { $0.statsModel }
        guard !models.isEmpty else { return nil }

        struct TierInfo {
            var tier: Int
            var avg: Double
            var isStale: Bool
        }

        func tierInfo(for keyPath: KeyPath<StatsModel, Double>) -> TierInfo? {
            let groups = Dictionary(grouping: models, by: { Int($0.tier) ?? 0 })
            let cutoff = Date().addingTimeInterval(-14 * 24 * 3600)
            var result: TierInfo?
            for (tier, items) in groups where tier > 0 {
                let avg = items.reduce(0.0) { $0 + $1[keyPath: keyPath] } / Double(items.count)
                let latest = items.compactMap { $0.photoDate }.max() ?? .distantPast
                let stale = latest < cutoff
                if result == nil || avg > result!.avg {
                    result = TierInfo(tier: tier, avg: avg, isStale: stale)
                }
            }
            return result
        }

        func freshTier(for keyPath: KeyPath<StatsModel, Double>) -> Int? {
            let groups = Dictionary(grouping: models, by: { Int($0.tier) ?? 0 })
            let cutoff = Date().addingTimeInterval(-14 * 24 * 3600)
            var best: (tier: Int, avg: Double)?
            for (tier, items) in groups where tier > 0 {
                let latest = items.compactMap { $0.photoDate }.max() ?? .distantPast
                guard latest >= cutoff else { continue }
                let avg = items.reduce(0.0) { $0 + $1[keyPath: keyPath] } / Double(items.count)
                if best == nil || avg > best!.avg {
                    best = (tier, avg)
                }
            }
            return best?.tier
        }

        func bestString(for keyPath: KeyPath<StatsModel, Double>) -> (String, Int?) {
            guard let info = tierInfo(for: keyPath) else { return ("N/A", nil) }
            let fresh = freshTier(for: keyPath)
            var refresh: Int? = nil
            if info.isStale {
                refresh = info.tier
            } else if let fresh = fresh, abs(fresh - info.tier) <= 3, fresh != info.tier {
                refresh = fresh
            }
            let value = info.isStale ? "\(info.tier)*" : "\(info.tier)"
            return (value, refresh)
        }

        let coinInfo = bestString(for: \StatsModel.coinEfficiency)
        let cellInfo = bestString(for: \StatsModel.cellEfficiency)
        let shardInfo = bestString(for: \StatsModel.shardEfficiency)

        var refreshTier: String?
        if let r = coinInfo.1 { refreshTier = String(r) }
        if let r = cellInfo.1 { refreshTier = refreshTier ?? String(r) }
        if let r = shardInfo.1 { refreshTier = refreshTier ?? String(r) }

        return (
            coins: coinInfo.0,
            cells: cellInfo.0,
            shards: shardInfo.0,
            refresh: refreshTier
        )
    }

    private var analysisView: some View {
        let coins = (tierAnalysis?.coins).flatMap { $0.isEmpty ? nil : $0 } ?? "N/A"
        let cells = (tierAnalysis?.cells).flatMap { $0.isEmpty ? nil : $0 } ?? "N/A"
        let shards = (tierAnalysis?.shards).flatMap { $0.isEmpty ? nil : $0 } ?? "N/A"
        let refresh = tierAnalysis?.refresh ?? "N/A"

        return HStack(spacing: 8) {
            tierBox(label: "Best Coins", value: coins)
            tierBox(label: "Best Cells", value: cells)
            tierBox(label: "Best Reroll", value: shards)
            tierBox(label: "Refresh", value: refresh)
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
        .onAppear {
            photoItems = PhotoPersistence.shared.load()
        }
        .onChange(of: photoItems) { newValue in
            PhotoPersistence.shared.save(newValue)
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
                    gridItem(for: $photoItems[index], index: index, indices: indices)
                }
            }
        }
    }

    @ViewBuilder
    private func gridItem(for item: Binding<PhotoData>, index: Int, indices: [Int]) -> some View {
        if !item.wrappedValue.isProcessing, let image = item.wrappedValue.image {
            NavigationLink(destination: StatsView(photoItems: $photoItems, indices: indices, startIndex: indices.firstIndex(of: index) ?? 0, onParseSuccess: {
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

                    if item.wrappedValue.isDuplicate {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.yellow)
                            .padding(4)
                    } else if item.wrappedValue.isAdded {
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

                            if !model.hasParsingError {
                                let added = StatsDatabase.shared.add(model)
                                photoItems[index].isAdded = added
                                photoItems[index].isDuplicate = !added && StatsDatabase.shared.isDuplicate(model)
                            }
                            PhotoPersistence.shared.save(photoItems)
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
            PhotoPersistence.shared.save(photoItems)
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
        var seen = Set<String>()
        return photoItems.indices.compactMap { index in
            let item = photoItems[index]
            guard !item.isProcessing else { return nil }

            if let model = item.statsModel {
                // Filter by selected tab
                switch selectedTab {
                case .analyzed:
                    guard model.hasParsingError == false else { return nil }
                case .errors:
                    guard model.hasParsingError == true else { return nil }
                }

                // Mark duplicates but continue displaying them so the user
                // can review screenshots even if they already exist in the
                // database or match another selected image.
                let key = "\(model.photoDate?.timeIntervalSince1970 ?? 0)-\(model.wave)-\(model.tier)-\(model.duration)-\(model.coinsEarned)-\(model.rerollShardsEarned)"
                if !item.isAdded && StatsDatabase.shared.isDuplicate(model) {
                    photoItems[index].isDuplicate = true
                } else if seen.contains(key) {
                    photoItems[index].isDuplicate = true
                }
                seen.insert(key)

                return index
            } else {
                // Show unprocessed images only on the analyzed tab
                guard selectedTab == .analyzed else { return nil }
                return index
            }
        }
    }

}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
