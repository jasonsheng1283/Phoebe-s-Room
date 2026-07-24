import Foundation

struct KnowledgePoint: Identifiable, Codable, Hashable {
    let id: String
    let subject: String
    let name: String
    let prerequisites: [String]
    let stars: Int
    let correctCount: Int
    let attemptCount: Int

    enum CodingKeys: String, CodingKey {
        case id, subject, name, prerequisites, stars
        case correctCount = "correct_count"
        case attemptCount = "attempt_count"
    }
}

struct Question: Identifiable, Codable, Hashable {
    let id: String
    let subject: String
    let knowledgePointId: String
    let type: String
    let stem: String
    let options: [String]
    let ttsText: String?
    let difficulty: Int

    enum CodingKeys: String, CodingKey {
        case id, subject, type, stem, options, difficulty
        case knowledgePointId = "knowledge_point_id"
        case ttsText = "tts_text"
    }

    var needsTextInput: Bool {
        type == "fill" || type == "word_problem"
    }

    var isAudioQuestion: Bool {
        type == "listening" || type == "phonics"
    }
}

struct StartPracticeResponse: Codable {
    let sessionId: String
    let mode: String
    let subject: String?
    let questions: [Question]

    enum CodingKeys: String, CodingKey {
        case mode, subject, questions
        case sessionId = "session_id"
    }
}

struct SubmitAnswerResponse: Codable {
    let isCorrect: Bool
    let correctAnswer: String
    let explanation: String
    let stars: Int
    let knowledgePointId: String

    enum CodingKeys: String, CodingKey {
        case explanation, stars
        case isCorrect = "is_correct"
        case correctAnswer = "correct_answer"
        case knowledgePointId = "knowledge_point_id"
    }
}

struct ParentSummary: Codable {
    let totalAttempts: Int
    let correctAttempts: Int
    let accuracy: Double
    let totalPracticeSeconds: Int
    let weakPoints: [KnowledgePoint]

    enum CodingKeys: String, CodingKey {
        case accuracy
        case totalAttempts = "total_attempts"
        case correctAttempts = "correct_attempts"
        case totalPracticeSeconds = "total_practice_seconds"
        case weakPoints = "weak_points"
    }
}

struct ParentGateChallenge: Codable {
    let prompt: String
    let a: Int
    let b: Int
}

struct GenerateSimilarResponse: Codable {
    let accepted: Bool
    let reason: String
}
