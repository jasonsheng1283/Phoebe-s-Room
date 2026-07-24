import SwiftUI

struct KnowledgeListView: View {
    @EnvironmentObject private var appState: AppState
    let subject: Subject?

    var body: some View {
        List {
            ForEach(filtered) { kp in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(kp.name).font(.headline)
                        Text(kp.subject == "math" ? "数学" : "英语")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    StarRow(stars: kp.stars)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("知识点星级")
        .task {
            await appState.refreshKnowledgePoints(subject: subject)
        }
        .overlay {
            if appState.isLoading {
                ProgressView()
            }
        }
    }

    private var filtered: [KnowledgePoint] {
        guard let subject else { return appState.knowledgePoints }
        return appState.knowledgePoints.filter { $0.subject == subject.rawValue }
    }
}

struct ParentGateView: View {
    @EnvironmentObject private var appState: AppState
    @State private var challenge: ParentGateChallenge?
    @State private var answerText = ""
    @State private var errorMessage: String?
    @State private var unlocked = false

    var body: some View {
        Group {
            if unlocked || appState.parentUnlocked {
                ParentSummaryView()
            } else {
                VStack(spacing: 20) {
                    Text("家长区")
                        .font(.largeTitle.bold())
                    Text(challenge?.prompt ?? "加载中…")
                        .font(.title2)
                    TextField("答案", text: $answerText)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 200)
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                    Button("进入") {
                        Task { await verify() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .task { await loadGate() }
            }
        }
        .navigationTitle("家长")
    }

    private func loadGate() async {
        do {
            challenge = try await appState.api.parentGate()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func verify() async {
        guard let value = Int(answerText.trimmingCharacters(in: .whitespaces)) else {
            errorMessage = "请输入数字"
            return
        }
        do {
            try await appState.api.verifyParentGate(answer: value, familyCode: appState.familyCode)
            appState.parentUnlocked = true
            unlocked = true
        } catch {
            errorMessage = "门禁未通过"
        }
    }
}

struct ParentSummaryView: View {
    @EnvironmentObject private var appState: AppState
    @State private var summary: ParentSummary?
    @State private var errorMessage: String?

    var body: some View {
        List {
            if let summary {
                Section("总览") {
                    LabeledContent("作答次数", value: "\(summary.totalAttempts)")
                    LabeledContent("正确次数", value: "\(summary.correctAttempts)")
                    LabeledContent("正确率", value: String(format: "%.0f%%", summary.accuracy * 100))
                    LabeledContent("练习时长", value: "\(summary.totalPracticeSeconds / 60) 分")
                }
                Section("需要关注的知识点") {
                    if summary.weakPoints.isEmpty {
                        Text("还没有足够练习数据")
                    } else {
                        ForEach(summary.weakPoints) { kp in
                            HStack {
                                Text(kp.name)
                                Spacer()
                                StarRow(stars: kp.stars)
                            }
                        }
                    }
                }
            } else if let errorMessage {
                Text(errorMessage)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("学习摘要")
        .task {
            do {
                summary = try await appState.api.parentSummary(familyCode: appState.familyCode)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
