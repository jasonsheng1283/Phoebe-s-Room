import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var selectedSubject: Subject? = nil
    @Published var knowledgePoints: [KnowledgePoint] = []
    @Published var isLoading = false
    @Published var lastError: String?
    @Published var parentUnlocked = false

    let api = APIClient()
    let familyCode = "phoebe-home"

    func refreshKnowledgePoints(subject: Subject? = nil) async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        do {
            knowledgePoints = try await api.fetchKnowledgePoints(subject: subject?.rawValue)
        } catch {
            lastError = error.localizedDescription
        }
    }
}

enum Subject: String, CaseIterable, Identifiable, Codable {
    case math
    case english

    var id: String { rawValue }

    var title: String {
        switch self {
        case .math: return "数学"
        case .english: return "英语"
        }
    }
}

enum PracticeMode: String, CaseIterable, Identifiable, Codable {
    case review
    case weak
    case habit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .review: return "课后巩固"
        case .weak: return "薄弱专项"
        case .habit: return "日常习惯"
        }
    }

    var subtitle: String {
        switch self {
        case .review: return "把最近学的再练一遍"
        case .weak: return "专攻星级较低的知识点"
        case .habit: return "每天一小会儿，轻轻坚持"
        }
    }
}
