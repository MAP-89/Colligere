import Foundation
import UIKit
import FirebaseAuth
import FirebaseFirestore
import AuthenticationServices
import GoogleSignIn
import CryptoKit

@Observable
final class AuthService {
    var currentUser: FirebaseAuth.User? = nil
    var isLoading = false
    var errorMessage: String?

    // Persisted so the sign-in screen stays dismissed across launches
    var hasSkippedSignIn: Bool = UserDefaults.standard.bool(forKey: "hasSkippedSignIn") {
        didSet { UserDefaults.standard.set(hasSkippedSignIn, forKey: "hasSkippedSignIn") }
    }

    private(set) var currentNonce = ""
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor [weak self] in
                self?.currentUser = user
            }
        }
    }

    var isSignedIn: Bool { currentUser != nil }

    // MARK: - Sign in with Apple

    /// Returns the SHA-256-hashed nonce to embed in the Apple ID request.
    func prepareAppleSignIn() -> String {
        let nonce = randomNonce()
        currentNonce = nonce
        return sha256(nonce)
    }

    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            guard case .success(let auth) = result else {
                if case .failure(let error) = result { throw error }
                return
            }
            guard let appleIDCredential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = appleIDCredential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                throw AuthError.invalidCredential
            }

            let credential = OAuthProvider.credential(
                providerID: AuthProviderID.apple,
                idToken: idToken,
                rawNonce: currentNonce
            )

            let authResult = try await Auth.auth().signIn(with: credential)
            try await syncUserDocument(for: authResult.user, appleCredential: appleIDCredential)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Sign in with Google

    func handleGoogleSignIn() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            guard let presenting = topViewController() else {
                throw AuthError.noPresentingController
            }
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenting)
            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthError.invalidCredential
            }
            let accessToken = result.user.accessToken.tokenString

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: accessToken
            )
            let authResult = try await Auth.auth().signIn(with: credential)
            try await syncUserDocument(for: authResult.user)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })
              ?? (UIApplication.shared.connectedScenes.first as? UIWindowScene),
              let window = scene.keyWindow ?? scene.windows.first
        else { return nil }
        var top = window.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }

    // MARK: - Guest / Sign-out

    func skipSignIn() {
        hasSkippedSignIn = true
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        try? Auth.auth().signOut()
        hasSkippedSignIn = false
    }

    // MARK: - Firestore user document

    private func syncUserDocument(
        for user: FirebaseAuth.User,
        appleCredential: ASAuthorizationAppleIDCredential? = nil
    ) async throws {
        let db = Firestore.firestore()
        let ref = db.collection("users").document(user.uid)
        let snapshot = try await ref.getDocument()

        if !snapshot.exists {
            var displayName = user.displayName ?? ""
            if displayName.isEmpty, let name = appleCredential?.fullName {
                displayName = PersonNameComponentsFormatter().string(from: name)
            }
            try await ref.setData([
                "uid": user.uid,
                "displayName": displayName,
                "email": user.email ?? "",
                "createdAt": Timestamp(date: Date()),
                "lastActiveAt": Timestamp(date: Date()),
                "projectIDs": [String](),
                "collaborativeProjectIDs": [String]()
            ])
        } else {
            try await ref.updateData(["lastActiveAt": Timestamp(date: Date())])
        }
    }

    // MARK: - Nonce helpers

    private func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }

    enum AuthError: LocalizedError {
        case invalidCredential
        case noPresentingController
        var errorDescription: String? {
            switch self {
            case .invalidCredential: "Could not read sign-in credential."
            case .noPresentingController: "Couldn't present the sign-in screen."
            }
        }
    }
}
