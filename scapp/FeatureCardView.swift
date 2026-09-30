import SwiftUI

struct FeatureCardView: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let color: Color
    let unreadCount: Int

    init(
        title: String,
        subtitle: String,
        systemImage: String,
        color: Color,
        unreadCount: Int = 0
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.color = color
        self.unreadCount = unreadCount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.14))
                    .frame(width: 34, height: 34)

                Image(systemName: systemImage)
                    .font(.subheadline)
                    .foregroundStyle(color)
                    .frame(width: 34, height: 34)

                UnreadBadgeView(count: unreadCount)
                    .offset(x: 8, y: -8)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.black)
                    .foregroundStyle(AppTheme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(subtitle)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.muted)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .padding(10)
        .background(AppTheme.card.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .shadow(color: AppTheme.sidebar.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}