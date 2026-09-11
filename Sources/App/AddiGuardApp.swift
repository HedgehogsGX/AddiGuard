import SwiftUI

@main
struct AddiGuardApp: App {
    @State private var store = ScanStore()
    @State private var theme = AppTheme()
    private let recognitionService = RecognitionService.live
    private let ingredientAnalysisService = IngredientAnalysisService.live

    var body: some Scene {
        WindowGroup {
            AppShellView()
                .environment(store)
                .environment(theme)
                .environment(\.recognitionService, recognitionService)
                .environment(\.ingredientAnalysisService, ingredientAnalysisService)
                .tint(theme.accent)
        }
    }
}
