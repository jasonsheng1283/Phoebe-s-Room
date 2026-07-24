import PencilKit
import SwiftUI

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

/// MVP：手写后由孩子/家长确认文本（不做强制 OCR）。
struct HandwritingAnswerPanel: View {
    @Binding var confirmedText: String
    @State private var drawing = PKDrawing()
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("可以用手写，再确认成文字提交")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HandwritingCanvas(drawing: $drawing)
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            HStack {
                Button("清空手写") {
                    drawing = PKDrawing()
                }
                Spacer()
            }
            TextField("把你写的答案打在这里确认", text: $draft)
                .textFieldStyle(.roundedBorder)
                .font(.title2)
            Button("用手写确认的答案") {
                confirmedText = draft.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .buttonStyle(.borderedProminent)
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}
