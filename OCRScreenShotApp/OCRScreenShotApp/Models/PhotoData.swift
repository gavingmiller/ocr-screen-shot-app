import SwiftUI
import PhotosUI

enum PostStatus {
    case none
    case success
    case failure
}

struct PhotoData: Identifiable {
    let id = UUID()
    let item: PhotosPickerItem
    var image: UIImage?
    var ocrText: String?
    var postStatus: PostStatus = .none

    init(item: PhotosPickerItem) {
        self.item = item
    }

    mutating func loadImage(completion: @escaping (Bool) -> Void) {
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                await MainActor.run {
                    self.image = uiImage
                    completion(true)
                }
            } else {
                await MainActor.run {
                    completion(false)
                }
            }
        }
    }
}
