import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("activeProjectID") private var activeProjectID: String?
    @Query private var projects: [LanguageProject]
    @Environment(AuthService.self) private var auth

    private var activeProject: LanguageProject? {
        guard let idString = activeProjectID,
              let id = UUID(uuidString: idString) else { return nil }
        return projects.first { $0.id == id }
    }

    var body: some View {
        TabView {
            Tab("Projects", systemImage: "folder") {
                ProjectListView()
            }
            Tab("Elicitation", systemImage: "list.bullet.clipboard") {
                if let project = activeProject {
                    ElicitationView(project: project)
                } else {
                    NoActiveProjectView()
                }
            }
            Tab("Translate", systemImage: "translate") {
                if let project = activeProject {
                    TranslateView(project: project)
                } else {
                    NoActiveProjectView()
                }
            }
            Tab("Lexicon", systemImage: "book") {
                if let project = activeProject {
                    LexiconView(project: project)
                } else {
                    NoActiveProjectView()
                }
            }
            Tab("Settings", systemImage: "gear") {
                SettingsView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .fullScreenCover(isPresented: Binding(
            get: { !auth.isSignedIn && !auth.hasSkippedSignIn },
            set: { _ in }
        )) {
            SignInView(onSkip: { auth.skipSignIn() })
        }
    }
}

struct NoActiveProjectView: View {
    var message: String = "Select or create a project in the Projects tab"

    var body: some View {
        ContentUnavailableView(
            "No Active Project",
            systemImage: "folder.badge.questionmark",
            description: Text(message)
        )
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            LanguageProject.self,
            LexicalEntry.self,
            AudioRecording.self,
            TranslationSession.self
        ], inMemory: true)
        .environment(AuthService())
}
