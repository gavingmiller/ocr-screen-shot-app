import SwiftUI

struct StatsView: View {
    @Binding var photoData: PhotoData

    @State private var isPosting = false
    @StateObject private var authManager = GoogleAuthManager.shared

    private var parsedPairs: [(String, String)] {
        if let text = photoData.ocrText,
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return OCRProcessor.shared.parsePairs(from: text)
        }
        return []
    }

    private var statsModel: StatsModel? {
        if let text = photoData.ocrText,
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let pairs = OCRProcessor.shared.parsePairs(from: text)
            guard !pairs.isEmpty else { return nil }
            return StatsModel(pairs: pairs)
        }
        return nil
    }

    private var displayPairs: [(String, String)] {
        if let model = statsModel {
            return [
                ("Game Time", model.gameTime),
                ("Real Time", model.realTime),
                ("Tier", model.tier),
                ("Wave", model.wave),
                ("Killed By", model.killedBy),
                ("Coins Earned", model.coinsEarned),
                ("Cash Earned", model.cashEarned),
                ("Interest Earned", model.interestEarned),
                ("Gem Blocks Tapped", model.gemBlocksTapped),
                ("Cells Earned", model.cellsEarned),
                ("Reroll Shards Earned", model.rerollShardsEarned)
            ]
        }
        return parsedPairs
    }

    private var extractedFields: OCRResultFields {
        if let text = photoData.ocrText,
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return OCRProcessor.shared.extractFields(from: text)
        }
        return OCRResultFields()
    }

    var body: some View {
        ScrollView {
            if let image = photoData.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }

            VStack(alignment: .leading, spacing: 8) {

                if !displayPairs.isEmpty {
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                        ForEach(displayPairs.indices, id: \.self) { index in
                            let pair = displayPairs[index]
                            GridRow {
                                Text(pair.0)
                                Text(pair.1)
                            }
                            Divider().gridCellColumns(2)
                        }
                    }

                    submitButton
                } else if let text = photoData.ocrText,
                          !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("\nRecognized Text:")
                        .font(.headline)
                    Text(text)
                        .font(.footnote)
                        .padding(.top, 2)
                } else {
                    Text("Invalid image")
                        .font(.headline)
                        .padding(.top, 8)
                }
            }
            .padding()
        }
    }

    private var submitButton: some View {
        Button(action: submit) {
            if isPosting {
                ProgressView()
            } else if statsModel?.hasParsingError == true {
                Text("Parsing error cannot submit")
            } else {
                switch photoData.postStatus {
                case .success:
                    Text("Submitted \u{2705}")
                case .failure:
                    Text("Failed \u{274C}")
                default:
                    Text("Submit to Google Sheets")
                }
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(tintColor)
        .disabled(isPosting || photoData.postStatus != .none || !authManager.isSignedIn || statsModel?.hasParsingError == true)
        .padding(.top, 8)
    }

    private var tintColor: Color {
        switch photoData.postStatus {
        case .success:
            return .green
        case .failure:
            return .red
        default:
            return .blue
        }
    }

    private func submit() {
        isPosting = true
        GoogleFormPoster.shared.post(fields: extractedFields) { result in
            DispatchQueue.main.async {
                isPosting = false
                switch result {
                case .success:
                    photoData.postStatus = .success
                case .failure(let error):
                    print("Google form submission error: \(error.localizedDescription)")
                    photoData.postStatus = .failure
                }
            }
        }
    }
}

