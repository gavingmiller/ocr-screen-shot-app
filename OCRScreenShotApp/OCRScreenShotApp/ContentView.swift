import SwiftUI
import PhotosUI
import UIKit

struct ContentView: View {
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var photoItems: [PhotoData] = []
    @StateObject private var authManager = GoogleAuthManager.shared

    private var tierAnalysis: (coins: String, cells: String, shards: String)? {
        let models = photoItems.compactMap { $0.statsModel }
        guard !models.isEmpty else { return nil }

        func intValue(_ value: String) -> Int {
            return Int(value.filter { $0.isNumber }) ?? 0
        }

        func bestTier(for keyPath: KeyPath<StatsModel, String>) -> String {
            let groups = Dictionary(grouping: models, by: { $0.tier })
            var bestTier = ""
            var best = 0
            for (tier, items) in groups {
                let total = items.reduce(0) { $0 + intValue($1[keyPath: keyPath]) }
                if total > best {
                    best = total
                    bestTier = tier
                }
            }
            return bestTier
        }

        return (
            coins: bestTier(for: \StatsModel.coinsEarned),
            cells: bestTier(for: \StatsModel.cellsEarned),
            shards: bestTier(for: \StatsModel.rerollShardsEarned)
        )
    }

    @ViewBuilder
    private var analysisView: some View {
        if let analysis = tierAnalysis {
            VStack(spacing: 4) {
                Text("Tier Effectiveness")
                    .font(.headline)
                HStack {
                    Text("Coins: \(analysis.coins)")
                    Spacer()
                    Text("Cells: \(analysis.cells)")
                    Spacer()
                    Text("Reroll: \(analysis.shards)")
                }
                .font(.subheadline)
            }
            .padding(.bottom)
        }
    }

    var body: some View {
        NavigationView {
            VStack {
                if !authManager.isSignedIn {
                    signInButton
                }
                if photoItems.isEmpty {
                    Spacer()
                    PhotosPicker(
                        selection: $selectedItems,
                        maxSelectionCount: nil,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Text("Select Image from Library")
                            .padding()
                    }
                    .onChange(of: selectedItems) { _ in
                        handleResults(selectedItems)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        let columns = [GridItem(.adaptive(minimum: 100), spacing: 2)]
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach($photoItems) { $item in
                                if let image = item.image {
                                    NavigationLink(destination: StatsView(photoData: $item)) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(minWidth: 100, minHeight: 100)
                                            .clipped()
                                    }
                                }
                            }
                        }

                        PhotosPicker(
                            selection: $selectedItems,
                            maxSelectionCount: nil,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            Text("Add Photos")
                        }
                        .onChange(of: selectedItems) { _ in
                            handleResults(selectedItems)
                        }
                        .padding()

                        analysisView
                    }
                }
            }
            .navigationTitle("OCR Screen Shot")
        }
    }

    private var signInButton: some View {
        Button("Sign in with Google", action: signIn)
            .buttonStyle(.borderedProminent)
    }

    private func signIn() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return }
        authManager.signIn(presenting: root)
    }

    private func handleResults(_ items: [PhotosPickerItem]) {
        Task {
            for item in items {
                var data = PhotoData(item: item)
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
                            photoItems[index].statsModel = StatsModel(pairs: pairs)
                        }
                    }
                } else {
                    await MainActor.run {
                        photoItems[index].postStatus = .failure
                    }
                }
            }
            await MainActor.run {
                selectedItems.removeAll()
            }
        }
    }

}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
