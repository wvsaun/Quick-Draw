//
//  Theme.swift
//  QuickDraw
//
//  Warm Western palette + shared components. Deliberately restrained: dark
//  charcoal-brown backdrop, parchment surfaces, copper/gold accents, slab-ish
//  serif type. No gun imagery anywhere.
//

import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }

    static let qdBackground = Color(hex: 0x241B12)   // dark saloon brown
    static let qdSurface = Color(hex: 0xE9D7B4)      // parchment
    static let qdSurfaceDark = Color(hex: 0x3A2C1D)  // worn leather
    static let qdCopper = Color(hex: 0xB5652A)       // copper accent
    static let qdGold = Color(hex: 0xC89B3C)         // muted gold
    static let qdInk = Color(hex: 0x33241B)          // dark ink on parchment
    static let qdWin = Color(hex: 0x1F7A33)
    static let qdLose = Color(hex: 0x9E2B25)
    static let qdAmber = Color(hex: 0xC98A2D)
}

/// Big Western display text (serif + heavy + tracked out).
struct WesternTitle: ViewModifier {
    var size: CGFloat = 40
    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: .black, design: .serif))
            .kerning(2)
            .multilineTextAlignment(.center)
    }
}

extension View {
    func westernTitle(size: CGFloat = 40) -> some View {
        modifier(WesternTitle(size: size))
    }
}

/// Primary parchment-on-copper button.
struct WesternButtonStyle: ButtonStyle {
    var prominent = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.title3, design: .serif).weight(.bold))
            .kerning(1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(prominent ? Color.qdCopper : Color.qdSurfaceDark)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.qdGold.opacity(0.6), lineWidth: 1.5)
            )
            .foregroundStyle(prominent ? Color.qdSurface : Color.qdGold)
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

/// Parchment info card.
struct ParchmentCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.qdSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.qdCopper.opacity(0.5), lineWidth: 1)
            )
    }
}

/// Full-screen backdrop shared by every screen.
struct WesternBackground: View {
    var body: some View {
        ZStack {
            Color.qdBackground.ignoresSafeArea()
            // Subtle vertical "wood grain" bands — pure gradients, no assets.
            LinearGradient(colors: [.clear, Color.qdSurfaceDark.opacity(0.25), .clear],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        }
    }
}

/// Small status chip ("READY", "WAITING", …).
struct StatusChip: View {
    let text: String
    let active: Bool

    var body: some View {
        Text(text)
            .font(.caption.weight(.bold))
            .kerning(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(active ? Color.qdGold : Color.qdSurfaceDark))
            .foregroundStyle(active ? Color.qdBackground : Color.qdSurface.opacity(0.7))
            .accessibilityLabel(text)
    }
}
