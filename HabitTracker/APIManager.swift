import Foundation

struct APIHabit: Codable, Identifiable {
    let id: String
    let name: String
    let emoji: String
    let xpPoints: Int
    let isCompleted: Bool
    let progress: Double
    let isRecurring: Bool
    let deadlineDuration: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case emoji
        case xpPoints = "xp_points"
        case isCompleted
        case progress
        case isRecurring
        case deadlineDuration = "deadline_duration"
    }
}

struct APIHabitCreate: Codable {
    let name: String
    let emoji: String
    let xpPoints: Int
    let isCompleted: Bool
    let progress: Double
    let isRecurring: Bool
    let deadlineDuration: Int?
    
    enum CodingKeys: String, CodingKey {
        case name
        case emoji
        case xpPoints = "xp_points"
        case isCompleted
        case progress
        case isRecurring
        case deadlineDuration = "deadline_duration"
    }
}

enum APIError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case serverError(String)
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Ungültige URL"
        case .networkError(let error):
            return "Netzwerkfehler: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Dekodierungsfehler: \(error.localizedDescription)"
        case .serverError(let message):
            return "Serverfehler: \(message)"
        case .unauthorized:
            return "Nicht autorisiert"
        }
    }
}

class APIManager {
    static let shared = APIManager()
    private let baseURL = "https://api.davysgray.com"
    private let apiKey = "your-secret-api-key-1234567890" // TODO: Mit echtem API-Schlüssel ersetzen
    
    private init() {}
    
    func createHabit(_ habit: APIHabitCreate) async throws -> APIHabit {
        guard let url = URL(string: "\(baseURL)/habits") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        
        do {
            let encoder = JSONEncoder()
            let jsonData = try encoder.encode(habit)
            request.httpBody = jsonData
            
            // Debugging: JSON-Payload ausgeben
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("Create habit request body: \(jsonString)")
            }
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.serverError("Ungültige Serverantwort")
            }
            
            print("Create habit response status: \(httpResponse.statusCode)")
            print("Response body: \(String(data: data, encoding: .utf8) ?? "Kein Body")")
            
            guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
                throw APIError.serverError("Erstellen des Habits fehlgeschlagen mit Statuscode: \(httpResponse.statusCode)")
            }
            
            let decoder = JSONDecoder()
            return try decoder.decode(APIHabit.self, from: data)
        } catch {
            print("Create habit error: \(error)")
            throw error is APIError ? error : APIError.networkError(error)
        }
    }
    
    func fetchHabits() async throws -> [APIHabit] {
        guard let url = URL(string: "\(baseURL)/habits") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.serverError("Ungültige Serverantwort")
            }
            
            print("Fetch habits response status: \(httpResponse.statusCode)")
            print("Response body: \(String(data: data, encoding: .utf8) ?? "Kein Body")")
            
            guard httpResponse.statusCode == 200 else {
                if httpResponse.statusCode == 401 {
                    throw APIError.unauthorized
                }
                throw APIError.serverError("Abrufen der Habits fehlgeschlagen mit Statuscode: \(httpResponse.statusCode)")
            }
            
            let decoder = JSONDecoder()
            return try decoder.decode([APIHabit].self, from: data)
        } catch {
            print("Fetch habits error: \(error)")
            throw error is APIError ? error : APIError.networkError(error)
        }
    }
    
    func uploadProof(habitId: String, photoData: Data) async throws -> APIHabit? {
        guard let url = URL(string: "\(baseURL)/habits/\(habitId)/proof") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"proof\"; filename=\"proof.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(photoData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.serverError("Ungültige Serverantwort")
            }
            
            print("Upload proof response status: \(httpResponse.statusCode)")
            print("Response body: \(String(data: data, encoding: .utf8) ?? "Kein Body")")
            
            if httpResponse.statusCode == 204 {
                return nil // Nicht wiederkehrendes Habit wurde gelöscht
            } else if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                return try decoder.decode(APIHabit.self, from: data) // Wiederkehrendes Habit aktualisiert
            } else {
                throw APIError.serverError("Hochladen des Beweises fehlgeschlagen mit Statuscode: \(httpResponse.statusCode)")
            }
        } catch {
            print("Upload proof error: \(error)")
            throw error is APIError ? error : APIError.networkError(error)
        }
    }
    
    func updateHabit(_ habit: APIHabit) async throws -> APIHabit {
        guard let url = URL(string: "\(baseURL)/habits/\(habit.id)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        
        do {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(habit)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.serverError("Ungültige Serverantwort")
            }
            
            print("Update habit response status: \(httpResponse.statusCode)")
            print("Response body: \(String(data: data, encoding: .utf8) ?? "Kein Body")")
            
            guard httpResponse.statusCode == 200 else {
                throw APIError.serverError("Aktualisieren des Habits fehlgeschlagen mit Statuscode: \(httpResponse.statusCode)")
            }
            
            let decoder = JSONDecoder()
            return try decoder.decode(APIHabit.self, from: data)
        } catch {
            print("Update habit error: \(error)")
            throw error is APIError ? error : APIError.networkError(error)
        }
    }
    
    func deleteHabit(id: String) async throws {
        guard let url = URL(string: "\(baseURL)/habits/\(id)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.serverError("Ungültige Serverantwort")
            }
            
            print("Delete habit response status: \(httpResponse.statusCode)")
            print("Response body: \(String(data: data, encoding: .utf8) ?? "Kein Body")")
            
            guard httpResponse.statusCode == 200 || httpResponse.statusCode == 204 else {
                throw APIError.serverError("Löschen des Habits fehlgeschlagen mit Statuscode: \(httpResponse.statusCode)")
            }
        } catch {
            print("Delete habit error: \(error)")
            throw error is APIError ? error : APIError.networkError(error)
        }
    }
}
