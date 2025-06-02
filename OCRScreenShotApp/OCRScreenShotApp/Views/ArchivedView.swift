import SwiftUI

struct ArchivedView: View {
    @ObservedObject private var db = StatsDatabase.shared

    var body: some View {
        List {
            ForEach(db.entries.indices, id: \.self) { index in
                let entry = db.entries[index]
                NavigationLink(
                    destination: ArchivedDetailView(model: entry)
                ) {
                    VStack(alignment: .leading) {
                        Text("Tier \(entry.tier) - Wave \(entry.wave)")
                            .font(.headline)
                        Text("Game Time: \(entry.gameTime)")
                            .font(.subheadline)
                        if let date = entry.photoDate {
                            Text(date, formatter: dateFormatter)
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .navigationTitle("Archived")
    }

    private var dateFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }
}

struct ArchivedDetailView: View {
    let model: StatsModel

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }()

    private static let integerFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        f.roundingMode = .floor
        return f
    }()

    private static let decimalFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        f.roundingMode = .floor
        return f
    }()

    private static let durationFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        f.roundingMode = .floor
        return f
    }()

    private var displayPairs: [(String, String)] {
        var result: [(String, String)] = []
        if let date = model.photoDate {
            let formatted = Self.dateFormatter.string(from: date)
            result.append(("Photo Date", formatted))
        }
        result.append(contentsOf: [
            ("Game Time", model.gameTime),
            ("Real Time", model.realTime),
            (
                "Duration",
                (Self.durationFormatter.string(from: NSNumber(value: model.duration)) ?? "0") + "s"
            ),
            ("Tier", model.tier),
            ("Wave", model.wave),
            ("Killed By", model.killedBy),
            ("Coins Earned", model.coinsEarned),
            ("Coin Efficiency", Self.integerFormatter.string(from: NSNumber(value: model.coinEfficiency)) ?? "0"),
            ("Cash Earned", model.cashEarned),
            ("Interest Earned", model.interestEarned),
            ("Gem Blocks Tapped", model.gemBlocksTapped),
            ("Cells Earned", model.cellsEarned),
            ("Cell Efficiency", Self.decimalFormatter.string(from: NSNumber(value: model.cellEfficiency)) ?? "0.00"),
            ("Reroll Shards Earned", model.rerollShardsEarned),
            ("Shard Efficiency", Self.decimalFormatter.string(from: NSNumber(value: model.shardEfficiency)) ?? "0.00")
        ])
        return result
    }

    var body: some View {
        ScrollView {
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
            .padding()
        }
        .navigationTitle("Details")
    }
}

struct ArchivedView_Previews: PreviewProvider {
    static var previews: some View {
        ArchivedView()
    }
}
