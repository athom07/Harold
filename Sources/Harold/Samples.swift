import Foundation

enum Samples {
    struct Example: Identifiable {
        let shortcut: String
        let icon: String
        let brief: Brief
        let aliases: [String]

        var id: UUID { brief.id }
    }

    static let examples: [Example] = [
        Example(shortcut: "Moon exploration", icon: "moon.stars", brief: Brief(
            query: "Why are we going back to the Moon?",
            cards: [
                ResearchCard(kind: .summary, title: "A stepping stone to Mars",
                    text: "NASA’s Artemis program aims to build a lasting presence near the lunar south pole. The Moon lets astronauts test equipment, study an unexplored region, and practice living off Earth before longer missions to Mars.",
                    sourceIDs: [1, 2]),
                ResearchCard(kind: .takeaways, title: "What matters most", details: [
                    Detail(label: "Learn to live off Earth", text: "Test habitats, spacesuits and surface operations closer to home.", sourceIDs: [1]),
                    Detail(label: "Investigate the south pole", text: "Shadowed regions may hold water ice that could support future crews.", sourceIDs: [2]),
                    Detail(label: "Study the early solar system", text: "Ancient lunar terrain preserves a record of early impacts.", sourceIDs: [3]),
                ]),
                ResearchCard(kind: .comparison, title: "Apollo and Artemis", details: [
                    Detail(label: "Apollo", text: "Short crewed expeditions primarily explored sites nearer the lunar equator.", sourceIDs: [4]),
                    Detail(label: "Artemis", text: "NASA and its partners plan longer-term exploration near the lunar south pole.", sourceIDs: [1, 4]),
                ]),
                ResearchCard(kind: .sources, title: "Read the original sources"),
            ],
            sources: [
                source(1, "NASA’s Artemis program", "https://www.nasa.gov/humans-in-space/artemis/"),
                source(2, "What is Artemis?", "https://www.nasa.gov/general/what-is-artemis/"),
                source(3, "Artemis science", "https://www.nasa.gov/humans-in-space/artemis-science/"),
                source(4, "From Apollo to Artemis", "https://www.nasa.gov/moonbase-environment-visualization/"),
            ],
            isSample: true
        ), aliases: ["why go back to the moon", "artemis"]),
        Example(shortcut: "Solar vs. wind", icon: "sun.max", brief: Brief(
            query: "How does solar power compare with wind power?",
            cards: [
                ResearchCard(kind: .summary, title: "Different resources, complementary output",
                    text: "Solar panels turn sunlight directly into electricity and can work at rooftop or utility scale. Wind turbines harvest moving air and can generate after dark. The best fit depends on local conditions and when electricity is needed.",
                    sourceIDs: [1, 2, 3]),
                ResearchCard(kind: .comparison, title: "How they generate", details: [
                    Detail(label: "Solar photovoltaics", text: "Cells convert sunlight to electricity. Output varies with cloud cover and the time of day.", sourceIDs: [1, 3]),
                    Detail(label: "Wind turbines", text: "Wind spins a rotor connected to a generator. Output depends on wind conditions at the site.", sourceIDs: [2, 3]),
                ]),
                ResearchCard(kind: .takeaways, title: "Deciding between them", details: [
                    Detail(label: "Start with the site", text: "Sun exposure, shading and local wind patterns inform which resource is practical.", sourceIDs: [1, 2]),
                    Detail(label: "Compare hourly output", text: "Generation patterns can complement each other when sunlight and wind peak at different times.", sourceIDs: [3]),
                ]),
                ResearchCard(kind: .sources, title: "Read the original sources"),
            ],
            sources: [
                source(1, "How does solar energy work?", "https://www.energy.gov/cmei/systems/how-does-solar-energy-work"),
                source(2, "How do wind turbines work?", "https://www.energy.gov/cmei/systems/how-do-wind-turbines-work"),
                source(3, "Wind energy FAQ", "https://www.energy.gov/cmei/systems/frequently-asked-questions-about-wind-energy"),
            ],
            isSample: true
        ), aliases: ["solar vs wind", "compare solar and wind"]),
        Example(shortcut: "History of GPS", icon: "location.north.line", brief: Brief(
            query: "How did GPS become part of everyday life?",
            cards: [
                ResearchCard(kind: .summary, title: "Military navigation became a public utility",
                    text: "The United States launched the first GPS satellite in 1978. By 1995 the system was fully operational. Turning off intentional degradation of the civilian signal in 2000 improved accuracy, expanding its use in navigation and other civilian applications.",
                    sourceIDs: [1, 2]),
                ResearchCard(kind: .takeaways, title: "Three milestones", details: [
                    Detail(label: "1978", text: "The U.S. launches the first GPS satellite.", sourceIDs: [1]),
                    Detail(label: "1995", text: "The system reaches full operational capability.", sourceIDs: [1]),
                    Detail(label: "2000", text: "The United States ends selective availability, improving civilian accuracy.", sourceIDs: [2]),
                ]),
                ResearchCard(kind: .chart, title: "Civilian GPS error before and after May 2000",
                    points: [ChartPoint(label: "Before", value: 100), ChartPoint(label: "After", value: 20)],
                    unit: "Predicted error in meters", sourceIDs: [2]),
                ResearchCard(kind: .sources, title: "Read the original sources"),
            ],
            sources: [
                source(1, "GPS history and operation", "https://archive.gps.gov/news/2009/COPUOS/"),
                source(2, "Civilian accuracy after selective availability", "https://archive.gps.gov/systems/gps/modernization/sa/benefits/"),
                source(3, "The Global Positioning System", "https://www.gps.gov/gps"),
            ],
            isSample: true
        ), aliases: ["gps", "history of gps"]),
    ]

    static func matching(_ question: String) -> Brief? {
        let key = normalize(question)
        return examples.first { example in
            ([example.brief.query, example.shortcut] + example.aliases).contains { normalize($0) == key }
        }?.brief
    }

    private static func normalize(_ text: String) -> String {
        text.lowercased().split { !$0.isLetter && !$0.isNumber }.joined(separator: " ")
    }

    private static func source(_ id: Int, _ title: String, _ link: String) -> Source {
        Source(id: id, title: title, url: URL(string: link)!, excerpt: "")
    }
}
