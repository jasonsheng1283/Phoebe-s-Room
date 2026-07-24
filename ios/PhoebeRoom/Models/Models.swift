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
    let speakingAttempts: Int
    let speakingAvgStars: Double
    let speakingSeconds: Int

    enum CodingKeys: String, CodingKey {
        case accuracy
        case totalAttempts = "total_attempts"
        case correctAttempts = "correct_attempts"
        case totalPracticeSeconds = "total_practice_seconds"
        case weakPoints = "weak_points"
        case speakingAttempts = "speaking_attempts"
        case speakingAvgStars = "speaking_avg_stars"
        case speakingSeconds = "speaking_seconds"
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

struct SpeakingPrompt: Identifiable, Codable, Hashable {
    let id: String
    let type: String
    let knowledgePointId: String
    let promptText: String
    let ttsText: String
    let hintZh: String?
    let expectedText: String

    enum CodingKeys: String, CodingKey {
        case id, type
        case knowledgePointId = "knowledge_point_id"
        case promptText = "prompt_text"
        case ttsText = "tts_text"
        case hintZh = "hint_zh"
        case expectedText = "expected_text"
    }

    var isEcho: Bool { type == "echo" }
}

struct StartSpeakingResponse: Codable {
    let sessionId: String
    let prompts: [SpeakingPrompt]

    enum CodingKeys: String, CodingKey {
        case prompts
        case sessionId = "session_id"
    }
}

struct SpeakingSubmitResponse: Codable {
    let transcript: String
    let stars: Int
    let masteryStars: Int
    let feedback: String
    let expectedText: String
    let ttsText: String
    let knowledgePointId: String
    let sttSource: String
    let similarity: Double

    enum CodingKeys: String, CodingKey {
        case transcript, stars, feedback, similarity
        case masteryStars = "mastery_stars"
        case expectedText = "expected_text"
        case ttsText = "tts_text"
        case knowledgePointId = "knowledge_point_id"
        case sttSource = "stt_source"
    }
}
