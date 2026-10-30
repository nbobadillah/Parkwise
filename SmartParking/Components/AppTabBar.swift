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
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(selection == tab ? Palette.accent : Color.clear)
                            .frame(width: 32, height: 2)
                        Image(systemName: tab.icon)
                            .font(.system(size: 20, weight: .regular))
                            .padding(.top, 8)
                        Text(tab.title)
                            .font(.system(size: 11, weight: .medium))
                            .padding(.top, 4)
                            .padding(.bottom, 8)
                    }
                    .foregroundStyle(selection == tab ? Palette.accent : Palette.muted)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(Palette.card)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Palette.line)
                .frame(height: 1)
        }
    }
}
