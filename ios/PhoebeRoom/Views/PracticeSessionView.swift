import SwiftUI

struct PracticeSessionView: View {
    @EnvironmentObject private var appState: AppState
    let subject: Subject
    let mode: PracticeMode

    @StateObject private var speech = SpeechService()
    @State private var sessionId: String?
    @State private var questions: [Question] = []
    @State private var index = 0
    @State private var selectedOption: String?
    @State private var typedAnswer = ""
    @State private var feedback: SubmitAnswerResponse?
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    @State private var startedAt = Date()
    @State private var showHandwriting = false

    var body: some View {
        Group {
            if let errorMessage {
                ContentUnavailableView("暂时没法开始", systemImage: "wifi.exclamationmark", description: Text(errorMessage))
            } else if questions.isEmpty {
                ProgressView("正在准备题目…")
            } else if index >= questions.count {
                sessionDone
            } else {
                questionPage(questions[index])
            }
        }
        .padding()
        .navigationTitle(mode.title)
        .task { await start() }
        .onDisappear { speech.stop() }
    }

    private var sessionDone: some View {
        VStack(spacing: 16) {
            Text("这一轮练完啦")
                .font(.largeTitle.bold())
            Text("去看看星级有没有亮起来吧。")
                .foregroundStyle(.secondary)
            Button("结束并记录时长") {
                Task { await endSession() }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private func questionPage(_ question: Question) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("第 \(index + 1) / \(questions.count) 题")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(question.stem)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))

                if question.isAudioQuestion, let tts = question.ttsText {
                    Button {
                        speech.speak(tts)
                    } label: {
                        Label("播放发音", systemImage: "speaker.wave.2.fill")
                            .font(.title3)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(RoomTheme.sky.opacity(0.25))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }

                if !question.options.isEmpty {
                    ForEach(question.options, id: \.self) { option in
                        Button {
                            selectedOption = option
                        } label: {
                            HStack {
                                Text(option).font(.title2)
                                Spacer()
                                if selectedOption == option {
                                    Image(systemName: "checkmark.circle.fill")
                                }
                            }
                            .padding()
                            .background(selectedOption == option ? RoomTheme.leaf.opacity(0.18) : Color.white.opacity(0.9))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(feedback != nil)
                    }
                }

                if question.needsTextInput {
                    TextField("输入答案", text: $typedAnswer)
                        .textFieldStyle(.roundedBorder)
                        .font(.title)
                        .keyboardType(.numbersAndPunctuation)
                        .disabled(feedback != nil)
                    Toggle("用手写帮忙", isOn: $showHandwriting)
                        .disabled(feedback != nil)
                    if showHandwriting {
                        HandwritingAnswerPanel(confirmedText: $typedAnswer)
                    }
                }

                if let feedback {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(feedback.isCorrect ? "答对啦！" : "差一点点")
                            .font(.title2.bold())
                            .foregroundStyle(feedback.isCorrect ? RoomTheme.leaf : RoomTheme.peach)
                        Text("正确答案：\(feedback.correctAnswer)")
                        Text(feedback.explanation)
                            .font(.body)
                        StarRow(stars: feedback.stars)
                        Button(index + 1 >= questions.count ? "完成本轮" : "下一题") {
                            advance()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .background(Color.white.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                } else {
                    Button {
                        Task { await submit(question) }
                    } label: {
                        Text(isSubmitting ? "批改中…" : "提交")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSubmitting || currentAnswer(for: question).isEmpty)
                }
            }
        }
    }

    private func currentAnswer(for question: Question) -> String {
        if !question.options.isEmpty {
            return selectedOption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
        return typedAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func start() async {
        do {
            let count = mode == .habit ? 4 : 5
            let resp = try await appState.api.startPractice(
                mode: mode,
                subject: subject,
                count: count,
                familyCode: appState.familyCode
            )
            sessionId = resp.sessionId
            questions = resp.questions
            startedAt = Date()
        } catch {
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

    private func advance() {
        feedback = nil
        selectedOption = nil
        typedAnswer = ""
        showHandwriting = false
        index += 1
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
