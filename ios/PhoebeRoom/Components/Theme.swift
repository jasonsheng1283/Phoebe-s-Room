import SwiftUI

enum RoomTheme {
    static let cream = Color(red: 0.98, green: 0.96, blue: 0.92)
    static let leaf = Color(red: 0.25, green: 0.55, blue: 0.42)
    static let sky = Color(red: 0.55, green: 0.72, blue: 0.86)
    static let ink = Color(red: 0.18, green: 0.22, blue: 0.25)
    static let peach = Color(red: 0.93, green: 0.62, blue: 0.48)
}

struct StarRow: View {
    let stars: Int
    var maxStars: Int = 5

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...maxStars, id: \.self) { i in
                Image(systemName: i <= stars ? "star.fill" : "star")
                    .foregroundStyle(i <= stars ? RoomTheme.peach : .secondary.opacity(0.4))
            }
        }
        .accessibilityLabel("\(stars) 星")
    }
}
