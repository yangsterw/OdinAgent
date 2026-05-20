import WidgetKit
import SwiftUI

struct OdinWidgetEntry: TimelineEntry {
    let date: Date
}

struct OdinWidgetProvider: TimelineProvider {

    func placeholder(in context: Context) -> OdinWidgetEntry {
        OdinWidgetEntry(date: Date())
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (OdinWidgetEntry) -> Void
    ) {
        completion(OdinWidgetEntry(date: Date()))
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<OdinWidgetEntry>) -> Void
    ) {
        let entry = OdinWidgetEntry(date: Date())
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct OdinWidgetView: View {

    let entry: OdinWidgetEntry

    var body: some View {
        Link(destination: URL(string: "odinson://open")!) {
            VStack(spacing: 8) {
                Image("odin_SH")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)

                Text("Open Odin")
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
        .description("Tap to open Odin.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium
        ])
    }
}

#Preview(as: .systemSmall) {
    OdinWidget()
} timeline: {
    OdinWidgetEntry(date: Date())
}
