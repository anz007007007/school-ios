import SwiftUI
import UIKit

/// Праздничная иконка приложения. Иконки встроены в приложение (AppIcon-<код> в Assets),
/// код приходит из mobile-config.app_icon — расписание праздников в веб-админке.
/// iOS при смене значка всегда показывает системное сообщение — это нельзя отключить.
@MainActor
enum AppIconSwitcher {
    /// Коды должны совпадать с app/services/app_icons.py на сервере.
    static let holidayCodes: Set<String> = [
        "new_year", "defender_day", "march8", "cosmonautics", "victory_day", "last_bell",
        "children_day", "knowledge_day", "teacher_day", "halloween", "mother_day"
    ]

    static func apply(_ code: String?) {
        let application = UIApplication.shared

        guard application.supportsAlternateIcons else {
            return
        }

        let desired = code.flatMap { holidayCodes.contains($0) ? "AppIcon-\($0)" : nil }

        guard application.alternateIconName != desired else {
            return
        }

        application.setAlternateIconName(desired) { error in
            if let error {
                print("APP ICON CHANGE ERROR:", error.localizedDescription)
            }
        }
    }
}

/// Праздничная анимация: что летит и как, плюс короткое поздравление.
private struct HolidayTheme {
    let greeting: String
    let symbols: [String]
    /// true — частицы поднимаются (шарики), false — падают.
    var rises = false
}

private let holidayThemes: [String: HolidayTheme] = [
    "new_year": HolidayTheme(greeting: "С Новым годом!", symbols: ["❄️", "❄️", "❄️", "🎄", "⭐"]),
    "defender_day": HolidayTheme(greeting: "С Днём защитника Отечества!", symbols: ["⭐", "🎖️", "⭐"]),
    "march8": HolidayTheme(greeting: "С 8 Марта!", symbols: ["🌷", "🌸", "💐", "🌷"]),
    "cosmonautics": HolidayTheme(greeting: "С Днём космонавтики!", symbols: ["⭐", "🚀", "🌟", "🪐"]),
    "victory_day": HolidayTheme(greeting: "С Днём Победы!", symbols: ["🎆", "⭐", "🎇", "🌟"]),
    "last_bell": HolidayTheme(greeting: "С последним звонком!", symbols: ["🔔", "🎉", "🎊"]),
    "children_day": HolidayTheme(greeting: "С Днём защиты детей!", symbols: ["🎈", "🎈", "🎈", "🎉"], rises: true),
    "knowledge_day": HolidayTheme(greeting: "С Днём знаний!", symbols: ["📚", "✏️", "🍂", "🎒", "🍁"]),
    "teacher_day": HolidayTheme(greeting: "С Днём учителя!", symbols: ["🍁", "🍂", "💐", "🍎"]),
    "halloween": HolidayTheme(greeting: "Счастливого Хэллоуина!", symbols: ["🎃", "🍬", "🦇", "👻"]),
    "mother_day": HolidayTheme(greeting: "С Днём матери!", symbols: ["💖", "🌷", "💕", "🌸"])
]

private struct HolidayParticle {
    let x: Double
    let delay: Double
    let size: Double
    let sway: Double
    let swayPhase: Double
    let spin: Double
    let symbol: String
}

/// Один показ за запуск приложения, чтобы не надоедало при каждом возврате на главную.
@MainActor
private enum HolidayCelebrationState {
    static var shownThisLaunch = Set<String>()
}

/// Лёгкая праздничная анимация поверх экрана: частицы ~6 секунд и поздравление, потом всё
/// исчезает. Нажатия не перехватывает; при «Уменьшении движения» не показывается.
struct HolidayCelebrationView: View {
    let holidayCode: String?

    @State private var startDate: Date?
    @State private var isFinished = false

    private let duration: TimeInterval = 6.5

    var body: some View {
        if let code = holidayCode,
           let theme = holidayThemes[code],
           !isFinished,
           !UIAccessibility.isReduceMotionEnabled {
            content(code: code, theme: theme)
        }
    }

    private func content(code: String, theme: HolidayTheme) -> some View {
        let particles = Self.particles(for: code, theme: theme)

        return TimelineView(.animation) { timeline in
            let progress = startDate.map { min(1, timeline.date.timeIntervalSince($0) / duration) } ?? 0
            let opacity = progress < 0.08 ? progress / 0.08 : (progress > 0.85 ? (1 - progress) / 0.15 : 1)

            ZStack(alignment: .top) {
                Canvas { context, size in
                    for particle in particles {
                        let local = min(1, max(0, (progress - particle.delay) / (1 - particle.delay)))

                        guard local > 0, local < 1 else {
                            continue
                        }

                        let travel = size.height + particle.size * 2
                        let y = theme.rises
                            ? size.height + particle.size - travel * local
                            : -particle.size + travel * local
                        let x = particle.x * size.width + sin(local * 6 + particle.swayPhase) * particle.sway

                        var symbolContext = context
                        symbolContext.translateBy(x: x, y: y)
                        symbolContext.rotate(by: .degrees(particle.spin * local))
                        symbolContext.draw(
                            Text(particle.symbol).font(.system(size: particle.size)),
                            at: .zero
                        )
                    }
                }

                Text(theme.greeting)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.heading)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    .background(Color.white.opacity(0.92), in: Capsule())
                    .padding(.top, 70)
            }
            .opacity(max(0, min(1, opacity)))
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .task(id: code) {
            guard !HolidayCelebrationState.shownThisLaunch.contains(code) else {
                isFinished = true
                return
            }

            HolidayCelebrationState.shownThisLaunch.insert(code)
            startDate = Date()
            try? await Task.sleep(for: .seconds(duration))
            isFinished = true
        }
    }

    private static func particles(for code: String, theme: HolidayTheme) -> [HolidayParticle] {
        var generator = SeededGenerator(seed: UInt64(truncatingIfNeeded: code.hashValue))

        return (0..<26).map { _ in
            HolidayParticle(
                x: Double.random(in: 0...1, using: &generator),
                delay: Double.random(in: 0...0.45, using: &generator),
                size: Double.random(in: 18...32, using: &generator),
                sway: Double.random(in: 12...40, using: &generator),
                swayPhase: Double.random(in: 0...(2 * .pi), using: &generator),
                spin: Double.random(in: -110...110, using: &generator),
                symbol: theme.symbols.randomElement(using: &generator) ?? "✨"
            )
        }
    }
}

/// Детерминированный генератор, чтобы частицы не «перемешивались» при перерисовке.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
