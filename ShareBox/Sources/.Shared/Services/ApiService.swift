//
//  ApiService.swift
//  ShareBox
//
//  Created by Thom van den Broek on 31/05/2025.
//

import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}

enum APIError: Error {
    case invalidURL
    case invalidResponse
    case decodingError(Error)
    case networkError(Error)
    case serverError(Int, ErrorResponse)
    case unauthorized
    case unknown
}

class ApiService {
    // MARK: - Properties

    private let baseURL: String
    private let session: URLSession

    // MARK: - Initialization

    init(baseURL: String = (Bundle.main.object(forInfoDictionaryKey: "BASE_URL") as? String ?? "https://shareboxed.app"), session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    // MARK: - Generic Request Method

    func request<T: Decodable>( // swiftlint:disable:this cyclomatic_complexity function_body_length
        endpoint: String,
        method: HTTPMethod = .get,
        parameters: [String: Any?]? = nil,
        headers: [String: String]? = nil,
        multipartData: [(String, Data, String)]? = nil // swiftlint:disable:this large_tuple
    ) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue

        // Add auth token if available
        if let authToken = Keychain.shared.fetchToken(key: "AccessToken") {
            request.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }

        // Add headers
        headers?.forEach { request.addValue($0.value, forHTTPHeaderField: $0.key) }

        let cfClientId = Bundle.main.object(forInfoDictionaryKey: "CF_ACCESS_CLIENT_ID")
        let cfClientSecret = Bundle.main.object(forInfoDictionaryKey: "CF_ACCESS_CLIENT_SECRET")

        if let clientId = cfClientId as? String, let clientSecret = cfClientSecret as? String {
            request.addValue(clientId, forHTTPHeaderField: "CF-Access-Client-Id")
            request.addValue(clientSecret, forHTTPHeaderField: "CF-Access-Client-Secret")
        }

        // Handle multipart form data
        if let multipartData = multipartData {
            let boundary = "Boundary-\(UUID().uuidString)"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

            var body = Data()

            // Add parameters as form fields
            if let parameters = parameters {
                for (key, value) in parameters {
                    body.append(Data("--\(boundary)\r\n".utf8))
                    body.append(Data("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".utf8))
                    body.append(Data("\(value ?? "")\r\n".utf8))
                }
            }

            // Add multipart data
            for (key, data, mimeType) in multipartData {
                body.append(Data("--\(boundary)\r\n".utf8))
                body.append(Data("Content-Disposition: form-data; name=\"\(key)\"; filename=\"\(key)\"\r\n".utf8))
                body.append(Data("Content-Type: \(mimeType)\r\n\r\n".utf8))
                body.append(data)
                body.append(Data("\r\n".utf8))
            }

            body.append(Data("--\(boundary)--\r\n".utf8))
            request.httpBody = body
        } else if let parameters = parameters {
            // Handle regular JSON parameters
            if method == .get {
                var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
                components?.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value != nil ? "\($0.value!)" : nil) }
                request.url = components?.url
            } else {
                request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            switch httpResponse.statusCode {
            case 200 ... 299:
                do {
                    return try JSONDecoder().decode(T.self, from: data)
                } catch {
                    // If the decoder fails, i want to print the data
                    #if DEBUG
                        print("Failed to decode the following JSON body:")
                        print(String(data: data, encoding: .utf8) ?? "No data")
                    #endif
                    throw APIError.decodingError(error)
                }
            case 401:
                // If we failed to authorize, we will re-authorize with refresh token
                Keychain.shared.deleteToken(key: "AccessToken")
                if endpoint == "/api/auth/token" {
                    Keychain.shared.deleteToken(key: "RefreshToken")
                    User.shared?.signOut()
                    throw APIError.unauthorized
                }
                if let refreshToken = Keychain.shared.fetchToken(key: "RefreshToken") {
                    do {
                        let res: TokenResponse = try await self.request(endpoint: "/api/auth/token", method: .post, parameters: [
                            "refreshToken": refreshToken
                        ])
                        // If we have been authorized we update tokens
                        Keychain.shared.saveToken(res.accessToken, key: "AccessToken")
                        Keychain.shared.saveToken(res.refreshToken, key: "RefreshToken")
                        // Re-run the original query
                        return try await self.request(endpoint: endpoint, method: method, parameters: parameters, headers: headers, multipartData: multipartData)
                    } catch {
                        throw APIError.unauthorized
                    }
                } else {
                    throw APIError.unauthorized
                }
            case 400 ... 499:
                #if DEBUG
                print(String(data: data, encoding: .utf8) ?? "No data")
                #endif
                throw APIError.serverError(httpResponse.statusCode, try JSONDecoder().decode(ErrorResponse.self, from: data))
            case 500 ... 599:
                #if DEBUG
                print(String(data: data, encoding: .utf8) ?? "No data")
                #endif
                throw APIError.serverError(httpResponse.statusCode, try JSONDecoder().decode(ErrorResponse.self, from: data))
            default:
                throw APIError.unknown
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }

    // MARK: - Convenience Methods
    func get<T: Decodable>(endpoint: String, parameters: [String: Any]? = nil) async throws -> T {
        try await request(endpoint: endpoint, method: .get, parameters: parameters)
    }

    func post<T: Decodable>(
        endpoint: String,
        parameters: [String: Any?]? = nil,
        multipartData: [(String, Data, String)]? = nil // swiftlint:disable:this large_tuple
    ) async throws -> T {
        try await request(endpoint: endpoint, method: .post, parameters: parameters, multipartData: multipartData)
    }

    func put<T: Decodable>(
        endpoint: String,
        parameters: [String: Any?]? = nil,
        multipartData: [(String, Data, String)]? = nil // swiftlint:disable:this large_tuple
    ) async throws -> T {
        try await request(endpoint: endpoint, method: .put, parameters: parameters, multipartData: multipartData)
    }

    func patch<T: Decodable>(
        endpoint: String,
        parameters: [String: Any?]? = nil,
        multipartData: [(String, Data, String)]? = nil // swiftlint:disable:this large_tuple
    ) async throws -> T {
        try await request(endpoint: endpoint, method: .patch, parameters: parameters, multipartData: multipartData)
    }

    func delete<T: Decodable>(endpoint: String, parameters: [String: Any?]? = nil) async throws -> T {
        try await request(endpoint: endpoint, method: .delete, parameters: parameters)
    }

    // MARK: - Subclasses
    struct BasicSuccessResponse: Codable {
        var success: Bool
    }

    struct BasicRedirectResponse: Codable {
        var redirectUrl: String
    }
}

public struct TokenResponse: Codable {
    var accessToken: String
    var refreshToken: String
}

public struct ErrorResponse: Codable {
    var error: String
}
