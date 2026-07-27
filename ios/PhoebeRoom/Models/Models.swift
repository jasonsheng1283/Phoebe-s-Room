import Foundation

struct KnowledgePoint: Identifiable, Codable, Hashable {
    let id: String
    let subject: String
    let name: String
    let prerequisites: [String]
    let semester: String?
    let sortOrder: Int
    let hasQuestions: Bool
    let stars: Int
    let correctCount: Int
    let attemptCount: Int

    enum CodingKeys: String, CodingKey {
        case id, subject, name, prerequisites, semester, stars
        case sortOrder = "sort_order"
        case hasQuestions = "has_questions"
        case correctCount = "correct_count"
        case attemptCount = "attempt_count"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        subject = try c.decode(String.self, forKey: .subject)
        name = try c.decode(String.self, forKey: .name)
        prerequisites = try c.decodeIfPresent([String].self, forKey: .prerequisites) ?? []
        semester = try c.decodeIfPresent(String.self, forKey: .semester)
        sortOrder = try c.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        hasQuestions = try c.decodeIfPresent(Bool.self, forKey: .hasQuestions) ?? true
        stars = try c.decodeIfPresent(Int.self, forKey: .stars) ?? 0
        correctCount = try c.decodeIfPresent(Int.self, forKey: .correctCount) ?? 0
        attemptCount = try c.decodeIfPresent(Int.self, forKey: .attemptCount) ?? 0
    }

    var semesterLabel: String? {
        switch semester {
        case "upper": return "上册"
        case "lower": return "下册"
        default: return nil
        }
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
    let interaction: QuestionInteraction?
    let imageAsset: String?
    let diagram: DiagramSpec?

    enum CodingKeys: String, CodingKey {
        case id, subject, type, stem, options, difficulty, interaction, diagram
        case knowledgePointId = "knowledge_point_id"
        case ttsText = "tts_text"
        case imageAsset = "image_asset"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        subject = try c.decode(String.self, forKey: .subject)
        knowledgePointId = try c.decode(String.self, forKey: .knowledgePointId)
        type = try c.decode(String.self, forKey: .type)
        stem = try c.decode(String.self, forKey: .stem)
        options = try c.decodeIfPresent([String].self, forKey: .options) ?? []
        ttsText = try c.decodeIfPresent(String.self, forKey: .ttsText)
        difficulty = try c.decodeIfPresent(Int.self, forKey: .difficulty) ?? 1
        interaction = try c.decodeIfPresent(QuestionInteraction.self, forKey: .interaction)
        imageAsset = try c.decodeIfPresent(String.self, forKey: .imageAsset)
        diagram = try c.decodeIfPresent(DiagramSpec.self, forKey: .diagram)
    }

    var isTrueFalse: Bool { type == "true_false" }
    var isDragSort: Bool { type == "drag_sort" }
    var isDragPlace: Bool { type == "drag_place" }
    var isChoiceLike: Bool { type == "choice" || type == "phonics" || type == "listening" || isTrueFalse }

    var isAudioQuestion: Bool {
        type == "listening" || type == "phonics"
    }
}

struct QuestionInteraction: Codable, Hashable {
    let kind: String
    let items: [InteractionItem]?
    let scene: String?
    let backgroundAsset: String?
    let tokens: [InteractionItem]?
    let slots: [InteractionSlot]?

    enum CodingKeys: String, CodingKey {
        case kind, items, scene, tokens, slots
        case backgroundAsset = "background_asset"
    }
}

struct DiagramSpec: Codable, Hashable {
    let kind: String
    let anglesDeg: [Double]?
    let highlightIndex: Int?
    let labels: [String]?
    let shape: String?
    let axis: String?
    let showAxis: Bool?
    let object: String?
    let view: String?
    let highlightFace: Bool?

    enum CodingKeys: String, CodingKey {
        case kind, labels, shape, axis, object, view
        case anglesDeg = "angles_deg"
        case highlightIndex = "highlight_index"
        case showAxis = "show_axis"
        case highlightFace = "highlight_face"
    }

    var isSupported: Bool {
        ["angles", "symmetry", "observe"].contains(kind)
    }
}

struct InteractionItem: Codable, Hashable, Identifiable {
    let id: String
    let label: String
}

struct InteractionSlot: Codable, Hashable, Identifiable {
    let id: String
    let label: String
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
    let extensionSudokuLevel: Int

    enum CodingKeys: String, CodingKey {
        case accuracy
        case totalAttempts = "total_attempts"
        case correctAttempts = "correct_attempts"
        case totalPracticeSeconds = "total_practice_seconds"
        case weakPoints = "weak_points"
        case speakingAttempts = "speaking_attempts"
        case speakingAvgStars = "speaking_avg_stars"
        case speakingSeconds = "speaking_seconds"
        case extensionSudokuLevel = "extension_sudoku_level"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        totalAttempts = try c.decodeIfPresent(Int.self, forKey: .totalAttempts) ?? 0
        correctAttempts = try c.decodeIfPresent(Int.self, forKey: .correctAttempts) ?? 0
        accuracy = try c.decodeIfPresent(Double.self, forKey: .accuracy) ?? 0
        totalPracticeSeconds = try c.decodeIfPresent(Int.self, forKey: .totalPracticeSeconds) ?? 0
        weakPoints = try c.decodeIfPresent([KnowledgePoint].self, forKey: .weakPoints) ?? []
        speakingAttempts = try c.decodeIfPresent(Int.self, forKey: .speakingAttempts) ?? 0
        speakingAvgStars = try c.decodeIfPresent(Double.self, forKey: .speakingAvgStars) ?? 0
        speakingSeconds = try c.decodeIfPresent(Int.self, forKey: .speakingSeconds) ?? 0
        extensionSudokuLevel = try c.decodeIfPresent(Int.self, forKey: .extensionSudokuLevel) ?? 0
    }
}

struct ExtensionActivity: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let kind: String
    let grades: [Int]
    let enabled: Bool
    let highestClearedLevel: Int
    let nextLevel: Int

    enum CodingKeys: String, CodingKey {
        case id, title, subtitle, kind, grades, enabled
        case highestClearedLevel = "highest_cleared_level"
        case nextLevel = "next_level"
    }
}

struct SudokuSymbol: Identifiable, Codable, Hashable {
    let id: Int
    let glyph: String
    let name: String
}

struct SudokuTheme: Codable, Hashable {
    let id: String
    let label: String
    let symbols: [SudokuSymbol]
}

struct SudokuLevel: Codable, Hashable {
    let activityId: String
    let grade: Int
    let level: Int
    let size: Int
    let box: Int
    let theme: SudokuTheme
    let givens: [[Int?]]
    let clueCount: Int

    enum CodingKeys: String, CodingKey {
        case grade, level, size, box, theme, givens
        case activityId = "activity_id"
        case clueCount = "clue_count"
    }
}

struct SudokuClearResponse: Codable {
    let ok: Bool
    let highestClearedLevel: Int
    let nextLevel: Int

    enum CodingKeys: String, CodingKey {
        case ok
        case highestClearedLevel = "highest_cleared_level"
        case nextLevel = "next_level"
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
