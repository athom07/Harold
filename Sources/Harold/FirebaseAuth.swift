import Security
import SwiftUI

struct FirebaseSession: Codable {
    let localId: String
    let email: String
    let refreshToken: String
}

struct FirebaseAuthAPI {
    var session: URLSession = .shared

    enum Failure: LocalizedError {
        case rejected(String)
        case response
        case storage

        var invalidSession: Bool {
            guard case let .rejected(code) = self else { return false }
            return ["TOKEN_EXPIRED", "INVALID_REFRESH_TOKEN", "USER_NOT_FOUND", "USER_DISABLED"].contains(code)
        }

        var errorDescription: String? {
            switch self {
            case let .rejected(code):
                switch code {
                case "EMAIL_EXISTS": "An account already exists for this email."
                case "INVALID_EMAIL": "Enter a valid email address."
                case "OPERATION_NOT_ALLOWED": "Enable Email/Password sign-in in your Firebase project."
                case "WEAK_PASSWORD", "PASSWORD_DOES_NOT_MEET_REQUIREMENTS": "Choose a password that meets your Firebase project’s password policy."
                case "EMAIL_NOT_FOUND", "INVALID_PASSWORD", "INVALID_LOGIN_CREDENTIALS":
                    "The email or password is incorrect."
                case "USER_DISABLED": "This account has been disabled."
                case "TOO_MANY_ATTEMPTS_TRY_LATER": "Too many attempts. Try again later."
                case "API_KEY_INVALID", "PROJECT_NUMBER_MISMATCH": "Check the Web API key for your Firebase project."
                default: "Firebase couldn’t complete the request. Try again."
                }
            case .response: "Firebase returned an unexpected response."
            case .storage: "Harold couldn’t update your account in macOS Keychain."
            }
        }
    }

    private struct ErrorPayload: Decodable {
        struct Detail: Decodable { let message: String }
        let error: Detail
    }

    private struct RefreshResponse: Decodable {
        let refresh_token: String
        let user_id: String
    }

    func authenticate(email: String, password: String, creating: Bool, key: String) async throws -> FirebaseSession {
        let route = creating ? "accounts:signUp" : "accounts:signInWithPassword"
        let data = try await accountRequest(
            route, key: key, body: ["email": email, "password": password, "returnSecureToken": true]
        )
        guard let account = try? JSONDecoder().decode(FirebaseSession.self, from: data),
              !account.localId.isEmpty, !account.refreshToken.isEmpty else { throw Failure.response }
        return account
    }

    func sendReset(email: String, key: String) async throws {
        do {
            _ = try await accountRequest("accounts:sendOobCode", key: key, body: ["requestType": "PASSWORD_RESET", "email": email])
        } catch Failure.rejected("EMAIL_NOT_FOUND") {
            // Use the same acknowledgment for both existing and unknown addresses.
        }
    }

    func refresh(_ account: FirebaseSession, key: String) async throws -> FirebaseSession {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        let encoded = account.refreshToken.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        let data = try await post(
            host: "securetoken.googleapis.com", path: "/v1/token", key: key,
            type: "application/x-www-form-urlencoded", body: Data("grant_type=refresh_token&refresh_token=\(encoded)".utf8)
        )
        guard let response = try? JSONDecoder().decode(RefreshResponse.self, from: data),
              response.user_id == account.localId, !response.refresh_token.isEmpty else { throw Failure.response }
        return FirebaseSession(localId: account.localId, email: account.email, refreshToken: response.refresh_token)
    }

    private func accountRequest(_ route: String, key: String, body: [String: Any]) async throws -> Data {
        try await post(
            host: "identitytoolkit.googleapis.com", path: "/v1/\(route)", key: key,
            type: "application/json", body: JSONSerialization.data(withJSONObject: body)
        )
    }

    private func post(host: String, path: String, key: String, type: String, body: Data) async throws -> Data {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path
        components.queryItems = [URLQueryItem(name: "key", value: key)]
        guard let url = components.url else { throw Failure.response }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 25)
        request.httpMethod = "POST"
        request.setValue(type, forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let (data, reply) = try await session.data(for: request)
        guard let reply = reply as? HTTPURLResponse else { throw Failure.response }
        guard (200..<300).contains(reply.statusCode) else {
            let code = try? JSONDecoder().decode(ErrorPayload.self, from: data).error.message
            // Some errors include validation details after the reason.
            throw Failure.rejected(code?.components(separatedBy: " : ").first ?? "")
        }
        return data
    }
}

@MainActor
final class Account: ObservableObject {
    @Published private(set) var apiKey = UserDefaults.standard.string(forKey: Account.keyPreference) ?? ""
    @Published private(set) var user: FirebaseSession?
    @Published private(set) var busy = false
    @Published private(set) var error: String?
    @Published private(set) var notice: String?

    private static let keyPreference = "harold.firebaseWebAPIKey"
    private let api = FirebaseAuthAPI()
    private var attemptedRestore = false

    func configure(_ incoming: String) {
        guard !busy, user == nil else { return }
        let key = incoming.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.contains(where: \.isWhitespace), key.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil else {
            error = "Enter your Firebase project’s Web API key."
            return
        }
        if key != apiKey {
            do {
                try AccountKeychain.save(nil)
            } catch {
                self.error = error.localizedDescription
                return
            }
        }
        apiKey = key
        UserDefaults.standard.set(key, forKey: Self.keyPreference)
        clearMessage()
    }

    func disconnect() {
        guard !busy, user == nil else { return }
        do {
            try AccountKeychain.save(nil)
            apiKey = ""
            UserDefaults.standard.removeObject(forKey: Self.keyPreference)
            clearMessage()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func restore() async {
        guard !attemptedRestore else { return }
        attemptedRestore = true
        guard !apiKey.isEmpty, let saved = AccountKeychain.load() else { return }
        await run {
            do {
                let restored = try await api.refresh(saved, key: apiKey)
                try AccountKeychain.save(restored)
                user = restored
            } catch let failure as FirebaseAuthAPI.Failure where failure.invalidSession {
                try AccountKeychain.save(nil)
            }
        }
    }

    func authenticate(email: String, password: String, creating: Bool) async {
        guard !apiKey.isEmpty, user == nil, !password.isEmpty else { return }
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        await run {
            let signedIn = try await api.authenticate(email: email, password: password, creating: creating, key: apiKey)
            try AccountKeychain.save(signedIn)
            user = signedIn
        }
    }

    func reset(email: String) async {
        guard !apiKey.isEmpty, user == nil else { return }
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        await run {
            try await api.sendReset(email: email, key: apiKey)
            notice = "If an account exists for this email, Firebase will send a reset link."
        }
    }

    func signOut() {
        guard !busy else { return }
        do {
            try AccountKeychain.save(nil)
            user = nil
            clearMessage()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func clearMessage() {
        error = nil
        notice = nil
    }

    private func run(_ action: () async throws -> Void) async {
        guard !busy else { return }
        clearMessage()
        busy = true
        defer { busy = false }
        do {
            try await action()
        } catch {
            self.error = if let failure = error as? URLError {
                switch failure.code {
                case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost:
                    "Connect to the internet and try again."
                case .timedOut: "Firebase took too long to respond. Try again."
                default: "Couldn’t reach Firebase. Try again."
                }
            } else {
                error.localizedDescription
            }
        }
    }
}

private enum AccountKeychain {
    private static let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "app.harold.research",
        kSecAttrAccount as String: "firebase-session",
    ]

    static func load() -> FirebaseSession? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(FirebaseSession.self, from: data)
    }

    static func save(_ session: FirebaseSession?) throws {
        guard let session else {
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else { throw FirebaseAuthAPI.Failure.storage }
            return
        }

        let payload = [kSecValueData as String: try JSONEncoder().encode(session)]
        let status = SecItemUpdate(query as CFDictionary, payload as CFDictionary)
        if status == errSecItemNotFound {
            let item = query.merging(payload) { _, value in value }
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw FirebaseAuthAPI.Failure.storage }
        } else if status != errSecSuccess {
            throw FirebaseAuthAPI.Failure.storage
        }
    }
}
