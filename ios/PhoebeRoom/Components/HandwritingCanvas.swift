import PencilKit
import SwiftUI
import UIKit

struct HandwritingCanvas: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    var inkColor: UIColor = .label

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .anyInput
        canvas.tool = PKInkingTool(.pen, color: inkColor, width: 18)
        canvas.backgroundColor = UIColor.secondarySystemBackground
        canvas.delegate = context.coordinator
        canvas.drawing = drawing
        canvas.isOpaque = true
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        if uiView.drawing != drawing {
            uiView.drawing = drawing
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: HandwritingCanvas
        init(_ parent: HandwritingCanvas) { self.parent = parent }
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawing = canvasView.drawing
        }
    }
}

/// MVP：手写草稿区（不作为最终答案通道，仅辅助思考）。
struct HandwritingDraftPanel: View {
    @State private var drawing = PKDrawing()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("草稿区：可以写一写、算一算，答案请用上面的按钮提交")
                .font(.subheadline)
                .foregroundStyle(RoomTheme.ink.opacity(0.55))
            HandwritingCanvas(drawing: $drawing)
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: RoomTheme.cornerMedium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: RoomTheme.cornerMedium, style: .continuous)
                        .stroke(RoomTheme.sky.opacity(0.5), lineWidth: 2)
                )
            Button("清空草稿") {
                drawing = PKDrawing()
            }
            .buttonStyle(RoomSecondaryButtonStyle(tint: RoomTheme.lemon))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: RoomTheme.cornerMedium, style: .continuous)
                .fill(RoomTheme.card)
        )
    }
}

/// 兼容旧名
typealias HandwritingAnswerPanel = HandwritingDraftPanel

struct TrueFalseAnswerView: View {
    @Binding var selected: String?
    var disabled: Bool = false

    var body: some View {
        HStack(spacing: 16) {
            ForEach(["对", "错"], id: \.self) { option in
                Button {
                    selected = option
                } label: {
                    Text(option)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity, minHeight: 96)
                        .foregroundStyle(RoomTheme.ink)
                        .background(
                            selected == option
                                ? (option == "对" ? RoomTheme.mint.opacity(0.28) : RoomTheme.candy.opacity(0.35))
                                : RoomTheme.card
                        )
                        .clipShape(RoundedRectangle(cornerRadius: RoomTheme.cornerLarge, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: RoomTheme.cornerLarge, style: .continuous)
                                .stroke(
                                    selected == option
                                        ? (option == "对" ? RoomTheme.mint : RoomTheme.softWarn)
                                        : Color.clear,
                                    lineWidth: 3
                                )
                        )
                        .shadow(color: RoomTheme.softShadow, radius: 8, y: 4)
                        .scaleEffect(selected == option ? 1.03 : 1)
                }
                .buttonStyle(.plain)
                .disabled(disabled)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selected)
            }
        }
    }
}

struct DragSortAnswerView: View {
    let items: [InteractionItem]
    @Binding var orderedIds: [String]
    var disabled: Bool = false

    private let candyTints: [Color] = [
        RoomTheme.mint.opacity(0.22),
        RoomTheme.sky.opacity(0.28),
        RoomTheme.candy.opacity(0.28),
        RoomTheme.lemon.opacity(0.35),
        RoomTheme.lilac.opacity(0.3),
    ]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(orderedIds.enumerated()), id: \.element) { index, id in
                HStack(spacing: 12) {
                    Text("\(index + 1)")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(RoomTheme.ink.opacity(0.45))
                        .frame(width: 28)
                    Text(label(for: id))
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(RoomTheme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(spacing: 4) {
                        Button {
                            moveUp(index)
                        } label: {
                            Image(systemName: "chevron.up.circle.fill")
                                .font(.title2)
                        }
                        .disabled(disabled || index == 0)
                        Button {
                            moveDown(index)
                        } label: {
                            Image(systemName: "chevron.down.circle.fill")
                                .font(.title2)
                        }
                        .disabled(disabled || index >= orderedIds.count - 1)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(RoomTheme.mint)
                }
                .padding()
                .background(candyTints[index % candyTints.count])
                .clipShape(RoundedRectangle(cornerRadius: RoomTheme.cornerMedium, style: .continuous))
                .shadow(color: RoomTheme.softShadow, radius: 4, y: 2)
            }
        }
        .onAppear {
            if orderedIds.isEmpty {
                orderedIds = items.map(\.id)
            }
        }
    }

    private func label(for id: String) -> String {
        items.first(where: { $0.id == id })?.label ?? id
    }

    private func moveUp(_ index: Int) {
        guard index > 0 else { return }
        orderedIds.swapAt(index, index - 1)
    }

    private func moveDown(_ index: Int) {
        guard index < orderedIds.count - 1 else { return }
        orderedIds.swapAt(index, index + 1)
    }
}

struct DragPlaceAnswerView: View {
    let scene: String
    var backgroundAsset: String? = nil
    let tokens: [InteractionItem]
    let slots: [InteractionSlot]
    @Binding var assignments: [String: String]
    var disabled: Bool = false

    @State private var draggingToken: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            sceneCanvas
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .background(RoomTheme.sky.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: RoomTheme.cornerLarge, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: RoomTheme.cornerLarge, style: .continuous)
                        .stroke(RoomTheme.mint.opacity(0.35), lineWidth: 2)
                )

            Text("拖到下面的位置")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(RoomTheme.ink.opacity(0.55))

            ForEach(slots) { slot in
                HStack {
                    Text(slot.label)
                        .font(.headline)
                        .foregroundStyle(RoomTheme.ink)
                    Spacer()
                    Text(tokenLabel(assignments[slot.id]))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(assignments[slot.id] == nil ? RoomTheme.ink.opacity(0.35) : RoomTheme.mint)
                }
                .padding()
                .frame(maxWidth: .infinity, minHeight: RoomTheme.touchMin)
                .background(RoomTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: RoomTheme.cornerMedium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: RoomTheme.cornerMedium, style: .continuous)
                        .stroke(
                            assignments[slot.id] == nil ? RoomTheme.ink.opacity(0.12) : RoomTheme.mint,
                            style: StrokeStyle(lineWidth: 2, dash: assignments[slot.id] == nil ? [6, 4] : [])
                        )
                )
                .dropDestination(for: String.self) { items, _ in
                    guard !disabled, let tokenId = items.first else { return false }
                    var next = assignments
                    for (key, value) in next where value == tokenId {
                        next.removeValue(forKey: key)
                    }
                    next[slot.id] = tokenId
                    assignments = next
                    return true
                }
            }

            Text("可拖标签")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(RoomTheme.ink.opacity(0.55))
            HStack {
                ForEach(tokens) { token in
                    Text(token.label)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(RoomTheme.ink)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(RoomTheme.candy.opacity(0.4))
                        .clipShape(Capsule())
                        .shadow(color: RoomTheme.softShadow, radius: 4, y: 2)
                        .draggable(token.id) {
                            Text(token.label).onAppear { draggingToken = token.id }
                        }
                        .opacity(disabled ? 0.5 : 1)
                }
            }
        }
    }

    private func tokenLabel(_ id: String?) -> String {
        guard let id else { return "拖到这里" }
        return tokens.first(where: { $0.id == id })?.label ?? id
    }

    private var resolvedBackground: String? {
        if let backgroundAsset, !backgroundAsset.isEmpty { return backgroundAsset }
        switch scene {
        case "angles_three_v1": return "scene_angles_three_v1"
        case "observe_cube_v1": return "scene_observe_cube_v1"
        case "symmetry_line_v1": return "scene_symmetry_line_v1"
        default: return nil
        }
    }

    @ViewBuilder
    private var sceneCanvas: some View {
        if let asset = resolvedBackground, UIImage(named: asset) != nil {
            Image(asset)
                .resizable()
                .scaledToFit()
                .padding(8)
        } else {
            switch scene {
            case "angles_three_v1":
                AnglesThreeScene(highlightSlot: assignments.first(where: { $0.value == "right" })?.key)
            case "observe_cube_v1":
                ObserveCubeScene(filledFront: assignments["front"] != nil)
            case "symmetry_line_v1":
                SymmetryLineScene(axisPlaced: assignments["mid"] != nil)
            default:
                Text("场景 \(scene)")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct AnglesThreeScene: View {
    var highlightSlot: String?

    var body: some View {
        HStack(spacing: 24) {
            angleMark("角1", degrees: 40, active: highlightSlot == "s1")
            angleMark("角2", degrees: 90, active: highlightSlot == "s2")
            angleMark("角3", degrees: 120, active: highlightSlot == "s3")
        }
        .padding()
    }

    private func angleMark(_ title: String, degrees: Double, active: Bool) -> some View {
        VStack(spacing: 8) {
            Path { path in
                let origin = CGPoint(x: 40, y: 70)
                path.move(to: origin)
                path.addLine(to: CGPoint(x: 80, y: 70))
                path.move(to: origin)
                let rad = degrees * Double.pi / 180
                path.addLine(
                    to: CGPoint(
                        x: 40 + 40 * Foundation.cos(rad),
                        y: 70 - 40 * Foundation.sin(rad)
                    )
                )
            }
            .stroke(active ? RoomTheme.mint : RoomTheme.ink, lineWidth: 4)
            .frame(width: 90, height: 80)
            Text(title).font(.caption)
        }
    }
}

private struct ObserveCubeScene: View {
    var filledFront: Bool

    var body: some View {
        HStack(spacing: 28) {
            RoundedRectangle(cornerRadius: 8)
                .stroke(RoomTheme.ink, lineWidth: 3)
                .frame(width: 90, height: 90)
                .overlay(
                    Text("正面")
                        .font(.caption)
                        .foregroundStyle(filledFront ? RoomTheme.mint : .secondary)
                )
            RoundedRectangle(cornerRadius: 8)
                .stroke(RoomTheme.ink.opacity(0.45), lineWidth: 3)
                .frame(width: 70, height: 90)
                .overlay(Text("侧面").font(.caption).foregroundStyle(.secondary))
        }
    }
}

private struct SymmetryLineScene: View {
    var axisPlaced: Bool

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                TriangleShape()
                    .fill(RoomTheme.sky.opacity(0.5))
                    .frame(width: 70, height: 90)
                TriangleShape()
                    .fill(RoomTheme.sky.opacity(0.5))
                    .frame(width: 70, height: 90)
                    .scaleEffect(x: -1, y: 1)
            }
            Rectangle()
                .fill(axisPlaced ? RoomTheme.mint : RoomTheme.ink.opacity(0.35))
                .frame(width: axisPlaced ? 4 : 2, height: 100)
        }
    }
}

private struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
