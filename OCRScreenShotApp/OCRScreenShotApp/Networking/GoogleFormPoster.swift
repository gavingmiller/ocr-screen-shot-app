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

    func post(fields: OCRResultFields, completion: @escaping (Result<Void, Error>) -> Void) {
        var request = URLRequest(url: formURL)
        request.httpMethod = "POST"
        if let token = GoogleAuthManager.shared.idToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
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
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let http = response as? HTTPURLResponse else {
                let err = NSError(domain: "GoogleFormPoster", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                completion(.failure(err))
                return
            }
            if http.statusCode == 200 {
                completion(.success(()))
            } else {
                let err = NSError(domain: "GoogleFormPoster", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP status \(http.statusCode)"])
                completion(.failure(err))
            }
        }
        task.resume()
    }
}
