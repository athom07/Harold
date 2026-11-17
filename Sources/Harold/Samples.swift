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
        Example(shortcut: "Espresso under $2,000", icon: "cup.and.saucer", brief: Brief(
            query: "Compare the best dual-boiler espresso machines under $2,000",
            generatedQueries: [
                "best dual boiler espresso machine under 2000",
                "Breville Dual Boiler vs Rancilio Silvia Pro X vs Profitec Pro 300 specs"
            ],
            cards: [
                ResearchCard(kind: .summary, title: "Three true dual-boilers dominate under $2,000",
                    text: "The Breville Dual Boiler (BES920XL), Rancilio Silvia Pro X, and Profitec Pro 300 are the standout dual-boiler machines under $2,000. Breville leads in thermal PID precision and programmable pre-infusion ($1,599), Rancilio delivers commercial-grade 58mm portafilter durability and soft infusion ($1,990), and Profitec offers compact German brass-and-steel build with fast 10-minute warm-up ($1,849).",
                    sourceIDs: [1, 2, 3, 4]),
                ResearchCard(kind: .comparison, title: "Head-to-head comparison matrix", details: [
                    Detail(label: "Breville Dual Boiler ($1,599)", text: "58mm actively heated group · Dual stainless boilers · Electronic PID + volumetric shot control · Height: 14.8 in.", sourceIDs: [1, 4]),
                    Detail(label: "Profitec Pro 300 ($1,849)", text: "58mm ring group · 0.32L brass brew + 0.75L steel steam boiler · Fast 10-min heat-up · Height: 14.9 in.", sourceIDs: [2, 3]),
                    Detail(label: "Rancilio Silvia Pro X ($1,990)", text: "58mm commercial group · Dual PID + variable soft pre-infusion · Heavy stainless chassis · Height: 15.3 in.", sourceIDs: [1, 2]),
                ]),
                ResearchCard(kind: .prosCons, title: "Trade-offs across the class", details: [
                    Detail(label: "Advantage · Simultaneous brew & steam", text: "Dedicated brew and steam boilers eliminate temperature surfing and recovery wait times between milk drinks.", sourceIDs: [1, 2]),
                    Detail(label: "Advantage · 15-amp countertop friendly", text: "All three models operate on standard 110–120V household circuits without requiring a 20A kitchen outlet.", sourceIDs: [3, 4]),
                    Detail(label: "Disadvantage · Countertop clearance", text: "Rancilio Silvia Pro X stands 15.3 inches tall, which can brush low kitchen upper cabinets compared to Breville (14.8 in).", sourceIDs: [1, 3]),
                ]),
                ResearchCard(kind: .metrics, title: "Key specifications & dimensions", details: [
                    Detail(label: "Cabinet Clearance (Height)", text: "Breville: 14.8\" · Profitec Pro 300: 14.9\" · Rancilio Silvia Pro X: 15.3\"", sourceIDs: [1, 3, 4]),
                    Detail(label: "Brew Boiler Stability", text: "±1°F digital PID regulation across all three machines", sourceIDs: [1, 2]),
                    Detail(label: "Heat-Up Time to First Shot", text: "Breville: ~6 min · Profitec Pro 300: ~10 min · Rancilio Silvia Pro X: ~12 min", sourceIDs: [2, 4]),
                ]),
                ResearchCard(kind: .chart, title: "Street price in USD (under $2,000 cap)",
                    points: [
                        ChartPoint(label: "Breville BES920XL", value: 1599),
                        ChartPoint(label: "Profitec Pro 300", value: 1849),
                        ChartPoint(label: "Rancilio Silvia Pro X", value: 1990),
                    ],
                    unit: "Retail price in USD", sourceIDs: [1, 2, 3]),
                ResearchCard(kind: .sources, title: "Verified source citations"),
            ],
            sources: [
                source(1, "Best Dual Boiler Espresso Machines Tested", "https://www.seriouseats.com/best-espresso-machines",
                       excerpt: "Dual boiler machines use one boiler for brewing espresso at ~200°F and a second boiler for steaming milk at ~265°F. The Breville Dual Boiler ($1,599, 14.8 inches tall) and Rancilio Silvia Pro X ($1,990, 15.3 inches tall) lead our testing.",
                       rawBytes: 154_200, words: 1_480,
                       claims: ["Breville Dual Boiler retails at $1,599 and measures 14.8 inches tall", "Rancilio Silvia Pro X retails at $1,990 and measures 15.3 inches tall"]),
                source(2, "Rancilio Silvia Pro X vs Profitec Pro 300 Review", "https://www.wholelattelove.com/collections/dual-boiler-espresso-machines",
                       excerpt: "The Profitec Pro 300 ($1,849) pairs a 0.32L brass brew boiler with a 0.75L stainless steam boiler in a compact 14.9-inch-tall frame that heats in 10 minutes.",
                       rawBytes: 142_800, words: 1_390,
                       claims: ["Profitec Pro 300 costs $1,849 with a 0.32L brass brew boiler", "Heats up to brewing temperature in 10 minutes"]),
                source(3, "Profitec Pro 300 Technical Specifications", "https://www.profitec-espresso.com/en/products/pro-300",
                       excerpt: "Dual boiler with ring group, PID display with shot timer, dimensions 255 x 415 x 380 mm (14.9 inches height).",
                       rawBytes: 98_400, words: 1_120,
                       claims: ["Profitec Pro 300 height is 380 mm (14.9 inches)", "Includes integrated PID temperature controller and shot timer"]),
                source(4, "Breville Dual Boiler BES920XL Architecture", "https://www.breville.com/us/en/products/espresso/bes920.html",
                       excerpt: "Dual stainless steel boilers and heated group head controlled by digital PID. Over-pressure valve limits extraction pressure to 9 bars. Height: 14.8 inches.",
                       rawBytes: 128_900, words: 1_310,
                       claims: ["Active heated 58mm group head reaches thermal equilibrium in 6 minutes", "Height is 14.8 inches with top-fill water access"]),
            ],
            isSample: true
        ), aliases: [
            "compare the best dual boiler espresso machines under 2 000",
            "compare the best dual boiler espresso machines under 2000",
            "dual boiler espresso machines",
            "espresso machines under 2000"
        ]),
        Example(shortcut: "Moon exploration", icon: "moon.stars", brief: Brief(
            query: "Why are we going back to the Moon?",
            generatedQueries: ["NASA Artemis lunar south pole goals", "Apollo vs Artemis moon exploration"],
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
            generatedQueries: ["solar pv vs wind turbine efficiency comparison", "hourly generation profile solar and wind"],
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
            generatedQueries: ["GPS timeline 1978 1995 2000 selective availability", "civilian GPS accuracy improvement"],
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
        if key.contains("15 inches") || key.contains("taller than 15") {
            return espressoFilteredUnder15Inches
        }
        return examples.first { example in
            ([example.brief.query, example.shortcut] + example.aliases).contains { normalize($0) == key }
        }?.brief
    }

    static let espressoFilteredUnder15Inches = Brief(
        query: "Filter out anything taller than 15 inches (Dual-boiler espresso machines under $2,000)",
        generatedQueries: ["dual boiler espresso machine height under 15 inches", "Breville BES920XL vs Profitec Pro 300 dimensions"],
        cards: [
            ResearchCard(kind: .summary, title: "Two dual-boiler machines fit under 15-inch cabinets",
                text: "Filtering out machines taller than 15.0 inches eliminates the Rancilio Silvia Pro X (15.3 in). The remaining contenders are the Breville Dual Boiler BES920XL (14.8 in, $1,599) and the Profitec Pro 300 (14.9 in, $1,849). Breville adds a front-accessible water tank fill funnel and rolling chassis feet for tight under-cabinet counters.",
                sourceIDs: [1, 2, 3, 4]),
            ResearchCard(kind: .comparison, title: "Under-15-inch qualifying machines", details: [
                Detail(label: "Breville Dual Boiler ($1,599 · 14.8 in)", text: "Qualifies with 0.2\" margin · Front top-fill water access · Built-in rolling feet for under-cabinet sliding.", sourceIDs: [1, 4]),
                Detail(label: "Profitec Pro 300 ($1,849 · 14.9 in)", text: "Qualifies with 0.1\" margin · Brass/steel dual boilers · Requires clearance above top reservoir lid to refill.", sourceIDs: [2, 3]),
                Detail(label: "Excluded: Rancilio Silvia Pro X (15.3 in)", text: "Filtered out — exceeds 15.0\" height limit by 0.3 inches.", sourceIDs: [1]),
            ]),
            ResearchCard(kind: .metrics, title: "Verified height & clearance metrics", details: [
                Detail(label: "Breville BES920XL Height", text: "14.8 in (376 mm) — Best under-cabinet ergonomics", sourceIDs: [4]),
                Detail(label: "Profitec Pro 300 Height", text: "14.9 in (380 mm) — Fits 15\" cabinet, slide out to refill reservoir", sourceIDs: [3]),
            ]),
            ResearchCard(kind: .sources, title: "Verified source citations"),
        ],
        sources: examples[0].brief.sources,
        isSample: true
    )

    private static func normalize(_ text: String) -> String {
        text.lowercased().split { !$0.isLetter && !$0.isNumber }.joined(separator: " ")
    }

    private static func source(
        _ id: Int,
        _ title: String,
        _ link: String,
        excerpt: String = "",
        rawBytes: Int = 138_000,
        words: Int = 1_420,
        claims: [String] = []
    ) -> Source {
        Source(
            id: id,
            title: title,
            url: URL(string: link)!,
            excerpt: excerpt,
            rawByteCount: rawBytes,
            distilledWordCount: words,
            mappedClaims: claims
        )
    }
}

