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
        Task {
            for item in items {
                var data = PhotoData(item: item)
                let success = await data.loadImage()
                if success {
                    OCRProcessor.shared.recognizeText(in: data.image!) { text in
                        DispatchQueue.main.async {
                            data.ocrText = text
                        }
                    }
                } else {
                    data.postStatus = .failure
                }
                await MainActor.run {
                    photoItems.append(data)
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
