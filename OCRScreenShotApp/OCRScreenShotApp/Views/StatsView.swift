import SwiftUI

struct StatsView: View {
    @Binding var photoData: PhotoData

    private var parsedPairs: [(String, String)] {
        if let text = photoData.ocrText {
            return OCRProcessor.shared.parsePairs(from: text)
        }
        return []
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
}

