import SwiftUI

enum RoomTheme {
    /// 奶油墙面
    static let cream = Color(red: 1.00, green: 0.97, blue: 0.93)
    /// 薄荷绿（主强调）
    static let mint = Color(red: 0.42, green: 0.78, blue: 0.66)
    /// 叶绿（兼容旧名）
    static let leaf = mint
    /// 晴空蓝
    static let sky = Color(red: 0.58, green: 0.80, blue: 0.95)
    /// 柔和墨色
    static let ink = Color(red: 0.28, green: 0.30, blue: 0.36)
    /// 软糖粉
    static let candy = Color(red: 1.00, green: 0.72, blue: 0.78)
    /// 蜜桃（兼容旧名 / 次强调）
    static let peach = candy
    /// 柠檬黄
    static let lemon = Color(red: 1.00, green: 0.90, blue: 0.55)
    /// 淡紫点缀
    static let lilac = Color(red: 0.82, green: 0.75, blue: 0.95)
    /// 语义：正确
    static let success = Color(red: 0.35, green: 0.72, blue: 0.55)
    /// 语义：差一点（温和提示，非刺眼红）
    static let softWarn = Color(red: 0.95, green: 0.62, blue: 0.48)
    /// 卡片白
    static let card = Color.white.opacity(0.94)
    /// 阴影
    static let softShadow = Color.black.opacity(0.07)

    static let cornerLarge: CGFloat = 28
    static let cornerMedium: CGFloat = 20
    static let cornerSmall: CGFloat = 14
    static let touchMin: CGFloat = 56
}

struct StarRow: View {
    let stars: Int
    var maxStars: Int = 5

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...maxStars, id: \.self) { i in
                Image(systemName: i <= stars ? "star.fill" : "star")
                    .foregroundStyle(i <= stars ? RoomTheme.lemon : .secondary.opacity(0.35))
                    .shadow(color: i <= stars ? RoomTheme.lemon.opacity(0.35) : .clear, radius: 2)
            }
        }
        .accessibilityLabel("\(stars) 星")
    }
}
