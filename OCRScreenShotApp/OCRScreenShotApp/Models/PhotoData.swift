import SwiftUI
import PhotosUI
import Photos
import ImageIO

struct PhotoData: Identifiable {
    let id = UUID()
    let item: PhotosPickerItem
    var image: UIImage?
    var ocrText: String?
    var statsModel: StatsModel?
    var creationDate: Date?

    init(item: PhotosPickerItem) {
        self.item = item
    }

    // Cropping ratios based on a 1206x2622 reference screenshot.
    // Adjust these values if the UI layout changes.
    private let cropLeftRatio: CGFloat = 0.0
    private let cropTopRatio: CGFloat = 460.0 / 2622.0
    private let cropRightRatio: CGFloat = 1.0
    private let cropBottomRatio: CGFloat = 1360 / 2622.0

    /// Crop the given image using the ratios above. The ratios are applied
    /// to the pixel dimensions of the image so this works for different
    /// screenshot resolutions while keeping the region of interest.
    private func crop(_ image: UIImage) -> UIImage {
        let pixelWidth = CGFloat(image.cgImage?.width ?? Int(image.size.width))
        let pixelHeight = CGFloat(image.cgImage?.height ?? Int(image.size.height))

        let rect = CGRect(x: cropLeftRatio * pixelWidth,
                          y: cropTopRatio * pixelHeight,
                          width: (cropRightRatio - cropLeftRatio) * pixelWidth,
                          height: (cropBottomRatio - cropTopRatio) * pixelHeight)

        guard let cgImage = image.cgImage?.cropping(to: rect) else {
            return image
        }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    mutating func loadImage() async -> Bool {
        if let data = try? await item.loadTransferable(type: Data.self),
           let uiImage = UIImage(data: data) {
            let cropped = crop(uiImage)
            await MainActor.run {
                self.image = cropped
            }

            if let id = item.itemIdentifier {
                let assets = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
                self.creationDate = assets.firstObject?.creationDate
            } else if let source = CGImageSourceCreateWithData(data as CFData, nil),
                      let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
                if let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any],
                   let dateStr = exif[kCGImagePropertyExifDateTimeOriginal] as? String {
                    let df = DateFormatter()
                    df.dateFormat = "yyyy:MM:dd HH:mm:ss"
                    self.creationDate = df.date(from: dateStr)
                } else if let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any],
                          let dateStr = tiff[kCGImagePropertyTIFFDateTime] as? String {
                    let df = DateFormatter()
                    df.dateFormat = "yyyy:MM:dd HH:mm:ss"
                    self.creationDate = df.date(from: dateStr)
                }
            }

            return true
        } else {
            return false
        }
    }
}
