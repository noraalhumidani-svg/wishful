//
//  TwilioService.swift
//  WishsApp
//
//  Created by Nora Abdullah Alhumaydani on 19/08/1447 AH.
//

import Foundation

class TwilioService {
    static let shared = TwilioService()

    private let accountSID = TwilioCredentials.accountSID
    private let authToken  = TwilioCredentials.authToken
    private let verifySID  = TwilioCredentials.verifySID

    // MARK: - Format Phone Number
    private func formatPhoneNumber(_ phoneNumber: String) -> String {
        var phone = phoneNumber.trimmingCharacters(in: .whitespaces)

        if phone.hasPrefix("+") {
            phone = String(phone.dropFirst())
        }
        if phone.hasPrefix("966") {
            phone = String(phone.dropFirst(3))
        }

        return "+966" + phone
    }

    // Encodes + as %2B so the E.164 leading + survives form-decoding on the server.
    // URLComponents.percentEncodedQuery leaves + unencoded; servers treat it as a space.
    private func formEncode(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    // MARK: - Send OTP
    func sendOTP(to phoneNumber: String, completion: @escaping (Bool, String) -> Void) {
        let fullPhone = formatPhoneNumber(phoneNumber)

        print("📱 Sending to: \(fullPhone)")

        let urlString = "https://verify.twilio.com/v2/Services/\(verifySID)/Verifications"
        guard let url = URL(string: urlString) else {
            completion(false, "Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let authData = "\(accountSID):\(authToken)".data(using: .utf8)
        let base64Auth = authData?.base64EncodedString() ?? ""
        request.setValue("Basic \(base64Auth)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = "To=\(formEncode(fullPhone))&Channel=sms"
        print("📤 Body: \(body)")
        request.httpBody = body.data(using: .utf8)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error: \(error.localizedDescription)")
                    completion(false, error.localizedDescription)
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    print("📊 Code: \(httpResponse.statusCode)")
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        print("📝 Response: \(responseString)")
                    }

                    if httpResponse.statusCode == 201 {
                        print("✅ OTP sent!")
                        completion(true, fullPhone)
                        return
                    }
                }

                completion(false, "Failed")
            }
        }.resume()
    }

    // MARK: - Verify OTP
    func verifyOTP(to phoneNumber: String, code: String, completion: @escaping (Bool, String) -> Void) {
        let fullPhone = formatPhoneNumber(phoneNumber)

        print("📱 Verifying: \(fullPhone) with code: \(code)")

        let urlString = "https://verify.twilio.com/v2/Services/\(verifySID)/VerificationCheck"
        guard let url = URL(string: urlString) else {
            completion(false, "Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let authData = "\(accountSID):\(authToken)".data(using: .utf8)
        let base64Auth = authData?.base64EncodedString() ?? ""
        request.setValue("Basic \(base64Auth)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = "To=\(formEncode(fullPhone))&Code=\(formEncode(code))"
        print("📤 Body: \(body)")
        request.httpBody = body.data(using: .utf8)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error: \(error.localizedDescription)")
                    completion(false, error.localizedDescription)
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    print("📊 Code: \(httpResponse.statusCode)")
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        print("📝 Response: \(responseString)")
                    }

                    if httpResponse.statusCode == 200 {
                        print("✅ Verified!")
                        completion(true, "Verified")
                        return
                    }
                }

                completion(false, "Invalid code")
            }
        }.resume()
    }
}
