import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            HomeView()
        }
        .tint(RoomTheme.mint)
    }
}

struct HomeView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            RoomBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Phoebe's Room")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundStyle(RoomTheme.ink)
                        Text("阳光小房间里，爸爸和朋友陪你练一练。")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(RoomTheme.ink.opacity(0.55))
                    }
                    .padding(.top, 8)

                    #if DEBUG
                    DevServerBanner()
                    #endif

                    HStack(spacing: 16) {
                        ForEach(Subject.allCases) { subject in
                            NavigationLink(value: subject) {
                                RoomEntryCard(
                                    title: subject.title,
                                    subtitle: subject == .math ? "选择 · 判断 · 拖一拖" : "拼读 · 听力",
                                    tint: subject == .math ? RoomTheme.mint : RoomTheme.sky,
                                    systemImage: subject == .math ? "plus.forwardslash.minus" : "textformat.abc"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    NavigationLink {
                        SpeakingSessionView()
                    } label: {
                        RoomEntryCard(
                            title: "口语陪练",
                            subtitle: "跟读 · 少量问答 · 鼓励与星级",
                            tint: RoomTheme.candy,
                            systemImage: "mic.fill",
                            assetName: "decor_speaking"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        ExtensionHubView()
                    } label: {
                        RoomEntryCard(
                            title: "头脑拓展",
                            subtitle: "符号数独过关 · 不绑课本单元",
                            tint: RoomTheme.lilac,
                            systemImage: "square.grid.3x3.fill",
                            assetName: "decor_sudoku"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        KnowledgeListView(subject: nil)
                    } label: {
                        Label("看看我的星级", systemImage: "star.circle.fill")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(RoomTheme.ink)
                            .frame(maxWidth: .infinity, minHeight: RoomTheme.touchMin)
                            .background(RoomTheme.lemon.opacity(0.45))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        ParentGateView()
                    } label: {
                        Label("家长区", systemImage: "lock.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(RoomTheme.ink.opacity(0.45))
                    }
                }
                .padding(28)
            }
        }
        .navigationDestination(for: Subject.self) { subject in
            KnowledgePickerView(subject: subject)
        }
        .navigationTitle("学习空间")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct KnowledgePickerView: View {
    @EnvironmentObject private var appState: AppState
    let subject: Subject

    @State private var selectAll = true
    @State private var selectedIds: Set<String> = []

    var body: some View {
        ZStack {
            RoomBackground(showDecor: false)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    selectAllCard
                    if !upperPoints.isEmpty {
                        sectionTitle("上册")
                        ForEach(upperPoints) { kp in
                            knowledgeToggleCard(kp)
                        }
                    }
                    if !lowerPoints.isEmpty {
                        sectionTitle("下册")
                        ForEach(lowerPoints) { kp in
                            knowledgeToggleCard(kp)
                        }
                    }
                    if !otherPoints.isEmpty {
                        sectionTitle(subject == .english ? "英语" : "知识点")
                        ForEach(otherPoints) { kp in
                            knowledgeToggleCard(kp)
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 100)
            }
        }
        .navigationTitle("选知识点")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            NavigationLink {
                ModePickerView(
                    subject: subject,
                    knowledgePointIds: selectAll ? [] : Array(selectedIds).sorted()
                )
            } label: {
                Text("下一步：选练习方式")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: RoomTheme.touchMin)
                    .background(canContinue ? RoomTheme.mint : Color.gray.opacity(0.35))
                    .clipShape(Capsule())
            }
            .disabled(!canContinue)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
        .task {
            await appState.refreshKnowledgePoints(subject: subject)
        }
        .overlay {
            if appState.isLoading && points.isEmpty {
                ProgressView()
            }
        }
    }

    private var selectAllCard: some View {
        Button {
            selectAll = true
            selectedIds.removeAll()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("全部知识点")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(RoomTheme.ink)
                    Text(selectAll ? "会从本科目所有可练题目里抽题。" : "已选 \(selectedIds.count) 个知识点。")
                        .font(.caption)
                        .foregroundStyle(RoomTheme.ink.opacity(0.5))
                }
                Spacer()
                Image(systemName: selectAll ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(selectAll ? RoomTheme.mint : .secondary)
            }
            .padding(16)
            .background(RoomTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: RoomTheme.cornerMedium, style: .continuous))
            .shadow(color: RoomTheme.softShadow, radius: 6, y: 3)
        }
        .buttonStyle(.plain)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(RoomTheme.ink.opacity(0.5))
            .padding(.top, 8)
    }

    private var points: [KnowledgePoint] {
        appState.knowledgePoints.filter { $0.subject == subject.rawValue }
    }

    private var upperPoints: [KnowledgePoint] {
        points.filter { $0.semester == "upper" }
    }

    private var lowerPoints: [KnowledgePoint] {
        points.filter { $0.semester == "lower" }
    }

    private var otherPoints: [KnowledgePoint] {
        points.filter { $0.semester != "upper" && $0.semester != "lower" }
    }

    private var canContinue: Bool {
        selectAll || !selectedIds.isEmpty
    }

    @ViewBuilder
    private func knowledgeToggleCard(_ kp: KnowledgePoint) -> some View {
        let isOn = !selectAll && selectedIds.contains(kp.id)
        Button {
            guard kp.hasQuestions else { return }
            selectAll = false
            if selectedIds.contains(kp.id) {
                selectedIds.remove(kp.id)
                if selectedIds.isEmpty {
                    selectAll = true
                }
            } else {
                selectedIds.insert(kp.id)
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(kp.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(kp.hasQuestions ? RoomTheme.ink : .secondary)
                    HStack(spacing: 8) {
                        if !kp.hasQuestions {
                            Text("待练习")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        } else if kp.stars > 0 {
                            StarRow(stars: kp.stars)
                        }
                    }
                }
                Spacer()
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(kp.hasQuestions ? (isOn ? RoomTheme.mint : .secondary) : Color.secondary.opacity(0.35))
            }
            .padding(14)
            .background(isOn ? RoomTheme.mint.opacity(0.16) : RoomTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: RoomTheme.cornerMedium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: RoomTheme.cornerMedium, style: .continuous)
                    .stroke(isOn ? RoomTheme.mint : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .disabled(!kp.hasQuestions)
        .opacity(kp.hasQuestions ? 1 : 0.55)
        .accessibilityLabel(kp.hasQuestions ? kp.name : "\(kp.name)，待练习，暂不可选")
    }
}

struct ModePickerView: View {
    let subject: Subject
    var knowledgePointIds: [String] = []

    private func tint(for mode: PracticeMode) -> Color {
        switch mode {
        case .review: return RoomTheme.mint
        case .weak: return RoomTheme.softWarn
        case .habit: return RoomTheme.sky
        }
    }

    private func icon(for mode: PracticeMode) -> String {
        switch mode {
        case .review: return "book.fill"
        case .weak: return "flame.fill"
        case .habit: return "sun.max.fill"
        }
    }

    var body: some View {
        ZStack {
            RoomBackground(showDecor: false)
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(PracticeMode.allCases) { mode in
                        NavigationLink {
                            PracticeSessionView(
                                subject: subject,
                                mode: mode,
                                knowledgePointIds: knowledgePointIds
                            )
                        } label: {
                            RoomEntryCard(
                                title: mode.title,
                                subtitle: mode.subtitle,
                                tint: tint(for: mode),
                                systemImage: icon(for: mode),
                                minHeight: 110
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(24)
            }
        }
        .navigationTitle(subject.title)
    }
}
