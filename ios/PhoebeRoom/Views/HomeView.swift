import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            HomeView()
        }
        .tint(RoomTheme.leaf)
    }
}

struct HomeView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [RoomTheme.cream, RoomTheme.sky.opacity(0.35)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Phoebe's Room")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundStyle(RoomTheme.ink)
                        Text("爸爸和朋友陪你练一练。做题，也能开口说英语。")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 12)

                    HStack(spacing: 16) {
                        ForEach(Subject.allCases) { subject in
                            NavigationLink(value: subject) {
                                SubjectCard(subject: subject)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    NavigationLink {
                        SpeakingSessionView()
                    } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("口语陪练")
                                .font(.system(size: 32, weight: .semibold, design: .rounded))
                            Text("跟读 · 少量问答 · 鼓励与星级")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(RoomTheme.ink)
                        .padding(24)
                        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(RoomTheme.peach.opacity(0.22))
                                .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        KnowledgeListView(subject: nil)
                    } label: {
                        Label("看看我的星级", systemImage: "star.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(RoomTheme.leaf.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }

                    NavigationLink {
                        ParentGateView()
                    } label: {
                        Label("家长区", systemImage: "lock.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(28)
            }
        }
        .navigationDestination(for: Subject.self) { subject in
            ModePickerView(subject: subject)
        }
        .navigationTitle("学习空间")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SubjectCard: View {
    let subject: Subject

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(subject.title)
                .font(.system(size: 32, weight: .semibold, design: .rounded))
            Text(subject == .math ? "选择 · 填空 · 应用题" : "拼读 · 听力")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(RoomTheme.ink)
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.85))
                .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
        )
    }
}

struct ModePickerView: View {
    let subject: Subject

    var body: some View {
        List {
            ForEach(PracticeMode.allCases) { mode in
                NavigationLink {
                    PracticeSessionView(subject: subject, mode: mode)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(mode.title).font(.headline)
                        Text(mode.subtitle).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .navigationTitle(subject.title)
    }
}
