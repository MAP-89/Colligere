import SwiftUI
import SwiftData
import FirebaseCore
import GoogleSignIn

@main
struct ColligereApp: App {
    let container: ModelContainer
    @State private var authService: AuthService

    init() {
        FirebaseApp.configure()
        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }
        _authService = State(wrappedValue: AuthService())
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
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
        .modelContainer(container)
    }
}
