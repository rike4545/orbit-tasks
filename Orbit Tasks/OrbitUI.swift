import SwiftUI

enum OrbitUI {
    static let barCornerRadius: CGFloat = 16
    static let cardCornerRadius: CGFloat = 14
    static let heroCornerRadius: CGFloat = 24
}

extension View {
    func orbitBarStyle() -> some View {
        self
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: OrbitUI.barCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: OrbitUI.barCornerRadius, style: .continuous)
                    .strokeBorder(.quaternary, lineWidth: 1)
            )
    }

    func orbitCardStyle() -> some View {
        self
            .padding(12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: OrbitUI.cardCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: OrbitUI.cardCornerRadius, style: .continuous)
                    .strokeBorder(.quaternary, lineWidth: 1)
            )
    }

    func orbitHeroCardStyle() -> some View {
        self
            .padding(16)
            .background(
                LinearGradient(
                    colors: [Color.white.opacity(0.18), Color.white.opacity(0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: OrbitUI.heroCornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: OrbitUI.heroCornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.22), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.14), radius: 16, y: 10)
    }

    func orbitScreenChrome() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(
                ZStack {
                    LinearGradient(
                        colors: [Color.black.opacity(0.08), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .allowsHitTesting(false)

                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 240, height: 240)
                        .blur(radius: 2)
                        .offset(x: 140, y: -300)
                        .allowsHitTesting(false)
                }
            )
    }
}

struct OrbitStatPill: View {
    let label: String
    let value: String
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.11), in: Capsule(style: .continuous))
    }
}

struct OrbitFocusHeader: View {
    let title: String
    let subtitle: String
    let pills: [OrbitStatPill]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.bold))
                .fontDesign(.rounded)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(pills.enumerated()), id: \.offset) { item in
                        item.element
                    }
                }
            }
        }
        .orbitHeroCardStyle()
    }
}
