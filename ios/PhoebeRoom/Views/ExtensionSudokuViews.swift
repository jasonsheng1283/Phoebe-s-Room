import SwiftUI

struct ExtensionHubView: View {
    @EnvironmentObject private var appState: AppState
    @State private var activities: [ExtensionActivity] = []
    @State private var errorMessage: String?
    @State private var isLoading = true
    private let grade = 2

    var body: some View {
        ZStack {
            RoomBackground(showDecor: false)
            Group {
                if isLoading {
                    ProgressView("加载拓展活动…")
                } else if let errorMessage {
                    ContentUnavailableView("加载失败", systemImage: "wifi.exclamationmark", description: Text(errorMessage))
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("这里练的是不绑课本单元的小挑战，过一关解锁下一关。")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(RoomTheme.ink.opacity(0.55))

                            QuestionImageView(assetName: "decor_sudoku", height: 100, cornerRadius: 20)

                            ForEach(activities) { activity in
                                NavigationLink {
                                    if activity.kind == "sudoku" {
                                        SudokuGameView(grade: grade, startLevel: activity.nextLevel)
                                    } else {
                                        Text("即将开放")
                                    }
                                } label: {
                                    RoomEntryCard(
                                        title: activity.title,
                                        subtitle: activity.subtitle + "\n" + (
                                            activity.highestClearedLevel == 0
                                                ? "从第 1 关开始"
                                                : "已过 \(activity.highestClearedLevel) 关 · 下一关 \(activity.nextLevel)"
                                        ),
                                        tint: RoomTheme.lilac,
                                        systemImage: "square.grid.3x3.fill",
                                        assetName: "decor_sudoku",
                                        minHeight: 120
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(24)
                    }
                }
            }
        }
        .navigationTitle("头脑拓展")
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            activities = try await appState.api.fetchExtensionActivities(
                grade: grade,
                familyCode: appState.familyCode
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct SudokuGameView: View {
    @EnvironmentObject private var appState: AppState
    let grade: Int
    let startLevel: Int

    @State private var levelNumber: Int
    @State private var puzzle: SudokuLevel?
    @State private var board: [[Int?]] = []
    @State private var givenMask: [[Bool]] = []
    @State private var dropTarget: (row: Int, col: Int)?
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var isLoading = true
    @State private var isSubmitting = false
    @State private var cleared = false
    @State private var nextLevelToPlay: Int?

    private let eraseToken = "erase"
    private let candyFills: [Color] = [
        RoomTheme.mint.opacity(0.18),
        RoomTheme.sky.opacity(0.22),
        RoomTheme.candy.opacity(0.22),
        RoomTheme.lemon.opacity(0.28),
    ]

    init(grade: Int, startLevel: Int) {
        self.grade = grade
        self.startLevel = startLevel
        _levelNumber = State(initialValue: max(1, startLevel))
    }

    var body: some View {
        ZStack {
            RoomBackground(showDecor: false)
            Group {
                if isLoading {
                    ProgressView("准备第 \(levelNumber) 关…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage, puzzle == nil {
                    VStack(spacing: 12) {
                        Text(errorMessage).foregroundStyle(RoomTheme.softWarn)
                        RoomPrimaryButton(title: "重试") { Task { await loadLevel(levelNumber) } }
                            .padding(.horizontal, 48)
                    }
                } else if let puzzle {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            header(puzzle)
                            legend
                            boardGrid(puzzle)
                            symbolPalette(puzzle)

                            if let statusMessage {
                                Text(statusMessage)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(cleared ? RoomTheme.success : RoomTheme.ink.opacity(0.55))
                            }
                            if let errorMessage {
                                Text(errorMessage).font(.footnote).foregroundStyle(RoomTheme.softWarn)
                            }

                            actionBar(puzzle)
                        }
                        .padding(20)
                    }
                }
            }
        }
        .navigationTitle("符号数独")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { Task { await loadLevel(levelNumber) } }
    }

    private var boardComplete: Bool {
        board.allSatisfy { row in row.allSatisfy { $0 != nil } }
    }

    private var fillableCount: Int {
        givenMask.flatMap { $0 }.filter { !$0 }.count
    }

    private var filledCount: Int {
        zip(board.flatMap { $0 }, givenMask.flatMap { $0 })
            .filter { value, isGiven in !isGiven && value != nil }
            .count
    }

    private func header(_ puzzle: SudokuLevel) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("第 \(puzzle.level) 关")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(RoomTheme.ink)
                Text("已填 \(filledCount)/\(fillableCount) 个待填格")
                    .font(.caption)
                    .foregroundStyle(RoomTheme.ink.opacity(0.5))
            }
            Spacer()
            Text(puzzle.theme.label)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(RoomTheme.lilac.opacity(0.35))
                .clipShape(Capsule())
        }
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendSwatch(
                fill: Color.white.opacity(0.96),
                border: RoomTheme.ink.opacity(0.35),
                dashed: false,
                title: "题目给出"
            )
            legendSwatch(
                fill: RoomTheme.sky.opacity(0.22),
                border: RoomTheme.mint.opacity(0.85),
                dashed: true,
                title: "需要你填"
            )
        }
    }

    private func legendSwatch(fill: Color, border: Color, dashed: Bool, title: String) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(fill)
                .frame(width: 28, height: 28)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(border, style: StrokeStyle(lineWidth: dashed ? 2 : 1.5, dash: dashed ? [4, 3] : []))
                )
            Text(title)
                .font(.caption)
                .foregroundStyle(RoomTheme.ink.opacity(0.55))
        }
    }

    private func boardGrid(_ puzzle: SudokuLevel) -> some View {
        let size = puzzle.size
        return VStack(spacing: 0) {
            ForEach(0..<size, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<size, id: \.self) { c in
                        cellView(row: r, col: c, puzzle: puzzle)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(RoomTheme.ink.opacity(0.75), lineWidth: 3)
        )
        .shadow(color: RoomTheme.softShadow, radius: 10, y: 4)
    }

    private func cellView(row: Int, col: Int, puzzle: SudokuLevel) -> some View {
        let value = board[safe: row]?[safe: col] ?? nil
        let isGiven = givenMask[safe: row]?[safe: col] ?? false
        let isFillable = !isGiven
        let isDropping = dropTarget?.row == row && dropTarget?.col == col
        let thickRight = (col + 1) % puzzle.box == 0 && col + 1 != puzzle.size
        let thickBottom = (row + 1) % puzzle.box == 0 && row + 1 != puzzle.size

        return ZStack(alignment: .topTrailing) {
            Group {
                if let glyph = glyph(for: value, in: puzzle) {
                    Text(glyph)
                        .font(.system(size: 30))
                } else if isFillable {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(RoomTheme.mint.opacity(0.45))
                } else {
                    Text(" ")
                }
            }
            .frame(maxWidth: .infinity, minHeight: 76)

            if isFillable {
                Text("填")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(RoomTheme.mint)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.9))
                    .clipShape(Capsule())
                    .padding(5)
            }
        }
        .background(cellBackground(isGiven: isGiven, isDropping: isDropping, row: row, col: col))
        .overlay {
            if isFillable {
                RoundedRectangle(cornerRadius: 0)
                    .strokeBorder(
                        isDropping ? RoomTheme.mint : RoomTheme.mint.opacity(0.75),
                        style: StrokeStyle(lineWidth: isDropping ? 3 : 2, dash: [5, 4])
                    )
                    .padding(3)
            }
        }
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(RoomTheme.ink.opacity(thickRight ? 0.9 : 0.18))
                .frame(width: thickRight ? 3 : 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(RoomTheme.ink.opacity(thickBottom ? 0.9 : 0.18))
                .frame(height: thickBottom ? 3 : 1)
        }
        .contentShape(Rectangle())
        .dropDestination(for: String.self) { items, _ in
            guard isFillable, !cleared, let raw = items.first else { return false }
            if raw == eraseToken {
                board[row][col] = nil
            } else if let symbol = Int(raw) {
                board[row][col] = symbol
            } else {
                return false
            }
            errorMessage = nil
            return true
        } isTargeted: { hovering in
            if hovering, isFillable, !cleared {
                dropTarget = (row, col)
            } else if dropTarget?.row == row && dropTarget?.col == col {
                dropTarget = nil
            }
        }
        .foregroundStyle(isGiven ? RoomTheme.ink : RoomTheme.mint)
        .accessibilityLabel(isFillable ? "待填格子" : "题目格子")
    }

    private func cellBackground(isGiven: Bool, isDropping: Bool, row: Int, col: Int) -> Color {
        if isDropping {
            return RoomTheme.mint.opacity(0.28)
        }
        if isGiven {
            return Color.white.opacity(0.97)
        }
        return candyFills[(row + col) % candyFills.count]
    }

    private func symbolPalette(_ puzzle: SudokuLevel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("把下面的符号拖进带「填」字的格子；拖橡皮可以擦掉")
                .font(.subheadline)
                .foregroundStyle(RoomTheme.ink.opacity(0.55))

            HStack(spacing: 12) {
                ForEach(Array(puzzle.theme.symbols.enumerated()), id: \.element.id) { idx, symbol in
                    Text(symbol.glyph)
                        .font(.system(size: 34))
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .background(candyFills[idx % candyFills.count])
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: RoomTheme.softShadow, radius: 4, y: 2)
                        .opacity(cleared ? 0.45 : 1)
                        .draggable(String(symbol.id)) {
                            Text(symbol.glyph)
                                .font(.system(size: 44))
                                .padding(12)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .disabled(cleared)
                        .accessibilityLabel("拖动\(symbol.name)")
                }

                Image(systemName: "eraser.fill")
                    .font(.title2)
                    .frame(width: 64, height: 64)
                    .foregroundStyle(RoomTheme.ink.opacity(0.75))
                    .background(RoomTheme.candy.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .opacity(cleared ? 0.45 : 1)
                    .draggable(eraseToken) {
                        Image(systemName: "eraser.fill")
                            .font(.largeTitle)
                            .padding(12)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(cleared)
                    .accessibilityLabel("拖动橡皮清除")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoomTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: RoomTheme.cornerLarge, style: .continuous))
    }

    private func actionBar(_ puzzle: SudokuLevel) -> some View {
        HStack(spacing: 12) {
            Button("清空填写") { clearFills(puzzle) }
                .buttonStyle(RoomSecondaryButtonStyle(tint: RoomTheme.lemon))
                .disabled(cleared || filledCount == 0)
            RoomPrimaryButton(
                title: isSubmitting ? "检查中…" : (cleared ? "下一关" : "检查过关"),
                disabled: isSubmitting || (!cleared && !boardComplete)
            ) {
                if cleared {
                    Task { await loadLevel(nextLevelToPlay ?? (levelNumber + 1)) }
                } else {
                    Task { await submit(puzzle) }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func glyph(for value: Int?, in puzzle: SudokuLevel) -> String? {
        guard let value else { return nil }
        return puzzle.theme.symbols.first(where: { $0.id == value })?.glyph
    }

    private func loadLevel(_ level: Int) async {
        isLoading = true
        errorMessage = nil
        statusMessage = nil
        cleared = false
        dropTarget = nil
        nextLevelToPlay = nil
        defer { isLoading = false }
        do {
            let data = try await appState.api.fetchSudokuLevel(
                grade: grade,
                level: level,
                familyCode: appState.familyCode
            )
            puzzle = data
            levelNumber = data.level
            board = data.givens
            givenMask = data.givens.map { row in row.map { $0 != nil } }
        } catch {
            puzzle = nil
            errorMessage = error.localizedDescription
        }
    }

    private func clearFills(_ puzzle: SudokuLevel) {
        for r in 0..<puzzle.size {
            for c in 0..<puzzle.size {
                if !(givenMask[safe: r]?[safe: c] ?? false) {
                    board[r][c] = nil
                }
            }
        }
        statusMessage = nil
        errorMessage = nil
    }

    private func submit(_ puzzle: SudokuLevel) async {
        guard boardComplete else { return }
        let filled: [[Int]] = board.map { row in row.map { $0 ?? -1 } }
        guard filled.allSatisfy({ $0.allSatisfy { $0 >= 0 } }) else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            let resp = try await appState.api.clearSudoku(
                grade: grade,
                level: puzzle.level,
                board: filled,
                familyCode: appState.familyCode
            )
            cleared = true
            nextLevelToPlay = resp.nextLevel
            statusMessage = "过关！下一关是第 \(resp.nextLevel) 关"
        } catch {
            errorMessage = "还不对，再检查每一行、每一列和每个小宫格。"
            statusMessage = nil
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
