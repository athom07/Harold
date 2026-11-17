import Charts
import SwiftUI

struct BriefView: View {
    let brief: Brief
    let width: CGFloat
    let isSpeaking: Bool
    let onSpeak: () -> Void
    let onFollowUp: () -> Void
    let onSources: () -> Void
    let canFollowUp: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            Divider().overlay(Palette.border.opacity(0.55))
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 8) {
                    SmallLabel(text: brief.isSample ? "Sample research" : "Research brief", color: Palette.accent)
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(Palette.mint, in: Capsule())
                    Text(brief.query)
                        .font(.harold(size: 26, weight: .bold))
                        .foregroundStyle(Palette.text)
                        .accessibilityAddTraits(.isHeader)
                }
                Spacer(minLength: 12)
                Button(action: onSources) {
                    Label("\(brief.sources.count) sources", systemImage: "link")
                        .font(.harold(size: 13, weight: .semibold))
                        .padding(.horizontal, 11).frame(height: 32)
                }
                .buttonStyle(HoverButtonStyle(fill: Palette.panel, radius: 17))
                Button(action: onSpeak) {
                    Label(isSpeaking ? "Stop" : "Listen", systemImage: isSpeaking ? "stop.fill" : "waveform")
                        .font(.harold(size: 13, weight: .semibold))
                        .padding(.horizontal, 11).frame(height: 32)
                }
                .buttonStyle(HoverButtonStyle(fill: Palette.mint, radius: 17))
                .foregroundStyle(Palette.accent)
            }

            ForEach(Array(stride(from: 0, to: brief.cards.count, by: width >= 650 ? 2 : 1)), id: \.self) { start in
                if width >= 650, start + 1 < brief.cards.count {
                    HStack(alignment: .top, spacing: 14) {
                        card(brief.cards[start])
                            .frame(width: (width - 14) * 0.54)
                        card(brief.cards[start + 1])
                            .frame(width: (width - 14) * 0.46)
                    }
                } else {
                    card(brief.cards[start])
                }
            }
            if canFollowUp {
                Button(action: onFollowUp) {
                    Label("Ask a follow-up", systemImage: "arrow.turn.up.left")
                        .font(.harold(size: 13, weight: .semibold))
                        .padding(.horizontal, 12).frame(height: 34)
                }
                .buttonStyle(HoverButtonStyle(fill: Palette.panel, radius: 17))
            }
        }
        .frame(width: width)
    }

    private func card(_ card: ResearchCard) -> some View {
        CardView(card: card, sources: brief.sources)
            .id(card.kind)
    }
}

struct CardView: View {
    let card: ResearchCard
    let sources: [Source]

    private var iconColor: Color {
        switch card.kind {
        case .summary: Palette.rgb(0x654B8B)
        case .takeaways: Palette.teal
        case .comparison, .prosCons, .metrics: Palette.amber
        case .chart: Palette.accent
        case .sources: Palette.teal
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                Image(systemName: card.kind.icon)
                    .font(.harold(size: 13, weight: .bold))
                    .frame(width: 27, height: 27)
                    .background(iconColor.opacity(0.13), in: Circle())
                    .foregroundStyle(iconColor)
                    .accessibilityHidden(true)
                SmallLabel(text: card.kind.label)
            }
            Text(card.title)
                .font(.harold(size: 18, weight: .bold))
                .foregroundStyle(Palette.text)
                .accessibilityAddTraits(.isHeader)

            switch card.kind {
            case .summary:
                Text(card.text)
                    .font(.harold(size: 14, weight: .medium))
                    .foregroundStyle(Palette.secondary)
                    .lineSpacing(5)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                Citations(ids: card.sourceIDs, sources: sources)
            case .takeaways, .comparison, .prosCons, .metrics:
                ForEach(Array(card.details.enumerated()), id: \.offset) { index, detail in
                    if index > 0 { Divider().overlay(Palette.border.opacity(0.4)) }
                    HStack(alignment: .top, spacing: 10) {
                        if card.kind == .takeaways {
                            Image(systemName: "checkmark")
                                .font(.harold(size: 12, weight: .bold))
                                .foregroundStyle(iconColor)
                                .padding(.top, 3)
                                .accessibilityHidden(true)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(detail.label).font(.harold(size: 13, weight: .bold)).foregroundStyle(Palette.text)
                            Text(detail.text).font(.harold(size: 13)).foregroundStyle(Palette.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 2)
                        Citations(ids: detail.sourceIDs, sources: sources)
                    }
                }
            case .chart:
                let points = Array(card.points.enumerated())
                Chart(points, id: \.offset) { _, point in
                    BarMark(x: .value(card.unit.isEmpty ? "Value" : card.unit, point.value), y: .value("Category", point.label))
                        .foregroundStyle(Palette.accent.gradient)
                        .cornerRadius(3)
                }
                .chartPlotStyle { $0.padding(.vertical, 5) }
                .frame(height: CGFloat(55 + points.count * 27))
                if !card.unit.isEmpty {
                    Text(card.unit).font(.harold(size: 12)).foregroundStyle(Palette.secondary)
                }
                Citations(ids: card.sourceIDs, sources: sources)
            case .sources:
                VStack(spacing: 3) {
                    ForEach(sources) { source in SourceRow(source: source) }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: card.kind == .summary ? 222 : 0, alignment: .topLeading)
        .modifier(Surface(
            fill: card.kind == .summary ? Palette.lavender : Palette.panel,
            border: card.kind == .summary ? .white : Palette.border.opacity(0.48),
            radius: 22
        ))
    }
}

struct SourceRow: View {
    let source: Source

    var body: some View {
        Link(destination: source.url) {
            HStack(spacing: 9) {
                Text(String(format: "%02d", source.id))
                    .font(.harold(size: 10, weight: .bold))
                    .foregroundStyle(Palette.accent)
                    .frame(width: 23, height: 23)
                    .background(Palette.raised, in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(source.title).font(.harold(size: 13, weight: .semibold)).lineLimit(1)
                        .foregroundStyle(Palette.text)
                    Text(source.domain).font(.harold(size: 11)).foregroundStyle(Palette.muted).lineLimit(1)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Palette.muted)
            }
            .padding(5)
            .contentShape(Rectangle())
        }
        .buttonStyle(HoverButtonStyle())
        .help(source.url.absoluteString)
    }
}

private struct Citations: View {
    let ids: [Int]
    let sources: [Source]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(sources.filter { ids.contains($0.id) }) { source in
                Link(destination: source.url) {
                    Text("\(source.id)")
                        .font(.harold(size: 10, weight: .bold))
                        .foregroundStyle(Palette.accent)
                        .frame(minWidth: 21, minHeight: 21)
                }
                .buttonStyle(HoverButtonStyle(fill: Palette.mint.opacity(0.78), radius: 10))
                .help(source.title)
                .accessibilityLabel("Source \(source.id), \(source.title)")
            }
        }
    }
}
