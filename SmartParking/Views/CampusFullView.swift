import SwiftUI

struct CampusFullView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                alertCard
                nearbyParkingSection
                notifyCard
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 14)
        }
        .background(Palette.screen)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("No campus spots")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Palette.ink)
            Text("All levels at capacity")
                .font(.system(size: 15))
                .foregroundStyle(Palette.muted)
        }
    }

    private var alertCard: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Palette.alertRed)
                    .frame(width: 30, height: 30)
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Campus is full")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Palette.alertRed)
                Text("All 3 levels at capacity. Verified nearby options below.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.alertText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Palette.alertSoft)
        )
    }

    private var nearbyParkingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nearby parking")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Palette.ink)

            VStack(spacing: 14) {
                NearbyParkingCard(
                    title: "Parque Central Salitre",
                    price: "$3.500/hr",
                    minutes: "4 min",
                    free: "22 free",
                    badges: [.closest, .lit, .guarded],
                    accent: .blue,
                    isPrimary: true
                )
                NearbyParkingCard(
                    title: "Parking Av. El Dorado",
                    price: "$2.800/hr",
                    minutes: "6 min",
                    free: "8 free",
                    badges: [.lit],
                    accent: .gray,
                    isPrimary: false
                )
                NearbyParkingCard(
                    title: "Zona Azul — Bloque 14",
                    price: "$2.000/hr",
                    minutes: "8 min",
                    free: "3 free",
                    badges: [],
                    accent: .gray,
                    isPrimary: false
                )
                NearbyParkingCard(
                    title: "CC Metropolis P3",
                    price: "$4.000/hr",
                    minutes: "11 min",
                    free: "45 free",
                    badges: [.lit, .guarded],
                    accent: .gray,
                    isPrimary: false
                )
            }
        }
    }

    private var notifyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notify when campus opens up")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Palette.ink)
            HStack(alignment: .center, spacing: 12) {
                Text("We'll ping you the moment a spot")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button { } label: {
                    Text("Notify me")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(minWidth: 104)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Palette.purple)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Palette.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Palette.line, lineWidth: 1)
                )
        )
    }
}

private enum NearbyBadgeType {
    case closest
    case lit
    case guarded

    var label: String {
        switch self {
        case .closest: return "CLOSEST"
        case .lit: return "Lit"
        case .guarded: return "Guarded"
        }
    }

    var tint: Color {
        switch self {
        case .closest: return Palette.accentSoft
        case .lit: return Palette.amberSoft
        case .guarded: return Palette.violetSoft
        }
    }

    var foreground: Color {
        switch self {
        case .closest: return Palette.accent
        case .lit: return Palette.amberText
        case .guarded: return Palette.violetInk
        }
    }
}

private struct NearbyParkingCard: View {
    let title: String
    let price: String
    let minutes: String
    let free: String
    let badges: [NearbyBadgeType]
    let accent: AccentStyle
    let isPrimary: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text(price)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(Palette.ink)
            }

            HStack(alignment: .center, spacing: 14) {
                HStack(spacing: 6) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Palette.ink)
                    Text(minutes)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.ink)
                }

                Text(free)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Palette.greenInk)

                Spacer()

                if !badges.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(badges, id: \.label) { badge in
                            Text(badge.label)
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .foregroundStyle(badge.foreground)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(badge.tint)
                                )
                        }
                    }
                }
            }

            HStack(alignment: .center) {
                Spacer()
                Button { } label: {
                    Text("Navigate")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .frame(minWidth: 120)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(accent == .blue ? Palette.accent : Palette.buttonGray)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Palette.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isPrimary ? Palette.accent : Palette.line, lineWidth: isPrimary ? 1.8 : 1)
                )
        )
    }
}

private enum AccentStyle {
    case blue
    case gray
}
