import SwiftUI

struct SpeakingSessionView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var speech = SpeechService()
    @StateObject private var recorder = AudioRecorder()

    @State private var sessionId: String?
    @State private var prompts: [SpeakingPrompt] = []
    @State private var index = 0
    @State private var feedback: SpeakingSubmitResponse?
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    @State private var startedAt = Date()
    @State private var micDenied = false

    var body: some View {
        ZStack {
            RoomBackground(showDecor: false)
            Group {
                if micDenied {
                    ContentUnavailableView(
                        "需要麦克风",
                        systemImage: "mic.slash",
                        description: Text("请在设置里允许 Phoebe's Room 使用麦克风，才能练口语。")
                    )
                } else if let errorMessage {
                    ContentUnavailableView("暂时没法开始", systemImage: "wifi.exclamationmark", description: Text(errorMessage))
                } else if prompts.isEmpty {
                    ProgressView("正在准备口语陪练…")
                } else if index >= prompts.count {
                    finishedView
                } else {
                    promptView(prompts[index])
                }
            }
            .padding()
        }
        .navigationTitle("口语陪练")
        .task { await bootstrap() }
        .onDisappear {
            speech.stop()
            recorder.reset()
        }
    }

    private var finishedView: some View {
        VStack(spacing: 20) {
            RoomStarBurst(
                title: "口语练完啦",
                subtitle: "开口本身就很棒。想再听听示范也可以回来继续。"
            )
            RoomPrimaryButton(title: "结束并记录") {
                Task { await endSession() }
            }
            .padding(.horizontal, 48)
        }
    }

    @ViewBuilder
    private func promptView(_ prompt: SpeakingPrompt) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                RoomProgressPips(current: index + 1, total: prompts.count)
                Text(prompt.isEcho ? "跟读" : "问答")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(RoomTheme.candy)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(RoomTheme.candy.opacity(0.2))
                    .clipShape(Capsule())

                Text(prompt.promptText)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(RoomTheme.ink)
                if let hint = prompt.hintZh {
                    Text(hint)
                        .foregroundStyle(RoomTheme.ink.opacity(0.55))
                }

                QuestionImageView(assetName: "decor_speaking", height: 96, cornerRadius: 20)

                Button {
                    speech.speak(prompt.ttsText)
                } label: {
                    Label("听示范", systemImage: "speaker.wave.2.fill")
                        .frame(maxWidth: .infinity, minHeight: RoomTheme.touchMin)
                }
                .buttonStyle(RoomSecondaryButtonStyle(tint: RoomTheme.sky))

                if feedback == nil {
                    HStack(spacing: 12) {
                        Button {
                            toggleRecord()
                        } label: {
                            Label(
                                recorder.isRecording ? "停止录音" : "开始录音",
                                systemImage: recorder.isRecording ? "stop.circle.fill" : "mic.circle.fill"
                            )
                            .frame(maxWidth: .infinity, minHeight: RoomTheme.touchMin)
                        }
                        .buttonStyle(RoomPrimaryButtonStyle(
                            tint: recorder.isRecording ? RoomTheme.softWarn : RoomTheme.mint
                        ))

                        Button {
                            try? recorder.playRecording()
                        } label: {
                            Label("回放", systemImage: "play.circle")
                                .frame(minHeight: RoomTheme.touchMin)
                                .padding(.horizontal, 12)
                        }
                        .buttonStyle(RoomSecondaryButtonStyle(tint: RoomTheme.lemon))
                        .disabled(recorder.recordedURL == nil || recorder.isRecording)
                    }

                    RoomPrimaryButton(
                        title: isSubmitting ? "点评中…" : "提交给爸爸听听",
                        disabled: isSubmitting || recorder.recordedURL == nil || recorder.isRecording
                    ) {
                        Task { await submit(prompt) }
                    }
                } else if let feedback {
                    VStack(alignment: .leading, spacing: 12) {
                        StarRow(stars: feedback.stars)
                        Text(feedback.feedback)
                            .foregroundStyle(RoomTheme.ink)
                        if !feedback.transcript.isEmpty {
                            Text("我听到：\(feedback.transcript)")
                                .font(.subheadline)
                                .foregroundStyle(RoomTheme.ink.opacity(0.55))
                        }
                        Button("再听正确示范") {
                            speech.speak(feedback.ttsText)
                        }
                        .buttonStyle(RoomSecondaryButtonStyle(tint: RoomTheme.sky))
                        RoomPrimaryButton(title: index + 1 >= prompts.count ? "完成本轮" : "下一题") {
                            advance()
                        }
                    }
                    .padding(16)
                    .background(RoomTheme.mint.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: RoomTheme.cornerMedium, style: .continuous))
                }
            }
        }
    }

    private func bootstrap() async {
        let allowed = await recorder.requestPermission()
        if !allowed {
            micDenied = true
            return
        }
        do {
            let resp = try await appState.api.startSpeaking(count: 6, familyCode: appState.familyCode)
            sessionId = resp.sessionId
            prompts = resp.prompts
            startedAt = Date()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleRecord() {
        do {
            if recorder.isRecording {
                recorder.stop()
            } else {
                feedback = nil
                try recorder.start()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func submit(_ prompt: SpeakingPrompt) async {
        guard let sessionId else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let data = try recorder.audioData()
            feedback = try await appState.api.submitSpeakingAudio(
                sessionId: sessionId,
                promptId: prompt.id,
                familyCode: appState.familyCode,
                audioData: data
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func advance() {
        feedback = nil
        recorder.reset()
        index += 1
    }

    private func endSession() async {
        guard let sessionId else { return }
        let seconds = Int(Date().timeIntervalSince(startedAt))
        try? await appState.api.endSpeaking(
            sessionId: sessionId,
            durationSeconds: seconds,
            familyCode: appState.familyCode
        )
    }
}
