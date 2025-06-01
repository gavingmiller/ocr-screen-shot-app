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
            HStack(spacing: 8) {
                tierBox(label: "Best Coins Tier", value: analysis.coins)
                tierBox(label: "Best Cells Tier", value: analysis.cells)
                tierBox(label: "Best Reroll Tier", value: analysis.shards)
            }
            .padding()
        }
    }

    var body: some View {
        NavigationView {
            VStack {
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
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Tower Analysis")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !authManager.isSignedIn {
                        signInButton
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                analysisView
            }
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
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary, lineWidth: 1)
        )
    }

}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
