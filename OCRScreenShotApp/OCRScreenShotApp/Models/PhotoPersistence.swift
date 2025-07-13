import Foundation
import UIKit

struct StoredPhoto: Codable {
    let id: UUID
    let imageName: String
    let ocrText: String?
    let statsModel: StatsModel?
    let creationDate: Date?
    let isAdded: Bool
    let isDuplicate: Bool
}

final class PhotoPersistence {
    static let shared = PhotoPersistence()

    private let imagesDir: URL
    private let fileURL: URL

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        imagesDir = docs.appendingPathComponent("SavedImages", isDirectory: true)
        fileURL = docs.appendingPathComponent("photos.json")
        if !FileManager.default.fileExists(atPath: imagesDir.path) {
            try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        }
    }

    func save(_ photos: [PhotoData]) {
        let records: [StoredPhoto] = photos.compactMap { photo in
            guard let image = photo.image else { return nil }
            let name = photo.id.uuidString + ".png"
            let url = imagesDir.appendingPathComponent(name)
            if !FileManager.default.fileExists(atPath: url.path) {
                if let data = image.pngData() {
                    try? data.write(to: url)
                }
            }
            return StoredPhoto(id: photo.id, imageName: name, ocrText: photo.ocrText, statsModel: photo.statsModel, creationDate: photo.creationDate, isAdded: photo.isAdded, isDuplicate: photo.isDuplicate)
        }
        guard let data = try? JSONEncoder().encode(records) else { return }
        try? data.write(to: fileURL)
    }

    func load() -> [PhotoData] {
        guard let data = try? Data(contentsOf: fileURL),
              let records = try? JSONDecoder().decode([StoredPhoto].self, from: data) else {
            return []
        }
        return records.map { rec in
            let url = imagesDir.appendingPathComponent(rec.imageName)
            let image = UIImage(contentsOfFile: url.path)
            return PhotoData(id: rec.id, image: image, ocrText: rec.ocrText, statsModel: rec.statsModel, creationDate: rec.creationDate, isAdded: rec.isAdded, isDuplicate: rec.isDuplicate)
        }
    }
}
