import SwiftUI

enum AppTheme {
    // MARK: - Base palette

    static let background = Color(red: 1.0, green: 0.965, blue: 0.835)
    static let backgroundSoft = Color(red: 1.0, green: 0.902, blue: 0.580)
    static let backgroundWarm = Color(red: 1.0, green: 0.988, blue: 0.940)

    static let card = Color.white
    static let cardSoft = Color(red: 1.0, green: 0.985, blue: 0.925)

    static let text = Color(red: 0.145, green: 0.090, blue: 0.020)
    static let muted = Color(red: 0.430, green: 0.315, blue: 0.110)

    static let primary = Color(red: 1.0, green: 0.720, blue: 0.120)
    static let primaryDark = Color(red: 0.850, green: 0.430, blue: 0.030)
    static let primarySoft = Color(red: 1.0, green: 0.890, blue: 0.560)

    static let accent = Color(red: 0.830, green: 0.180, blue: 0.080)
    static let accentDark = Color(red: 0.530, green: 0.130, blue: 0.030)

    static let sidebar = Color(red: 1.0, green: 0.894, blue: 0.520)
    static let sidebarSecond = Color(red: 1.0, green: 0.788, blue: 0.255)

    static let border = Color(red: 0.900, green: 0.660, blue: 0.240)

    static let success = Color(red: 0.050, green: 0.520, blue: 0.230)
    static let successSoft = Color(red: 0.880, green: 0.970, blue: 0.900)

    static let danger = Color(red: 0.820, green: 0.120, blue: 0.120)
    static let dangerSoft = Color(red: 1.0, green: 0.910, blue: 0.890)

    static let warning = Color(red: 0.780, green: 0.380, blue: 0.030)
    static let warningSoft = Color(red: 1.0, green: 0.930, blue: 0.710)

    static let heading = Color(red: 0.380, green: 0.130, blue: 0.025)
    static let brownText = Color(red: 0.300, green: 0.190, blue: 0.055)

    // Единый цвет для обычных иконок, ссылок, кнопок в списках и меню.
    static let control = primaryDark

    // Единый цвет для декоративных иконок вместо системного синего.
    static let icon = Color(red: 0.760, green: 0.330, blue: 0.030)

    static let iconSoft = Color(red: 1.0, green: 0.910, blue: 0.650)

    static let radius: CGFloat = 20

    // MARK: - Gradients

    static let mainGradient = LinearGradient(
        colors: [
            backgroundWarm,
            background,
            backgroundSoft.opacity(0.55)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let navGradient = LinearGradient(
        colors: [
            sidebar,
            sidebarSecond
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let buttonGradient = LinearGradient(
        colors: [
            primary,
            primaryDark
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let dangerGradient = LinearGradient(
        colors: [
            danger,
            Color(red: 0.560, green: 0.050, blue: 0.050)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct AppLogoView: View {
    var size: CGFloat = 76

    var body: some View {
        Image("SchoolLogo")
            .resizable()
            .scaledToFit()
            .padding(size * 0.08)
            .frame(width: size, height: size)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.28))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.28)
                    .stroke(AppTheme.primary.opacity(0.55), lineWidth: 1)
            )
            .shadow(color: AppTheme.accentDark.opacity(0.22), radius: 18, x: 0, y: 10)
    }
}

struct AppPrimaryButtonStyle: ButtonStyle {
    var isDanger = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.black)
            .foregroundStyle(Color.white)
            .padding(.vertical, 13)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(isDanger ? AppTheme.dangerGradient : AppTheme.buttonGradient)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
            )
            .shadow(
                color: (isDanger ? AppTheme.danger : AppTheme.primaryDark).opacity(configuration.isPressed ? 0.14 : 0.28),
                radius: configuration.isPressed ? 6 : 14,
                x: 0,
                y: configuration.isPressed ? 4 : 8
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct AppSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.bold)
            .foregroundStyle(AppTheme.heading)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(AppTheme.primarySoft.opacity(0.95))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppTheme.primaryDark.opacity(0.45), lineWidth: 1)
            )
            .shadow(color: AppTheme.primaryDark.opacity(0.10), radius: 8, x: 0, y: 4)
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}

struct AppCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(AppTheme.card.opacity(0.98))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radius)
                    .stroke(AppTheme.border.opacity(0.65), lineWidth: 1)
            )
            .shadow(color: AppTheme.accentDark.opacity(0.13), radius: 22, x: 0, y: 12)
    }
}

struct AppFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundColor(AppTheme.text)
            .tint(AppTheme.control)
            .padding(14)
            .background(AppTheme.cardSoft)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppTheme.border.opacity(0.85), lineWidth: 1)
            )
    }
}

struct AppNavigationStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.sidebar, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .tint(AppTheme.control)
    }
}

struct AppPlainListButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(AppTheme.control)
            .opacity(configuration.isPressed ? 0.65 : 1)
    }
}

struct AppChipModifier: ViewModifier {
    var isSelected = false

    func body(content: Content) -> some View {
        content
            .fontWeight(.bold)
            .foregroundStyle(isSelected ? Color.white : AppTheme.heading)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isSelected ? AppTheme.primaryDark : AppTheme.primarySoft.opacity(0.70))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(AppTheme.border.opacity(0.75), lineWidth: 1)
            )
    }
}

// MARK: - Готовые модификаторы для всех экранов

struct AppThemedListModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .appScreenBackground()
            .tint(AppTheme.control)
            .preferredColorScheme(.light)
    }
}

struct AppThemedFormModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .appScreenBackground()
            .tint(AppTheme.control)
            .preferredColorScheme(.light)
    }
}

extension View {
    func appCard() -> some View {
        modifier(AppCardModifier())
    }

    func appField() -> some View {
        modifier(AppFieldModifier())
    }

    func appNavigationStyle() -> some View {
        modifier(AppNavigationStyleModifier())
    }

    func appPlainListButton() -> some View {
        buttonStyle(AppPlainListButtonStyle())
    }

    func appChip(isSelected: Bool = false) -> some View {
        modifier(AppChipModifier(isSelected: isSelected))
    }

    func appThemedList() -> some View {
        modifier(AppThemedListModifier())
    }

    func appThemedForm() -> some View {
        modifier(AppThemedFormModifier())
    }

    func appScreenBackground() -> some View {
        background(
            ZStack {
                AppTheme.mainGradient
                    .ignoresSafeArea()

                Circle()
                    .fill(AppTheme.primary.opacity(0.24))
                    .frame(width: 360, height: 360)
                    .blur(radius: 34)
                    .offset(x: -190, y: -270)

                Circle()
                    .fill(AppTheme.accent.opacity(0.10))
                    .frame(width: 300, height: 300)
                    .blur(radius: 34)
                    .offset(x: 200, y: -230)

                Circle()
                    .fill(AppTheme.primaryDark.opacity(0.13))
                    .frame(width: 320, height: 320)
                    .blur(radius: 38)
                    .offset(x: 180, y: 360)
            }
        )
    }
}