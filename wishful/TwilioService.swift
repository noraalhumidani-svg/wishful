import Foundation

struct TwilioConfig {
    let accountSID: String
    let authToken: String
    let verifySID: String

    // Load credentials from TwilioConfig.plist (not committed to source control).
    static func fromPlist() -> TwilioConfig {
        guard
            let url = Bundle.main.url(forResource: "TwilioConfig", withExtension: "plist"),
            let dict = NSDictionary(contentsOf: url) as? [String: String],
            let accountSID = dict["AccountSID"],
            let authToken = dict["AuthToken"],
            let verifySID = dict["VerifySID"]
        else {
            fatalError("TwilioConfig.plist is missing or malformed — see TwilioConfig.plist.example")
        }
        return TwilioConfig(accountSID: accountSID, authToken: authToken, verifySID: verifySID)
    }
}

struct TwilioService {
    private let config: TwilioConfig

    init(config: TwilioConfig = .fromPlist()) {
        self.config = config
    }

    private var baseURL: String {
        "https://verify.twilio.com/v2/Services/\(config.verifySID)"
    }

    // Encodes + as %2B so Twilio receives the E.164 leading + intact.
    // Standard urlQueryAllowed leaves + unescaped; form-decoding then treats it
    // as a space, causing 966... to arrive instead of +966...
    private func formEncode(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private func makeRequest(path: String, body: [String: String]) -> URLRequest {
        let url = URL(string: "\(baseURL)/\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let credentials = "\(config.accountSID):\(config.authToken)"
        let encoded = Data(credentials.utf8).base64EncodedString()
        request.setValue("Basic \(encoded)", forHTTPHeaderField: "Authorization")

        request.httpBody = body
            .map { "\(formEncode($0.key))=\(formEncode($0.value))" }
            .joined(separator: "&")
            .data(using: .utf8)

        return request
    }

    func sendOTP(to phoneNumber: String) async throws {
        let request = makeRequest(path: "Verifications", body: [
            "To": phoneNumber,
            "Channel": "sms"
        ])
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw TwilioError.sendFailed
        }
    }

    func verifyOTP(phoneNumber: String, code: String) async throws -> Bool {
        let request = makeRequest(path: "VerificationCheck", body: [
            "To": phoneNumber,
            "Code": code
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw TwilioError.verifyFailed
        }
        let json = try JSONDecoder().decode(VerificationCheckResponse.self, from: data)
        return json.status == "approved"
    }
}

enum TwilioError: Error {
    case sendFailed
    case verifyFailed
}

private struct VerificationCheckResponse: Decodable {
    let status: String
}
