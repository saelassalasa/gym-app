import Foundation
import UIKit

// MARK: - Gemini API Service
// Handles image-to-workout parsing using Gemini Vision API

actor GeminiService {
    static let shared = GeminiService()
    
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"
    
    // MARK: - API Key Management

    private static let keyLock = NSLock()

    nonisolated static var apiKey: String? {
        get {
            keyLock.lock()
            defer { keyLock.unlock() }
            if let key = KeychainManager.get(forKey: "gemini_api_key") { return key }
            // One-time migration from UserDefaults
            if let legacy = UserDefaults.standard.string(forKey: "gemini_api_key"), !legacy.isEmpty {
                if KeychainManager.set(legacy, forKey: "gemini_api_key") {
                    UserDefaults.standard.removeObject(forKey: "gemini_api_key")
                }
                return legacy
            }
            return nil
        }
        set {
            keyLock.lock()
            defer { keyLock.unlock() }
            if let val = newValue { KeychainManager.set(val, forKey: "gemini_api_key") }
            else { KeychainManager.delete(forKey: "gemini_api_key") }
        }
    }

    nonisolated static func hasAPIKey() -> Bool {
        apiKey?.isEmpty == false
    }
    
    // MARK: - Parse Workout Image
    
    func parseWorkoutImage(_ image: UIImage) async throws -> ParsedWorkoutProgram {
        guard let apiKey = GeminiService.apiKey, !apiKey.isEmpty else {
            throw GeminiError.noAPIKey
        }
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw GeminiError.imageConversionFailed
        }
        
        let base64Image = imageData.base64EncodedString()
        
        let request = try buildRequest(apiKey: apiKey, base64Image: base64Image)
        
        let (data, response) = try await URLSession.shared.data(for: request)

        // Cap response size to prevent OOM from malicious/oversized responses
        let maxBytes = 512 * 1024
        guard data.count <= maxBytes else {
            throw GeminiError.parsingFailed("Response too large (\(data.count) bytes)")
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw GeminiError.apiError(statusCode: httpResponse.statusCode)
        }

        return try parseResponse(data)
    }
    
    // MARK: - Request Building
    
    private func buildRequest(apiKey: String, base64Image: String) throws -> URLRequest {
        guard let url = URL(string: baseURL) else {
            throw GeminiError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        
        let prompt = """
        Parse this workout schedule image into JSON. Extract all workout days, exercises, sets, reps, and any notes.
        
        Return ONLY valid JSON in this exact format (no markdown, no explanation):
        {
          "programName": "string (infer from image or use 'Imported Program')",
          "days": [
            {
              "name": "string (day name like 'Monday', 'Push', 'Day 1')",
              "exercises": [
                {
                  "name": "string (exercise name)",
                  "sets": number (default 3 if unclear),
                  "reps": number (default 8 if unclear),
                  "notes": "string (RIR, RPE, tempo, etc. or empty)"
                }
              ]
            }
          ]
        }
        
        If you cannot parse the image, return: {"error": "description of issue"}
        """
        
        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt],
                        [
                            "inline_data": [
                                "mime_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.1,
                "maxOutputTokens": 1024
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }
    
    // MARK: - Response Parsing
    
    private func parseResponse(_ data: Data) throws -> ParsedWorkoutProgram {
        // Parse Gemini response structure
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw GeminiError.parsingFailed("Invalid Gemini response structure")
        }
        
        // Clean up response (remove markdown code blocks if present)
        let cleanedText = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let jsonData = cleanedText.data(using: .utf8) else {
            throw GeminiError.parsingFailed("Cannot convert response to data")
        }
        
        // Check for error response
        if let errorJson = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
           let errorMessage = errorJson["error"] as? String {
            throw GeminiError.parsingFailed(errorMessage)
        }
        
        // Decode the workout program
        let decoder = JSONDecoder()
        return try decoder.decode(ParsedWorkoutProgram.self, from: jsonData)
    }
}

// MARK: - Parsed Workout Models

struct ParsedWorkoutProgram: Codable {
    let programName: String
    let days: [ParsedWorkoutDay]
}

struct ParsedWorkoutDay: Codable {
    let name: String
    let exercises: [ParsedExercise]
}

struct ParsedExercise: Codable {
    let name: String
    let sets: Int
    let reps: Int
    let notes: String?
}

// MARK: - Errors

enum GeminiError: LocalizedError {
    case noAPIKey
    case imageConversionFailed
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int)
    case parsingFailed(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "API key not configured. Go to Settings to add your Gemini API key."
        case .imageConversionFailed:
            return "Failed to process image."
        case .invalidURL:
            return "Invalid API URL."
        case .invalidResponse:
            return "Invalid response from server."
        case .apiError(let code):
            switch code {
            case 401, 403: return "API key invalid or quota exceeded."
            case 429:      return "Rate limit hit. Try again later."
            case 500...599: return "Gemini server error. Try again."
            default:       return "Request failed (HTTP \(code))."
            }
        case .parsingFailed(let reason):
            return "Failed to parse workout: \(reason)"
        }
    }
}
