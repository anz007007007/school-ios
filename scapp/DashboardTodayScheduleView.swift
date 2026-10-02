import Combine
import SchoolAPIClient
import SwiftUI

/// Урок в блоке «Расписание на сегодня».
struct TodayLesson: Identifiable, Hashable {
    let number: Int
    let time: String
    let subject: String
    let details: String?

    var id: String { "\(number)|\(time)|\(subject)" }
}

/// Расписание текущего дня для главной. Загружается только при раскрытии блока,
/// чтобы не замедлять открытие главной лишними запросами.
@MainActor
final class DashboardTodayScheduleViewModel: ObservableObject {
    @Published private(set) var lessons: [TodayLesson] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    /// Для кого загружено (день + учитель/ученик). nil — ещё не загружали.
    @Published private(set) var loadedKey: String?

    private var loadingKey: String?

    static var todayWeekday: Int {
        // Calendar: 1 — воскресенье … 7 — суббота; на сервере 1 — понедельник … 7 — воскресенье.
        let weekday = Calendar.current.component(.weekday, from: Date())
        return weekday == 1 ? 7 : weekday - 1
    }

    func loadIfNeeded(api: SchoolAPI, isTeacher: Bool, studentID: Int, force: Bool = false) async {
        let weekday = Self.todayWeekday
        let key = "\(weekday):" + (isTeacher ? "teacher" : "student:\(studentID)")

        if !force && (loadedKey == key || loadingKey == key) {
            return
        }

        loadingKey = key
        isLoading = true
        errorMessage = nil

        do {
            let result: [TodayLesson]

            if isTeacher {
                let response = try await APIRequestService.shared.decode(
                    TeacherScheduleResponseDTO.self,
                    api: api,
                    path: "/api/v1/teacher/schedule",
                    queryItems: [URLQueryItem(name: "weekday", value: "\(weekday)")],
                    logPrefix: "DASHBOARD TODAY SCHEDULE"
                )

                result = response.items
                    .filter { $0.weekday == weekday }
                    .map { lesson in
                        TodayLesson(
                            number: lesson.lesson_number ?? 0,
                            time: Self.timeRange(lesson.starts_at, lesson.ends_at),
                            subject: lesson.subject_name ?? "Урок",
                            details: [
                                lesson.class_name,
                                lesson.room.flatMap { $0.isEmpty ? nil : "каб. \($0)" }
                            ]
                            .compactMap { $0 }
                            .filter { !$0.isEmpty }
                            .joined(separator: " · ")
                            .nilIfEmpty
                        )
                    }
            } else {
                let response = try await APIRequestService.shared.decode(
                    ScheduleListResponseDTO.self,
                    api: api,
                    path: "/api/v1/schedule",
                    queryItems: studentID != 0 ? [URLQueryItem(name: "student_id", value: "\(studentID)")] : [],
                    logPrefix: "DASHBOARD TODAY SCHEDULE"
                )

                result = response.items
                    .filter { $0.weekday == weekday && (studentID == 0 || $0.student_id == nil || $0.student_id == studentID) }
                    .map { lesson in
                        TodayLesson(
                            number: lesson.lesson_number,
                            time: Self.timeRange(lesson.starts_at, lesson.ends_at),
                            subject: lesson.subject_name,
                            details: lesson.room.flatMap { $0.isEmpty ? nil : "каб. \($0)" }
                        )
                    }
            }

            // Пока грузили, могли выбрать другого ребёнка — старый ответ не показываем.
            guard loadingKey == key else {
                return
            }

            var seen = Set<String>()
            lessons = result
                .filter { seen.insert($0.id).inserted }
                .sorted { ($0.number, $0.time) < ($1.number, $1.time) }
            loadedKey = key
            isLoading = false
            loadingKey = nil
        } catch {
            guard loadingKey == key else {
                return
            }

            errorMessage = (error as? APIRequestError)?.localizedDescription
                ?? "Не удалось загрузить расписание"
            isLoading = false
            loadingKey = nil
        }
    }

    private static func timeRange(_ start: String?, _ end: String?) -> String {
        let from = String((start ?? "").prefix(5))
        let to = String((end ?? "").prefix(5))

        if !from.isEmpty && !to.isEmpty {
            return "\(from)–\(to)"
        }

        return from
    }
}

/// Свёрнутый блок «Расписание на сегодня» перед сводкой главной.
struct DashboardTodayScheduleView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = DashboardTodayScheduleViewModel()
    @State private var isExpanded = false

    let isTeacher: Bool
    /// Выбранный ребёнок у родителя, 0 для ученика.
    let studentID: Int
    /// Родитель: ждём выбранного ребёнка, иначе пришли бы уроки всех детей вперемешку.
    var waitForStudent = false

    private var dayTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: Date()).capitalized
    }

    private var subtitle: String {
        guard viewModel.loadedKey != nil, !viewModel.lessons.isEmpty else {
            return dayTitle
        }

        return "\(dayTitle) · \(Self.lessonsCountText(viewModel.lessons.count))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "clock")
                        .font(.title3)
                        .foregroundStyle(AppTheme.primaryDark)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Расписание на сегодня")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(AppTheme.text)

                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(AppTheme.muted)
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.muted)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                content
            }
        }
        .appCard()
        .task(id: "\(isExpanded)|\(isTeacher)|\(studentID)") {
            guard isExpanded, !(waitForStudent && studentID == 0) else {
                return
            }

            await viewModel.loadIfNeeded(api: appState.api, isTeacher: isTeacher, studentID: studentID)
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.isLoading && viewModel.loadedKey == nil {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Загружаем...")
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                }
            } else if let errorMessage = viewModel.errorMessage {
                HStack {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)

                    Spacer()

                    Button("Повторить") {
                        Task {
                            await viewModel.loadIfNeeded(
                                api: appState.api,
                                isTeacher: isTeacher,
                                studentID: studentID,
                                force: true
                            )
                        }
                    }
                    .font(.caption.weight(.semibold))
                }
            } else if viewModel.lessons.isEmpty {
                Text("Сегодня уроков нет")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            } else {
                ForEach(viewModel.lessons) { lesson in
                    lessonRow(lesson)
                }
            }

            HStack {
                Spacer()

                NavigationLink {
                    LazyView { ScheduleView() }
                } label: {
                    Text("Всё расписание")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.primaryDark)
                }
            }
        }
        .transition(.opacity)
    }

    private func lessonRow(_ lesson: TodayLesson) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(lesson.number > 0 ? "\(lesson.number)" : "•")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.primaryDark)
                .frame(width: 18, alignment: .leading)

            Text(lesson.time)
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
                .frame(width: 84, alignment: .leading)

            VStack(alignment: .leading, spacing: 1) {
                Text(lesson.subject)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.text)
                    .lineLimit(1)

                if let details = lesson.details {
                    Text(details)
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                }
            }
        }
    }

    private static func lessonsCountText(_ count: Int) -> String {
        let mod10 = count % 10
        let mod100 = count % 100

        let word: String
        if mod10 == 1 && mod100 != 11 {
            word = "урок"
        } else if (2...4).contains(mod10) && !(12...14).contains(mod100) {
            word = "урока"
        } else {
            word = "уроков"
        }

        return "\(count) \(word)"
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
