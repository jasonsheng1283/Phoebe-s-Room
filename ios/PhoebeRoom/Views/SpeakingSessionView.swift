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
        .navigationTitle("口语陪练")
        .task { await bootstrap() }
        .onDisappear {
            speech.stop()
            recorder.reset()
        }
    }

    private var finishedView: some View {
        VStack(spacing: 16) {
            Text("口语练完啦")
                .font(.largeTitle.bold())
            Text("开口本身就很棒。想再听听示范也可以回来继续。")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("结束并记录") {
                Task { await endSession() }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private func promptView(_ prompt: SpeakingPrompt) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("第 \(index + 1) / \(prompts.count) 轮 · \(prompt.isEcho ? "跟读" : "问答")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(prompt.promptText)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                if let hint = prompt.hintZh {
                    Text(hint).foregroundStyle(.secondary)
                }

                Button {
                    speech.speak(prompt.ttsText)
                } label: {
                    Label("听示范", systemImage: "speaker.wave.2.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(RoomTheme.sky.opacity(0.25))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                if feedback == nil {
                    HStack(spacing: 12) {
                        Button {
                            toggleRecord()
                        } label: {
                            Label(recorder.isRecording ? "停止录音" : "开始录音", systemImage: recorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(recorder.isRecording ? RoomTheme.peach : RoomTheme.leaf)

                        Button {
                            try? recorder.playRecording()
                        } label: {
                            Label("回放", systemImage: "play.circle")
                                .padding()
                        }
                        .buttonStyle(.bordered)
                        .disabled(recorder.recordedURL == nil || recorder.isRecording)
                    }

                    Button {
                        Task { await submit(prompt) }
                    } label: {
                        Text(isSubmitting ? "点评中…" : "提交给爸爸听听")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSubmitting || recorder.recordedURL == nil || recorder.isRecording)
                } else if let feedback {
                    VStack(alignment: .leading, spacing: 10) {
                        StarRow(stars: feedback.stars)
                        Text(feedback.feedback)
                        if !feedback.transcript.isEmpty {
                            Text("我听到：\(feedback.transcript)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Button("再听正确示范") {
                            speech.speak(feedback.ttsText)
                        }
                        Button(index + 1 >= prompts.count ? "完成本轮" : "下一题") {
                            advance()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .background(Color.white.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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
