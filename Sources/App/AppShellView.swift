import SwiftUI

enum AppTab: Hashable {
    case scan
    case history
    case profile

    var title: String {
        switch self {
        case .scan: "匹配"
        case .history: "记录"
        case .profile: "我的"
        }
    }

    var symbol: String {
        switch self {
        case .scan: "viewfinder"
        case .history: "clock.arrow.circlepath"
        case .profile: "person.crop.circle"
        }
    }
}

struct AppShellView: View {
    @Environment(AppTheme.self) private var theme

    @State private var selectedTab: AppTab = .scan
    @State private var scanPath: [UUID] = []

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $scanPath) {
                ScanHomeView(path: $scanPath)
            }
            .tabItem { Label(AppTab.scan.title, systemImage: AppTab.scan.symbol) }
            .tag(AppTab.scan)

            NavigationStack {
                HistoryView(selectedTab: $selectedTab)
            }
            .tabItem { Label(AppTab.history.title, systemImage: AppTab.history.symbol) }
            .tag(AppTab.history)

            NavigationStack {
                ProfileView()
            }
            .tabItem { Label(AppTab.profile.title, systemImage: AppTab.profile.symbol) }
            .tag(AppTab.profile)
        }
        .background(theme.canvas.ignoresSafeArea())
        .onOpenURL { url in
            guard url.scheme?.lowercased() == "addiguard" else { return }

            if url.host?.lowercased() == "scan" {
                selectedTab = .scan
                scanPath.removeAll()
            }
        }
    }
}
