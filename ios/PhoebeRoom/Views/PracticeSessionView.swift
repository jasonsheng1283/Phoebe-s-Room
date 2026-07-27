import SwiftUI

struct PracticeSessionView: View {
    @EnvironmentObject private var appState: AppState
    let subject: Subject
    let mode: PracticeMode
    var knowledgePointIds: [String] = []

    @StateObject private var speech = SpeechService()
    @State private var sessionId: String?
    @State private var questions: [Question] = []
    @State private var index = 0
    @State private var selectedOption: String?
    @State private var dragSortIds: [String] = []
    @State private var placeAssignments: [String: String] = [:]
    @State private var feedback: SubmitAnswerResponse?
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    @State private var isLoading = true
    @State private var startedAt = Date()
    @State private var showHandwritingDraft = false
    @State private var loadGeneration = 0
    @State private var cancelRetries = 0
    @AppStorage("phoebe.diagram.lookHintSeen") private var diagramLookHintSeen = false
    @State private var showDiagramLookHint = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// Keep diagram compact so options stay reachable (esp. landscape iPad).
    private var diagramHeight: CGFloat {
        let landscape = verticalSizeClass == .compact
        if landscape { return 120 }
        return horizontalSizeClass == .regular ? 148 : 156
    }

    private var diagramMaxWidth: CGFloat {
        horizontalSizeClass == .regular ? 520 : .infinity
    }

    var body: some View {
        ZStack {
            RoomBackground(showDecor: false)
            Group {
                if let errorMessage {
                    VStack(spacing: 16) {
                        ContentUnavailableView(
                            "暂时没法开始",
                            systemImage: "wifi.exclamationmark",
                            description: Text(errorMessage)
                        )
                        RoomPrimaryButton(title: "再试一次") {
                            Task { await start(force: true) }
                        }
                        .padding(.horizontal, 40)
                    }
                } else if isLoading {
                    ProgressView("正在准备题目…")
                        .font(.headline)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if questions.isEmpty {
                    VStack(spacing: 16) {
                        ContentUnavailableView(
                            "还没有题目",
                            systemImage: "tray",
                            description: Text("这个知识点暂时没有可练的题，换一个试试。")
                        )
                        RoomPrimaryButton(title: "再试一次") {
                            Task { await start(force: true) }
                        }
                        .padding(.horizontal, 40)
                    }
                } else if index >= questions.count {
                    sessionDone
                } else {
                    questionPage(questions[index])
                }
            }
            .padding()
        }
        .navigationTitle(mode.title)
        .onAppear {
            Task { await start() }
        }
        .onDisappear { speech.stop() }
    }

    private var sessionDone: some View {
        VStack(spacing: 20) {
            RoomStarBurst(
                title: "这一轮练完啦",
                subtitle: "去看看星级有没有亮起来吧。"
            )
            RoomPrimaryButton(title: "结束并记录时长") {
                Task { await endSession() }
            }
            .padding(.horizontal, 48)
        }
    }

    @ViewBuilder
    private func questionPage(_ question: Question) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                RoomProgressPips(current: index + 1, total: questions.count)

                Text(question.stem)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(RoomTheme.ink)

                if let diagram = question.diagram, diagram.isSupported {
                    if showDiagramLookHint {
                        Text("先看图，再选答案")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(RoomTheme.ink.opacity(0.55))
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    QuestionDiagramView(
                        diagram: diagram,
                        height: diagramHeight,
                        showAmbienceBadge: !(question.imageAsset ?? "").isEmpty
                    )
                    .frame(maxWidth: diagramMaxWidth)
                    .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    QuestionImageView(assetName: question.imageAsset, height: diagramHeight + 12)
                        .frame(maxWidth: diagramMaxWidth)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                if question.isAudioQuestion, let tts = question.ttsText {
                    Button {
                        speech.speak(tts)
                    } label: {
                        Label("播放发音", systemImage: "speaker.wave.2.fill")
                            .font(.title3.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: RoomTheme.touchMin)
                    }
                    .buttonStyle(RoomSecondaryButtonStyle(tint: RoomTheme.sky))
                }

                answerArea(question)
                    .padding(.top, 8)

                if subject == .math {
                    Toggle("打开手写草稿", isOn: $showHandwritingDraft)
                        .tint(RoomTheme.mint)
                        .disabled(feedback != nil)
                    if showHandwritingDraft {
                        HandwritingDraftPanel()
                    }
                }

                if let feedback {
                    RoomFeedbackCard(
                        isCorrect: feedback.isCorrect,
                        title: feedback.isCorrect ? "答对啦！" : "差一点点",
                        explanation: feedback.explanation,
                        correctAnswerLine: "正确答案：\(friendlyCorrectAnswer(feedback.correctAnswer, question: question))"
                    )
                    StarRow(stars: feedback.stars)
                    RoomPrimaryButton(title: index + 1 >= questions.count ? "完成本轮" : "下一题") {
                        advance(preparing: index + 1 < questions.count ? questions[index + 1] : nil)
                    }
                } else {
                    RoomPrimaryButton(
                        title: isSubmitting ? "批改中…" : "提交",
                        disabled: isSubmitting || currentAnswer(for: question).isEmpty
                    ) {
                        Task { await submit(question) }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 24)
        }
    }

    @ViewBuilder
    private func answerArea(_ question: Question) -> some View {
        if question.isTrueFalse {
            TrueFalseAnswerView(selected: $selectedOption, disabled: feedback != nil)
        } else if question.isDragSort {
            if let items = question.interaction?.items, !items.isEmpty {
                Text("用箭头调整顺序")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RoomTheme.ink.opacity(0.55))
                DragSortAnswerView(items: items, orderedIds: $dragSortIds, disabled: feedback != nil)
            } else {
                incompleteInteraction("排序题数据不完整")
            }
        } else if question.isDragPlace {
            if let interaction = question.interaction,
               let tokens = interaction.tokens,
               let slots = interaction.slots,
               !tokens.isEmpty,
               !slots.isEmpty
            {
                DragPlaceAnswerView(
                    scene: interaction.scene ?? "angles_three_v1",
                    backgroundAsset: interaction.backgroundAsset,
                    tokens: tokens,
                    slots: slots,
                    assignments: $placeAssignments,
                    disabled: feedback != nil
                )
            } else {
                incompleteInteraction("拖放题数据不完整")
            }
        } else if !question.options.isEmpty {
            VStack(spacing: 12) {
                ForEach(question.options, id: \.self) { option in
                    RoomOptionChip(
                        title: option,
                        isSelected: selectedOption == option,
                        disabled: feedback != nil
                    ) {
                        selectedOption = option
                    }
                }
            }
        } else {
            incompleteInteraction("还不支持题型：\(question.type)")
        }
    }

    private func incompleteInteraction(_ message: String) -> some View {
        Text(message)
            .font(.body)
            .foregroundStyle(RoomTheme.ink.opacity(0.55))
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoomTheme.lemon.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: RoomTheme.cornerSmall, style: .continuous))
    }

    private func currentAnswer(for question: Question) -> String {
        if question.isDragSort {
            return dragSortIds.joined(separator: ",")
        }
        if question.isDragPlace {
            guard !placeAssignments.isEmpty,
                  let data = try? JSONSerialization.data(withJSONObject: placeAssignments),
                  let text = String(data: data, encoding: .utf8)
            else { return "" }
            return text
        }
        return selectedOption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func friendlyCorrectAnswer(_ raw: String, question: Question) -> String {
        if question.isDragSort, let items = question.interaction?.items {
            let labels = raw.split(separator: ",").compactMap { id in
                items.first(where: { $0.id == id.trimmingCharacters(in: .whitespaces) })?.label
            }
            if !labels.isEmpty { return labels.joined(separator: " → ") }
        }
        if question.isDragPlace, let data = raw.data(using: .utf8),
           let map = try? JSONSerialization.jsonObject(with: data) as? [String: String],
           let slots = question.interaction?.slots,
           let tokens = question.interaction?.tokens
        {
            let parts = slots.compactMap { slot -> String? in
                guard let tokenId = map[slot.id],
                      let token = tokens.first(where: { $0.id == tokenId })
                else { return nil }
                return "\(slot.label)：\(token.label)"
            }
            if !parts.isEmpty { return parts.joined(separator: "；") }
        }
        return raw
    }

    private func prepareInteraction(for question: Question) {
        if question.isDragSort {
            dragSortIds = question.interaction?.items?.map(\.id) ?? []
        }
        if question.isDragPlace {
            placeAssignments = [:]
        }
        selectedOption = nil
        maybeShowDiagramHint(for: question)
    }

    private func maybeShowDiagramHint(for question: Question) {
        guard let diagram = question.diagram, diagram.isSupported, !diagramLookHintSeen else {
            showDiagramLookHint = false
            return
        }
        showDiagramLookHint = true
        diagramLookHintSeen = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            withAnimation(.easeOut(duration: 0.35)) {
                showDiagramLookHint = false
            }
        }
    }

    private func start(force: Bool = false) async {
        if !force, loadGeneration > 0, (!questions.isEmpty || errorMessage != nil) {
            return
        }
        loadGeneration += 1
        let generation = loadGeneration
        isLoading = true
        errorMessage = nil
        defer {
            if generation == loadGeneration {
                isLoading = false
            }
        }
        do {
            let count = mode == .habit ? 4 : 5
            let resp = try await appState.api.startPractice(
                mode: mode,
                subject: subject,
                count: count,
                familyCode: appState.familyCode,
                knowledgePointIds: knowledgePointIds.isEmpty ? nil : knowledgePointIds
            )
            guard generation == loadGeneration else { return }
            sessionId = resp.sessionId
            questions = resp.questions
            index = 0
            startedAt = Date()
            if let first = resp.questions.first {
                prepareInteraction(for: first)
            }
        } catch is CancellationError {
            guard generation == loadGeneration else { return }
            if questions.isEmpty, cancelRetries < 2 {
                cancelRetries += 1
                try? await Task.sleep(nanoseconds: 150_000_000)
                await start(force: true)
            }
        } catch {
            guard generation == loadGeneration else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func submit(_ question: Question) async {
        guard let sessionId else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            feedback = try await appState.api.submitAnswer(
                sessionId: sessionId,
                questionId: question.id,
                answer: currentAnswer(for: question),
                familyCode: appState.familyCode
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func advance(preparing next: Question?) {
        feedback = nil
        selectedOption = nil
        dragSortIds = []
        placeAssignments = [:]
        showHandwritingDraft = false
        index += 1
        if let next {
            prepareInteraction(for: next)
        }
    }

    private func endSession() async {
        guard let sessionId else { return }
        let seconds = Int(Date().timeIntervalSince(startedAt))
        try? await appState.api.endPractice(
            sessionId: sessionId,
            durationSeconds: seconds,
            familyCode: appState.familyCode
        )
    }
}
