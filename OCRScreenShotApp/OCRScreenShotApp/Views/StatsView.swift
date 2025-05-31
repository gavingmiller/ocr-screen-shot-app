import SwiftUI

struct StatsView: View {
    @Binding var photoData: PhotoData

    @State private var isPosting = false

    private var parsedPairs: [(String, String)] {
        if let text = photoData.ocrText {
            return OCRProcessor.shared.parsePairs(from: text)
        }
        return []
    }

    private var extractedFields: OCRResultFields {
        if let text = photoData.ocrText {
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

                if !parsedPairs.isEmpty {
                    Text("Stats:")
                        .font(.headline)
                        .padding(.top, 8)
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                        GridRow {
                            Text("Label").bold()
                            Text("Value").bold()
                        }
                        Divider().gridCellColumns(2)

                        ForEach(parsedPairs.indices, id: \.self) { index in
                            let pair = parsedPairs[index]
                            GridRow {
                                Text(pair.0)
                                Text(pair.1)
                            }
                            Divider().gridCellColumns(2)
                        }
                    }

                    submitButton
                } else if let text = photoData.ocrText {
                    Text("\nRecognized Text:")
                        .font(.headline)
                    Text(text)
                        .font(.footnote)
                        .padding(.top, 2)
                }
            }
            .padding()
        }
        .navigationTitle("Stats")
    }

    private var submitButton: some View {
        Button(action: submit) {
            if isPosting {
                ProgressView()
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
        .disabled(isPosting || photoData.postStatus != .none)
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

