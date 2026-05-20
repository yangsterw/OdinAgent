import WidgetKit
import SwiftUI

struct OdinWidgetEntry: TimelineEntry {
    let date: Date
    let imageName: String
}

struct OdinWidgetProvider: TimelineProvider {

    func placeholder(in context: Context) -> OdinWidgetEntry {
        OdinWidgetEntry(date: Date(), imageName: "odin_SH")
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (OdinWidgetEntry) -> Void
    ) {
        completion(
            OdinWidgetEntry(date: Date(), imageName: "odin_SH")
        )
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<OdinWidgetEntry>) -> Void
    ) {
        let now = Date()

        let entries = [
            OdinWidgetEntry(
                date: now,
                imageName: "odin_SH"
            ),
            OdinWidgetEntry(
                date: now.addingTimeInterval(2),
                imageName: "odin_BLINK"
            ),
            OdinWidgetEntry(
                date: now.addingTimeInterval(2.2),
                imageName: "odin_SH"
            )
        ]

        let timeline = Timeline(
            entries: entries,
            policy: .after(now.addingTimeInterval(10))
        )

        completion(timeline)
    }
}

struct OdinWidgetView: View {

    let entry: OdinWidgetEntry

    var body: some View {
        Link(destination: URL(string: "odinson://open")!) {
            VStack(spacing: 8) {
                Image(entry.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)

                Text("Pet Odin")
                    .font(.headline)
            }
            .padding()
        }
        .containerBackground(for: .widget) {
            Color.clear
        }
    }
}

struct OdinWidget: Widget {
    let kind: String = "OdinWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: OdinWidgetProvider()
        ) { entry in
            OdinWidgetView(entry: entry)
        }
        .configurationDisplayName("Odin")
        .description("Tap to Pet Odin.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium
        ])
    }
}

#Preview(as: .systemSmall) {
    OdinWidget()
} timeline: {
    OdinWidgetEntry(date: Date(), imageName: "odin_SH")
    OdinWidgetEntry(date: Date().addingTimeInterval(1), imageName: "odin_BLINK")
    OdinWidgetEntry(date: Date().addingTimeInterval(1.2), imageName: "odin_SH")
}
