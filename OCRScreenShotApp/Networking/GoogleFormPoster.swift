import Foundation

class GoogleFormPoster {
    static let shared = GoogleFormPoster()

    // Replace these entry IDs with the ones from your Google Form
    private let formURL = URL(string: "https://docs.google.com/forms/d/e/1FAIpQLSdw27tlBBJBhYsLwG_6jCz8_WINxRMPk2jyaiqqgQ6v-7_-Lg/formResponse")!
    private let tierEntry = "entry.123456"
    private let waveEntry = "entry.234567"
    private let timeEntry = "entry.345678"
    private let coinsEntry = "entry.456789"
    private let cellsEntry = "entry.567890"
    private let shardsEntry = "entry.678901"

    func post(fields: OCRResultFields, completion: @escaping (Bool) -> Void) {
        var request = URLRequest(url: formURL)
        request.httpMethod = "POST"
        let body = [
            tierEntry: fields.tier,
            waveEntry: fields.wave,
            timeEntry: fields.realTime,
            coinsEntry: fields.coins,
            cellsEntry: fields.cells,
            shardsEntry: fields.shards
        ]
        .compactMap { key, value in
            guard !value.isEmpty else { return nil }
            return "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        }
        .joined(separator: "&")
        request.httpBody = body.data(using: .utf8)

        let task = URLSession.shared.dataTask(with: request) { _, response, error in
            guard let http = response as? HTTPURLResponse, error == nil else {
                completion(false)
                return
            }
            completion(http.statusCode == 200)
        }
        task.resume()
    }
}
