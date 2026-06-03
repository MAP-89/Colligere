import SwiftUI
import AuthenticationServices
import GoogleSignInSwift

struct SignInView: View {
    @Environment(AuthService.self) private var auth
    var onSkip: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 14) {
                Image(systemName: "waveform.and.mic")
                    .font(.system(size: 72))
                    .foregroundStyle(Color.accentColor)
                    .padding(.bottom, 4)

                Text("LinguaField")
                    .font(.largeTitle.bold())

                Text("Document languages,\ntogether.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
            Spacer()

            VStack(spacing: 14) {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = auth.prepareAppleSignIn()
                } onCompletion: { result in
                    Task { await auth.handleAppleSignIn(result) }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .disabled(auth.isLoading)

                GoogleSignInButton(
                    scheme: .light,
                    style: .wide,
                    state: .normal
                ) {
                    Task { await auth.handleGoogleSignIn() }
                }
                .frame(height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .disabled(auth.isLoading)

                if auth.isLoading {
                    ProgressView()
                        .transition(.opacity)
                }

                if let err = auth.errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button("Continue without signing in") {
                    onSkip()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text("Sign in to contribute to collaborative\ndocumentation projects with other field linguists.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 32)
        .animation(.easeInOut(duration: 0.2), value: auth.isLoading)
    }
}
