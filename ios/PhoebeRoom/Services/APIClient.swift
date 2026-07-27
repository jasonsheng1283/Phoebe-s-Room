import Foundation

enum APIError: LocalizedError {
    case badURL
    case server(String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .badURL: return "接口地址无效"
        case .server(let msg): return msg
        case .decoding(let detail): return "数据解析失败：\(detail)"
        }
    }
}

final class APIClient {
    /// 模拟器默认本机后端；可在 DEBUG 联调条中修改。
    var baseURL: URL = APIConfig.baseURL

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    private let encoder = JSONEncoder()

    func healthCheck() async throws -> Bool {
        let url = baseURL.appendingPathComponent("health")
        let (data, response) = try await URLSession.shared.data(from: url)
        try validate(response)
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        return (obj["status"] as? String) == "ok"
    }

    func fetchKnowledgePoints(subject: String? = nil) async throws -> [KnowledgePoint] {
        var components = URLComponents(url: baseURL.appendingPathComponent("knowledge-points"), resolvingAgainstBaseURL: false)!
        if let subject {
            components.queryItems = [URLQueryItem(name: "subject", value: subject)]
        }
        guard let url = components.url else { throw APIError.badURL }
        let (data, response) = try await URLSession.shared.data(from: url)
        try validate(response)
        return try decoder.decode([KnowledgePoint].self, from: data)
    }

    func startPractice(
        mode: PracticeMode,
        subject: Subject?,
        count: Int,
        familyCode: String,
        knowledgePointIds: [String]? = nil
    ) async throws -> StartPracticeResponse {
        var payload: [String: Any] = [
            "mode": mode.rawValue,
            "count": count,
            "family_code": familyCode,
        ]
        if let subject {
            payload["subject"] = subject.rawValue
        }
        if let knowledgePointIds, !knowledgePointIds.isEmpty {
            payload["knowledge_point_ids"] = knowledgePointIds
        }
        return try await post("practice/start", json: payload, as: StartPracticeResponse.self)
    }

    func submitAnswer(sessionId: String, questionId: String, answer: String, familyCode: String) async throws -> SubmitAnswerResponse {
        try await post(
            "practice/submit",
            json: [
                "session_id": sessionId,
                "question_id": questionId,
                "answer": answer,
                "family_code": familyCode,
            ],
            as: SubmitAnswerResponse.self
        )
    }

    func endPractice(sessionId: String, durationSeconds: Int, familyCode: String) async throws {
        struct OK: Codable { let ok: Bool }
        _ = try await post(
            "practice/end",
            json: [
                "session_id": sessionId,
                "duration_seconds": durationSeconds,
                "family_code": familyCode,
            ],
            as: OK.self
        )
    }

    func parentGate() async throws -> ParentGateChallenge {
        let url = baseURL.appendingPathComponent("parent/gate")
        let (data, response) = try await URLSession.shared.data(from: url)
        try validate(response)
        return try decoder.decode(ParentGateChallenge.self, from: data)
    }

    func verifyParentGate(answer: Int, familyCode: String) async throws {
        struct OK: Codable { let ok: Bool }
        _ = try await post(
            "parent/gate/verify",
            json: ["answer": answer, "family_code": familyCode],
            as: OK.self
        )
    }

    func parentSummary(familyCode: String) async throws -> ParentSummary {
        var components = URLComponents(url: baseURL.appendingPathComponent("parent/summary"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "family_code", value: familyCode)]
        guard let url = components.url else { throw APIError.badURL }
        let (data, response) = try await URLSession.shared.data(from: url)
        try validate(response)
        return try decoder.decode(ParentSummary.self, from: data)
    }

    func generateSimilar(seedQuestionId: String, familyCode: String) async throws -> GenerateSimilarResponse {
        try await post(
            "questions/generate-similar",
            json: [
                "seed_question_id": seedQuestionId,
                "family_code": familyCode,
                "use_llm": false,
            ],
            as: GenerateSimilarResponse.self
        )
    }

    func startSpeaking(count: Int, familyCode: String) async throws -> StartSpeakingResponse {
        try await post(
            "speaking/start",
            json: ["count": count, "family_code": familyCode],
            as: StartSpeakingResponse.self
        )
    }

    func submitSpeakingAudio(
        sessionId: String,
        promptId: String,
        familyCode: String,
        audioData: Data,
        filename: String = "take.m4a",
        mockTranscript: String? = nil
    ) async throws -> SpeakingSubmitResponse {
        let url = baseURL.appendingPathComponent("speaking/submit-audio")
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func appendField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        appendField("session_id", sessionId)
        appendField("prompt_id", promptId)
        appendField("family_code", familyCode)
        if let mockTranscript {
            appendField("mock_transcript", mockTranscript)
        }
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        do {
            return try decoder.decode(SpeakingSubmitResponse.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }

    func endSpeaking(sessionId: String, durationSeconds: Int, familyCode: String) async throws {
        struct OK: Codable { let ok: Bool }
        _ = try await post(
            "speaking/end",
            json: [
                "session_id": sessionId,
                "duration_seconds": durationSeconds,
                "family_code": familyCode,
            ],
            as: OK.self
        )
    }

    func fetchExtensionActivities(grade: Int, familyCode: String) async throws -> [ExtensionActivity] {
        var components = URLComponents(url: baseURL.appendingPathComponent("extension/activities"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "family_code", value: familyCode),
            URLQueryItem(name: "grade", value: String(grade)),
        ]
        guard let url = components.url else { throw APIError.badURL }
        let (data, response) = try await URLSession.shared.data(from: url)
        try validate(response)
        return try decoder.decode([ExtensionActivity].self, from: data)
    }

    func fetchSudokuLevel(grade: Int, level: Int, familyCode: String) async throws -> SudokuLevel {
        var components = URLComponents(url: baseURL.appendingPathComponent("extension/sudoku/level"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "family_code", value: familyCode),
            URLQueryItem(name: "grade", value: String(grade)),
            URLQueryItem(name: "level", value: String(level)),
        ]
        guard let url = components.url else { throw APIError.badURL }
        let (data, response) = try await URLSession.shared.data(from: url)
        try validate(response)
        do {
            return try decoder.decode(SudokuLevel.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }

    func clearSudoku(grade: Int, level: Int, board: [[Int]], familyCode: String) async throws -> SudokuClearResponse {
        try await post(
            "extension/sudoku/clear",
            json: [
                "family_code": familyCode,
                "grade": grade,
                "level": level,
                "board": board,
            ],
            as: SudokuClearResponse.self
        )
    }

    private func post<T: Decodable>(_ path: String, json: [String: Any], as type: T.Type) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: json)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw APIError.server("无响应") }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.server("服务器错误 (\(http.statusCode))")
        }
    }
}
