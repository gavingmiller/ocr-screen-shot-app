import SwiftUI
import PhotosUI

struct ContentView: View {
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var photoItems: [PhotoData] = []

    var body: some View {
        NavigationView {
            VStack {
                if photoItems.isEmpty {
                    Text("Select screenshots to process")
                }
                List(photoItems) { item in
                    HStack {
                        if let image = item.image {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 100)
                        }
                        VStack(alignment: .leading) {
                            Text(item.ocrText ?? "No OCR yet")
                            switch item.postStatus {
                            case .none:
                                Text("Pending")
                                    .foregroundColor(.secondary)
                            case .success:
                                Text("Uploaded")
                                    .foregroundColor(.green)
                            case .failure:
                                Text("Failed")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                PhotosPicker(
                    selection: $selectedItems,
                    maxSelectionCount: nil,
                    matching: .images,
                    photoLibrary: .shared()) {
                    Text("Pick Photos")
                }
                .onChange(of: selectedItems) { _, newValue in
                    handleResults(newValue)
                }
                .padding()
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
                    let fields = OCRProcessor.shared.extractFields(from: text)
                    GoogleFormPoster.shared.post(fields: fields) { result in
                        DispatchQueue.main.async {
                            photoItems[index].postStatus = result ? .success : .failure
                        }
                    }
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
