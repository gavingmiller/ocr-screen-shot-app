import SwiftUI
import PhotosUI

struct ContentView: View {
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var photoItems: [PhotoData] = []

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
            .navigationTitle("OCR Screen Shot")
        }
    }

    private func handleResults(_ items: [PhotosPickerItem]) {
        for item in items {
            let data = PhotoData(item: item)
            photoItems.append(data)
            loadImage(for: data)
        }
        selectedItems.removeAll()
    }

    private func loadImage(for photoData: PhotoData) {
        guard let index = photoItems.firstIndex(where: { $0.id == photoData.id }) else { return }
        Task {
            let success = await photoItems[index].loadImage()
            if success {
                OCRProcessor.shared.recognizeText(in: photoItems[index].image!) { text in
                    DispatchQueue.main.async {
                        photoItems[index].ocrText = text
                    }
                    // Do not auto-submit to Google after OCR. Submission will
                    // happen from the Stats screen.
                }
            } else {
                DispatchQueue.main.async {
                    photoItems[index].postStatus = .failure
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
