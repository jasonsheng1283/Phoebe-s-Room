import SwiftUI

// MARK: - Container

struct QuestionDiagramView: View {
    let diagram: DiagramSpec
    var height: CGFloat = 180
    /// When the question also has a static illustration, show a small candy badge for warmth.
    var showAmbienceBadge: Bool = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                switch diagram.kind {
                case "angles":
                    AnglesDiagramView(diagram: diagram)
                case "symmetry":
                    SymmetryDiagramView(diagram: diagram)
                case "observe":
                    ObserveDiagramView(diagram: diagram)
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: RoomTheme.cornerMedium, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                RoomTheme.cream,
                                RoomTheme.card,
                                RoomTheme.lemon.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: RoomTheme.cornerMedium, style: .continuous)
                            .stroke(RoomTheme.sky.opacity(0.25), lineWidth: 1)
                    )
                    .shadow(color: RoomTheme.softShadow, radius: 6, y: 3)
            )

            if showAmbienceBadge {
                Group {
                    if UIImage(named: "decor_candy_star") != nil {
                        Image("decor_candy_star")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 36, height: 36)
                    } else {
                        Image(systemName: "star.fill")
                            .font(.title3)
                            .foregroundStyle(RoomTheme.lemon)
                    }
                }
                .padding(10)
                .accessibilityHidden(true)
            }
        }
        .accessibilityLabel("题目图形")
    }
}

// MARK: - Angles

private struct AnglesDiagramView: View {
    let diagram: DiagramSpec

    var body: some View {
        let degrees = (diagram.anglesDeg ?? [40, 90, 120]).map { CGFloat($0) }
        let labels = diagram.labels ?? []
        let highlight = diagram.highlightIndex

        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let count = max(degrees.count, 1)
            let cellW = w / CGFloat(count)

            HStack(spacing: 0) {
                ForEach(Array(degrees.enumerated()), id: \.offset) { index, deg in
                    let isHi = highlight == index
                    VStack(spacing: 8) {
                        AngleSector(
                            degrees: deg,
                            highlighted: isHi
                        )
                        .frame(width: min(cellW - 16, 110), height: min(h * 0.58, 96))

                        if index < labels.count {
                            Text(labels[index])
                                .font(.system(size: isHi ? 18 : 16, weight: isHi ? .bold : .semibold, design: .rounded))
                                .foregroundStyle(isHi ? RoomTheme.ink : RoomTheme.ink.opacity(0.7))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(isHi ? RoomTheme.mint.opacity(0.35) : RoomTheme.sky.opacity(0.18))
                                )
                        }
                    }
                    .frame(width: cellW)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(12)
    }
}

private struct AngleSector: View {
    let degrees: CGFloat
    let highlighted: Bool

    var body: some View {
        Canvas { context, size in
            let origin = CGPoint(x: size.width * 0.22, y: size.height * 0.78)
            let radius = min(size.width, size.height) * 0.72
            let start = Angle.degrees(0)
            let clamped = min(max(degrees, 5), 170)
            let end = Angle.degrees(Double(-clamped))

            var rays = Path()
            rays.move(to: origin)
            rays.addLine(to: CGPoint(x: origin.x + radius, y: origin.y))
            rays.move(to: origin)
            let rad = end.radians
            rays.addLine(to: CGPoint(
                x: origin.x + radius * CGFloat(Foundation.cos(rad)),
                y: origin.y + radius * CGFloat(Foundation.sin(rad))
            ))

            var wedge = Path()
            wedge.move(to: origin)
            wedge.addArc(center: origin, radius: radius * 0.28, startAngle: start, endAngle: end, clockwise: true)
            wedge.closeSubpath()

            let fillOpacity: Double = highlighted ? 0.42 : (clamped < 90 ? 0.28 : 0.22)
            context.fill(wedge, with: .color((highlighted ? RoomTheme.mint : RoomTheme.sky).opacity(fillOpacity)))
            context.stroke(
                rays,
                with: .color(highlighted ? RoomTheme.mint : RoomTheme.ink.opacity(0.75)),
                style: StrokeStyle(lineWidth: highlighted ? 4 : 3, lineCap: .round)
            )

            if abs(degrees - 90) < 0.5 {
                let s: CGFloat = 14
                var square = Path()
                square.move(to: CGPoint(x: origin.x + s, y: origin.y))
                square.addLine(to: CGPoint(x: origin.x + s, y: origin.y - s))
                square.addLine(to: CGPoint(x: origin.x, y: origin.y - s))
                context.stroke(square, with: .color(RoomTheme.lemon), lineWidth: 2.5)
            }
        }
    }
}

// MARK: - Symmetry

private struct SymmetryDiagramView: View {
    let diagram: DiagramSpec

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height) * 0.72
            ZStack {
                SymmetryShape(shape: diagram.shape ?? "heart")
                    .fill(RoomTheme.candy.opacity(0.55))
                    .overlay(
                        SymmetryShape(shape: diagram.shape ?? "heart")
                            .stroke(RoomTheme.ink.opacity(0.55), lineWidth: 2.5)
                    )
                    .frame(width: size, height: size * 0.92)

                if diagram.showAxis != false {
                    let axis = diagram.axis ?? "vertical"
                    Path { path in
                        if axis == "horizontal" {
                            path.move(to: CGPoint(x: geo.size.width * 0.18, y: geo.size.height * 0.5))
                            path.addLine(to: CGPoint(x: geo.size.width * 0.82, y: geo.size.height * 0.5))
                        } else if axis != "none" {
                            path.move(to: CGPoint(x: geo.size.width * 0.5, y: geo.size.height * 0.12))
                            path.addLine(to: CGPoint(x: geo.size.width * 0.5, y: geo.size.height * 0.88))
                        }
                    }
                    .stroke(
                        RoomTheme.mint,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [8, 6])
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(12)
    }
}

private struct SymmetryShape: Shape {
    let shape: String

    func path(in rect: CGRect) -> Path {
        switch shape {
        case "rect":
            let inset = rect.insetBy(dx: rect.width * 0.18, dy: rect.height * 0.2)
            return Path(roundedRect: inset, cornerRadius: 10)
        case "butterfly":
            var p = Path()
            let c = CGPoint(x: rect.midX, y: rect.midY)
            // Upper wings
            p.addEllipse(in: CGRect(
                x: c.x - rect.width * 0.46, y: c.y - rect.height * 0.36,
                width: rect.width * 0.38, height: rect.height * 0.42
            ))
            p.addEllipse(in: CGRect(
                x: c.x + rect.width * 0.08, y: c.y - rect.height * 0.36,
                width: rect.width * 0.38, height: rect.height * 0.42
            ))
            // Lower wings (slightly smaller)
            p.addEllipse(in: CGRect(
                x: c.x - rect.width * 0.4, y: c.y + rect.height * 0.02,
                width: rect.width * 0.3, height: rect.height * 0.32
            ))
            p.addEllipse(in: CGRect(
                x: c.x + rect.width * 0.1, y: c.y + rect.height * 0.02,
                width: rect.width * 0.3, height: rect.height * 0.32
            ))
            // Body
            p.addEllipse(in: CGRect(
                x: c.x - rect.width * 0.05, y: c.y - rect.height * 0.28,
                width: rect.width * 0.1, height: rect.height * 0.56
            ))
            return p
        default: // heart — wider top lobes, pointed bottom
            var p = Path()
            let w = rect.width
            let h = rect.height
            p.move(to: CGPoint(x: rect.midX, y: rect.minY + h * 0.32))
            p.addCurve(
                to: CGPoint(x: rect.midX, y: rect.maxY - h * 0.06),
                control1: CGPoint(x: rect.minX + w * 0.02, y: rect.minY + h * 0.02),
                control2: CGPoint(x: rect.minX + w * 0.08, y: rect.midY + h * 0.22)
            )
            p.addCurve(
                to: CGPoint(x: rect.midX, y: rect.minY + h * 0.32),
                control1: CGPoint(x: rect.maxX - w * 0.08, y: rect.midY + h * 0.22),
                control2: CGPoint(x: rect.maxX - w * 0.02, y: rect.minY + h * 0.02)
            )
            return p
        }
    }
}

// MARK: - Observe object

private struct ObserveDiagramView: View {
    let diagram: DiagramSpec

    var body: some View {
        GeometryReader { geo in
            let object = diagram.object ?? "cube"
            let view = diagram.view ?? "front"
            let highlight = diagram.highlightFace != false

            ZStack {
                if object == "cylinder" {
                    CylinderViewSketch(view: view, highlight: highlight)
                        .frame(width: geo.size.width * 0.55, height: geo.size.height * 0.62)
                } else {
                    CubeViewSketch(view: view, highlight: highlight)
                        .frame(width: geo.size.width * 0.55, height: geo.size.height * 0.62)
                }

                VStack(spacing: 2) {
                    Spacer()
                    if object == "cylinder" && view == "top" {
                        Text("圆")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(RoomTheme.mint)
                    }
                    Text(viewLabel(view))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(RoomTheme.ink.opacity(0.65))
                        .padding(.bottom, 4)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(12)
    }

    private func viewLabel(_ view: String) -> String {
        switch view {
        case "side": return "侧面"
        case "top": return "上面"
        default: return "正面"
        }
    }
}

private struct CubeViewSketch: View {
    let view: String
    let highlight: Bool

    var body: some View {
        Canvas { context, size in
            let fill = (highlight ? RoomTheme.sky : RoomTheme.lemon).opacity(0.45)
            let stroke = RoomTheme.ink.opacity(0.7)
            switch view {
            case "top":
                var diamond = Path()
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                diamond.move(to: CGPoint(x: c.x, y: c.y - size.height * 0.28))
                diamond.addLine(to: CGPoint(x: c.x + size.width * 0.32, y: c.y))
                diamond.addLine(to: CGPoint(x: c.x, y: c.y + size.height * 0.28))
                diamond.addLine(to: CGPoint(x: c.x - size.width * 0.32, y: c.y))
                diamond.closeSubpath()
                context.fill(diamond, with: .color(fill))
                context.stroke(diamond, with: .color(stroke), lineWidth: 3)
            case "side":
                let rect = CGRect(
                    x: size.width * 0.28, y: size.height * 0.12,
                    width: size.width * 0.44, height: size.height * 0.76
                )
                context.fill(Path(roundedRect: rect, cornerRadius: 6), with: .color(fill))
                context.stroke(Path(roundedRect: rect, cornerRadius: 6), with: .color(stroke), lineWidth: 3)
            default:
                let side = min(size.width, size.height) * 0.62
                let rect = CGRect(
                    x: (size.width - side) / 2, y: (size.height - side) / 2,
                    width: side, height: side
                )
                context.fill(Path(roundedRect: rect, cornerRadius: 8), with: .color(fill))
                context.stroke(Path(roundedRect: rect, cornerRadius: 8), with: .color(stroke), lineWidth: 3)
            }
        }
    }
}

private struct CylinderViewSketch: View {
    let view: String
    let highlight: Bool

    var body: some View {
        Canvas { context, size in
            let fill = (highlight ? RoomTheme.lilac : RoomTheme.sky).opacity(0.45)
            let stroke = RoomTheme.ink.opacity(0.7)
            switch view {
            case "top":
                let oval = CGRect(
                    x: size.width * 0.18, y: size.height * 0.22,
                    width: size.width * 0.64, height: size.height * 0.5
                )
                context.fill(Path(ellipseIn: oval), with: .color(fill))
                context.stroke(Path(ellipseIn: oval), with: .color(stroke), lineWidth: 3)
            default:
                let body = CGRect(
                    x: size.width * 0.28, y: size.height * 0.18,
                    width: size.width * 0.44, height: size.height * 0.64
                )
                context.fill(Path(roundedRect: body, cornerRadius: body.width / 2), with: .color(fill))
                context.stroke(Path(roundedRect: body, cornerRadius: body.width / 2), with: .color(stroke), lineWidth: 3)
                let top = CGRect(
                    x: body.minX, y: body.minY - 8,
                    width: body.width, height: 20
                )
                context.stroke(Path(ellipseIn: top), with: .color(stroke), lineWidth: 2)
            }
        }
    }
}
