import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case map
    case reserve
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .map: return "Map"
        case .reserve: return "Reserve"
        case .profile: return "Profile"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house"
        case .map: return "map"
        case .reserve: return "calendar"
        case .profile: return "person"
        }
    }
}

struct AppTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 6) {
                        Capsule()
                            .fill(selection == tab ? Palette.accent : Color.clear)
                            .frame(width: 30, height: 3)
                        Image(systemName: tab.icon)
                            .font(.system(size: 19, weight: .regular))
                        Text(tab.title)
                            .font(.system(size: 11, weight: selection == tab ? .semibold : .regular))
                    }
                    .foregroundStyle(selection == tab ? Palette.accent : Palette.muted)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 6)
        .background(Palette.card)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Palette.line)
                .frame(height: 1)
        }
    }
}
