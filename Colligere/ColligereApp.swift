import SwiftUI
import SwiftData
import FirebaseCore

@main
struct ColligereApp: App {
    let container: ModelContainer
    let authService = AuthService()

    init() {
        FirebaseApp.configure()
        do {
            container = try ModelContainer(for:
                LanguageProject.self,
                LexicalEntry.self,
                AudioRecording.self,
                TranslationSession.self
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authService)
        }
        .modelContainer(container)
    }
}
