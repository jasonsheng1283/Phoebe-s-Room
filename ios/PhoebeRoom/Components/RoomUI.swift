import SwiftUI
import UIKit

// MARK: - Background

struct RoomBackground: View {
    var showDecor: Bool = true

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    RoomTheme.cream,
                    RoomTheme.sky.opacity(0.38),
                    RoomTheme.candy.opacity(0.22),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if showDecor {
                VStack {
                    HStack {
                        Spacer()
                        QuestionImageView(assetName: "decor_room_sun", height: 88, cornerRadius: 0)
                            .padding(.trailing, 28)
                            .padding(.top, 8)
                            .opacity(0.9)
                    }
                    Spacer()
                    HStack {
                        Circle()
                            .fill(RoomTheme.lemon.opacity(0.35))
                            .frame(width: 120, height: 120)
                            .blur(radius: 28)
                            .offset(x: -20, y: 40)
                        Spacer()
                        Circle()
                            .fill(RoomTheme.mint.opacity(0.28))
                            .frame(width: 140, height: 140)
                            .blur(radius: 32)
                            .offset(x: 30, y: 10)
                    }
                }
                .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - Cards

struct RoomEntryCard: View {
    let title: String
    let subtitle: String
    var tint: Color = RoomTheme.mint
    var systemImage: String? = nil
    var assetName: String? = nil
    var minHeight: CGFloat = 132

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(RoomTheme.ink)
                Text(subtitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(RoomTheme.ink.opacity(0.55))
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 8)
            Group {
                if let assetName, UIImage(named: assetName) != nil {
                    Image(assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 64, height: 64)
                        .background(tint.opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RoomTheme.cornerLarge, style: .continuous)
                .fill(RoomTheme.card)
                .shadow(color: RoomTheme.softShadow, radius: 14, y: 7)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RoomTheme.cornerLarge, style: .continuous)
                .stroke(tint.opacity(0.28), lineWidth: 2)
        )
    }
}

// MARK: - Buttons

struct RoomPrimaryButtonStyle: ButtonStyle {
    var tint: Color = RoomTheme.mint
    var disabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: RoomTheme.touchMin)
            .padding(.horizontal, 18)
            .background(
                Capsule(style: .continuous)
                    .fill(disabled ? Color.gray.opacity(0.35) : tint)
            )
            .scaleEffect(configuration.isPressed && !disabled ? 0.97 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isPressed)
            .opacity(disabled ? 0.7 : 1)
    }
}

struct RoomSecondaryButtonStyle: ButtonStyle {
    var tint: Color = RoomTheme.sky

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(RoomTheme.ink)
            .frame(maxWidth: .infinity, minHeight: RoomTheme.touchMin)
            .padding(.horizontal, 18)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.35))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

struct RoomPrimaryButton: View {
    let title: String
    var tint: Color = RoomTheme.mint
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
        }
        .buttonStyle(RoomPrimaryButtonStyle(tint: tint, disabled: disabled))
        .disabled(disabled)
    }
}

// MARK: - Option chip

struct RoomOptionChip: View {
    let title: String
    var isSelected: Bool
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(RoomTheme.ink)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(RoomTheme.mint)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: RoomTheme.touchMin)
            .background(
                RoundedRectangle(cornerRadius: RoomTheme.cornerMedium, style: .continuous)
                    .fill(isSelected ? RoomTheme.mint.opacity(0.22) : RoomTheme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RoomTheme.cornerMedium, style: .continuous)
                    .stroke(isSelected ? RoomTheme.mint : Color.clear, lineWidth: 3)
            )
            .shadow(color: RoomTheme.softShadow, radius: isSelected ? 8 : 4, y: 3)
            .scaleEffect(isSelected ? 1.02 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .animation(.spring(response: 0.32, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Feedback / progress

struct RoomFeedbackCard: View {
    let isCorrect: Bool
    let title: String
    let explanation: String
    var correctAnswerLine: String? = nil

    @State private var bounce = false
    @State private var shake = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                if isCorrect {
                    QuestionImageView(assetName: "decor_candy_star", height: 44, cornerRadius: 0)
                        .scaleEffect(bounce ? 1.08 : 0.92)
                } else {
                    Image(systemName: "sparkles")
                        .font(.title)
                        .foregroundStyle(RoomTheme.softWarn)
                }
                Text(title)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(isCorrect ? RoomTheme.success : RoomTheme.softWarn)
            }
            Text(explanation)
                .font(.body)
                .foregroundStyle(RoomTheme.ink.opacity(0.85))
            if let correctAnswerLine {
                Text(correctAnswerLine)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(RoomTheme.ink.opacity(0.65))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RoomTheme.cornerMedium, style: .continuous)
                .fill(isCorrect ? RoomTheme.mint.opacity(0.16) : RoomTheme.candy.opacity(0.2))
        )
        .overlay(
            RoundedRectangle(cornerRadius: RoomTheme.cornerMedium, style: .continuous)
                .stroke((isCorrect ? RoomTheme.mint : RoomTheme.softWarn).opacity(0.45), lineWidth: 2)
        )
        .offset(x: shake ? -6 : 0)
        .onAppear {
            if isCorrect {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.55).repeatCount(2, autoreverses: true)) {
                    bounce = true
                }
            } else {
                withAnimation(.default.repeatCount(2, autoreverses: true)) {
                    shake = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    shake = false
                }
            }
        }
    }
}

struct RoomProgressPips: View {
    let current: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("第 \(current) / \(total) 题")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(RoomTheme.ink.opacity(0.55))
            HStack(spacing: 8) {
                ForEach(1...max(total, 1), id: \.self) { i in
                    Capsule()
                        .fill(i <= current ? RoomTheme.mint : RoomTheme.ink.opacity(0.12))
                        .frame(height: 8)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

struct RoomStarBurst: View {
    let title: String
    let subtitle: String

    @State private var popped = false

    var body: some View {
        VStack(spacing: 16) {
            QuestionImageView(assetName: "decor_candy_star", height: 96, cornerRadius: 0)
                .scaleEffect(popped ? 1 : 0.6)
                .opacity(popped ? 1 : 0.4)
            Text(title)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(RoomTheme.ink)
            Text(subtitle)
                .font(.title3)
                .foregroundStyle(RoomTheme.ink.opacity(0.55))
                .multilineTextAlignment(.center)
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
                popped = true
            }
        }
    }
}

// MARK: - Question image

struct QuestionImageView: View {
    let assetName: String?
    var height: CGFloat = 180
    var cornerRadius: CGFloat = RoomTheme.cornerMedium

    var body: some View {
        Group {
            if let assetName, !assetName.isEmpty, UIImage(named: assetName) != nil {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            } else if let assetName, !assetName.isEmpty {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(RoomTheme.sky.opacity(0.2))
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(RoomTheme.ink.opacity(0.35))
                    )
                    .accessibilityLabel("插画暂缺")
            }
        }
    }
}
