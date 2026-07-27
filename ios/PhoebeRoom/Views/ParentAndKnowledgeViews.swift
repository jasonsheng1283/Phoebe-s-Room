import SwiftUI

struct KnowledgeListView: View {
    @EnvironmentObject private var appState: AppState
    let subject: Subject?

    var body: some View {
        ZStack {
            RoomBackground(showDecor: false)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if !upperPoints.isEmpty {
                        sectionHeader("上册")
                        ForEach(upperPoints) { kp in
                            knowledgeCard(kp)
                        }
                    }
                    if !lowerPoints.isEmpty {
                        sectionHeader("下册")
                        ForEach(lowerPoints) { kp in
                            knowledgeCard(kp)
                        }
                    }
                    if !otherPoints.isEmpty {
                        sectionHeader(otherSectionTitle)
                        ForEach(otherPoints) { kp in
                            knowledgeCard(kp)
                        }
                    }
                }
                .padding(20)
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

    private var upperPoints: [KnowledgePoint] {
        filtered.filter { $0.semester == "upper" }
    }

    private var lowerPoints: [KnowledgePoint] {
        filtered.filter { $0.semester == "lower" }
    }

    private var otherPoints: [KnowledgePoint] {
        filtered.filter { $0.semester != "upper" && $0.semester != "lower" }
    }

    private var otherSectionTitle: String {
        if subject == .english { return "英语" }
        if subject == nil, upperPoints.isEmpty, lowerPoints.isEmpty { return "全部" }
        return "其他"
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(RoomTheme.ink.opacity(0.5))
            .padding(.top, 6)
    }

    @ViewBuilder
    private func knowledgeCard(_ kp: KnowledgePoint) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(kp.name)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(RoomTheme.ink)
                HStack(spacing: 8) {
                    Text(kp.subject == "math" ? "数学" : "英语")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RoomTheme.mint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(RoomTheme.mint.opacity(0.15))
                        .clipShape(Capsule())
                    if let label = kp.semesterLabel, subject == nil {
                        Text(label)
                            .font(.caption)
                            .foregroundStyle(RoomTheme.ink.opacity(0.45))
                    }
                    if !kp.hasQuestions {
                        Text("待练习")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            Spacer()
            if kp.hasQuestions {
                StarRow(stars: kp.stars)
            } else {
                Text("内容筹备中")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .background(RoomTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: RoomTheme.cornerMedium, style: .continuous))
        .shadow(color: RoomTheme.softShadow, radius: 6, y: 3)
        .opacity(kp.hasQuestions ? 1 : 0.72)
    }
}

struct ParentGateView: View {
    @EnvironmentObject private var appState: AppState
    @State private var challenge: ParentGateChallenge?
    @State private var answerText = ""
    @State private var errorMessage: String?
    @State private var unlocked = false

    var body: some View {
        ZStack {
            RoomBackground(showDecor: false)
            Group {
                if unlocked || appState.parentUnlocked {
                    ParentSummaryView()
                } else {
                    VStack(spacing: 20) {
                        Text("家长区")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(RoomTheme.ink)
                        Text("轻轻算一算，再进来看进度。")
                            .font(.subheadline)
                            .foregroundStyle(RoomTheme.ink.opacity(0.5))
                        Text(challenge?.prompt ?? "加载中…")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(RoomTheme.ink)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(RoomTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: RoomTheme.cornerMedium, style: .continuous))
                        TextField("答案", text: $answerText)
                            .keyboardType(.numberPad)
                            .padding()
                            .background(RoomTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: RoomTheme.cornerSmall, style: .continuous))
                            .frame(maxWidth: 240)
                        if let errorMessage {
                            Text(errorMessage).foregroundStyle(RoomTheme.softWarn)
                        }
                        RoomPrimaryButton(title: "进入", tint: RoomTheme.sky) {
                            Task { await verify() }
                        }
                        .frame(maxWidth: 240)
                    }
                    .padding(28)
                    .task { await loadGate() }
                }
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
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let summary {
                    summaryCard("总览", rows: [
                        ("作答次数", "\(summary.totalAttempts)"),
                        ("正确次数", "\(summary.correctAttempts)"),
                        ("正确率", String(format: "%.0f%%", summary.accuracy * 100)),
                        ("练习时长", "\(summary.totalPracticeSeconds / 60) 分"),
                    ])
                    summaryCard("口语陪练", rows: [
                        ("口语次数", "\(summary.speakingAttempts)"),
                        ("平均星级", String(format: "%.1f", summary.speakingAvgStars)),
                        ("口语时长", "\(summary.speakingSeconds / 60) 分"),
                    ])
                    summaryCard("头脑拓展", rows: [
                        ("符号数独最高关", "\(summary.extensionSudokuLevel)"),
                    ])

                    VStack(alignment: .leading, spacing: 10) {
                        Text("需要关注的知识点")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(RoomTheme.ink)
                        if summary.weakPoints.isEmpty {
                            Text("还没有足够练习数据")
                                .foregroundStyle(RoomTheme.ink.opacity(0.5))
                        } else {
                            ForEach(summary.weakPoints) { kp in
                                HStack {
                                    Text(kp.name)
                                        .foregroundStyle(RoomTheme.ink)
                                    Spacer()
                                    StarRow(stars: kp.stars)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoomTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: RoomTheme.cornerMedium, style: .continuous))
                } else if let errorMessage {
                    Text(errorMessage).foregroundStyle(RoomTheme.softWarn)
                } else {
                    ProgressView()
                }
            }
            .padding(20)
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

    private func summaryCard(_ title: String, rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(RoomTheme.ink)
            ForEach(rows, id: \.0) { row in
                HStack {
                    Text(row.0).foregroundStyle(RoomTheme.ink.opacity(0.55))
                    Spacer()
                    Text(row.1).fontWeight(.semibold).foregroundStyle(RoomTheme.ink)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoomTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: RoomTheme.cornerMedium, style: .continuous))
        .shadow(color: RoomTheme.softShadow, radius: 5, y: 2)
    }
}
