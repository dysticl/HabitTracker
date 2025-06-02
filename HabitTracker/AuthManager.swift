import Foundation
import Security

enum AuthenticationError: Error, LocalizedError {
    case noCredentials
    case keychainError(String)
    case serverError(String)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .noCredentials:
            return "Ungültige Anmeldeinformationen"
        case .keychainError(let message):
            return "Keychain-Fehler: \(message)"
        case .serverError(let message):
            return "Serverfehler: \(message)"
        case .networkError(let error):
            return "Netzwerkfehler: \(error.localizedDescription)"
        }
    }
}

struct LoginResponse: Codable {
    let token: String
    let user: User
    
    struct User: Codable {
        let id: String
        let email: String
        let name: String?
    }
}

class AuthManager {
    static let shared = AuthManager()
    private let baseURL = "https://api.davysgray.com"
    private let apiKey = "your-secret-api-key-1234567890"
    
    private init() {}
    
    func signIn(email: String, password: String) async throws {
        guard !email.isEmpty, !password.isEmpty else {
            throw AuthenticationError.noCredentials
        }
        
        guard let url = URL(string: "\(baseURL)/auth/login") else {
            throw AuthenticationError.serverError("Ungültige URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        
        let body: [String: String] = [
            "email": email,
            "password": password
        ]
        
        request.httpBody = try JSONEncoder().encode(body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw AuthenticationError.serverError("Anmeldung fehlgeschlagen: Status \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            }
            
            let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
            try saveToken(loginResponse.token)
        } catch {
            print("Login error: \(error)")
            throw error is AuthenticationError ? error : AuthenticationError.networkError(error)
        }
    }
    
    func signUp(email: String, password: String, name: String?) async throws {
        guard !email.isEmpty, !password.isEmpty else {
            throw AuthenticationError.noCredentials
        }
        
        guard let url = URL(string: "\(baseURL)/auth/signup") else {
            throw AuthenticationError.serverError("Ungültige URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        
        let body: [String: String?] = [
            "email": email,
            "password": password,
            "name": name
        ]
        
        request.httpBody = try JSONEncoder().encode(body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 else {
                throw AuthenticationError.serverError("Registrierung fehlgeschlagen: Status \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            }
            
            let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
            try saveToken(loginResponse.token)
        } catch {
            print("Signup error: \(error)")
            throw error is AuthenticationError ? error : AuthenticationError.networkError(error)
        }
    }
    
    private func saveToken(_ token: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "authToken",
            kSecValueData as String: token.data(using: .utf8)!
        ]
        
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AuthenticationError.keychainError("Fehler beim Speichern des Tokens: \(status)")
        }
    }
    
    func getToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "authToken",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        return token
    }
    
    func clearToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "authToken"
        ]
        SecItemDelete(query as CFDictionary)
    }
    
    func refreshToken() async throws -> String {
        guard let currentToken = getToken() else {
            throw AuthenticationError.noCredentials
        }
        
        guard let url = URL(string: "\(baseURL)/auth/refresh") else {
            throw AuthenticationError.serverError("Ungültige URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(currentToken)", forHTTPHeaderField: "Authorization")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw AuthenticationError.serverError("Token-Refresh fehlgeschlagen mit Status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            }
            
            let refreshResponse = try JSONDecoder().decode([String: String].self, from: data)
            guard let newToken = refreshResponse["token"] else {
                throw AuthenticationError.serverError("Ungültiges Token-Format")
            }
            
            try saveToken(newToken)
            return newToken
        } catch {
            print("Refresh token error: \(error)")
            throw AuthenticationError.networkError(error)
        }
    }
}
