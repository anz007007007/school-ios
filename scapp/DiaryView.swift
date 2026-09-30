import SwiftUI

struct DiaryView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = DiaryViewModel()
    @State private var selectedTableGrade: DiaryGradeDTO?
    @State private var isFiltersExpanded = false

    var body: some View {
        NavigationStack {
            List {
                filtersSection

                if !viewModel.grades.isEmpty {
                    Section("Таблица оценок") {
                        gradesTableView
                    }

                    Section("Средние оценки") {
                        averagesView
                    }
                }

                detailsSection
            }
            .appThemedList()
            .navigationTitle("Дневник")
            .searchable(text: $viewModel.searchText, prompt: "Поиск")
            .refreshable {
                await viewModel.loadGrades(api: appState.api)
            }
            .task {
                await appState.markNotificationsReadForRoute(.diary(notificationID: nil))
                PushNotificationService.shared.clearLatestRemoteNotification()

                if viewModel.grades.isEmpty {
                    await viewModel.loadGrades(api: appState.api)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await viewModel.loadGrades(api: appState.api)
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(item: $selectedTableGrade) { grade in
                DiaryGradeDetailsSheetView(
                    grade: grade,
                    gradeTypeTitle: viewModel.gradeTypeTitle(grade.grade_type)
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private var filtersSection: some View {
        Section {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isFiltersExpanded.toggle()
                }
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            .foregroundStyle(.blue)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Фильтры")
                                .font(.headline)
                                .foregroundStyle(.primary)

                            Text(filtersSummaryText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        Spacer()

                        Image(systemName: isFiltersExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                    }

                    if !viewModel.grades.isEmpty {
                        diaryHeaderStatsView
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isFiltersExpanded {
                Picker("Период", selection: $viewModel.selectedPeriod) {
                    ForEach(DiaryViewModel.DiaryPeriod.allCases) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: viewModel.selectedPeriod) {
                    Task {
                        await viewModel.reloadForFilters(api: appState.api)
                    }
                }

                LabeledContent("Диапазон", value: viewModel.periodTitle)

                if !viewModel.students.isEmpty {
                    Picker("Ученик", selection: $viewModel.selectedStudentID) {
                        ForEach(viewModel.students, id: \.id) { student in
                            Text(student.name).tag(student.id)
                        }
                    }
                    .onChange(of: viewModel.selectedStudentID) {
                        Task {
                            await viewModel.reloadForFilters(api: appState.api)
                        }
                    }
                }

                if !viewModel.subjects.isEmpty {
                    Picker("Предмет", selection: $viewModel.selectedSubjectID) {
                        Text("Все предметы").tag(0)

                        ForEach(viewModel.subjects, id: \.id) { subject in
                            Text(subject.name).tag(subject.id)
                        }
                    }
                    .onChange(of: viewModel.selectedSubjectID) {
                        Task {
                            await viewModel.reloadForFilters(api: appState.api)
                        }
                    }
                }
            }
        }
    }

    private var filtersSummaryText: String {
        var parts: [String] = [
            viewModel.selectedPeriod.rawValue,
            viewModel.periodTitle
        ]

        if let student = viewModel.students.first(where: { $0.id == viewModel.selectedStudentID }) {
            parts.append(student.name)
        }

        if viewModel.selectedSubjectID != 0,
           let subject = viewModel.subjects.first(where: { $0.id == viewModel.selectedSubjectID }) {
            parts.append(subject.name)
        } else {
            parts.append("Все предметы")
        }

        return parts.joined(separator: " · ")
    }

    private var diaryHeaderStatsView: some View {
        HStack(spacing: 8) {
            diaryHeaderStatItem(
                title: "Оценок",
                value: "\(viewModel.filteredGrades.count)",
                color: .blue,
                systemImage: "list.bullet"
            )

            diaryHeaderStatItem(
                title: "Средний",
                value: viewModel.totalAverageText,
                color: .green,
                systemImage: "chart.bar.fill"
            )

            diaryHeaderStatItem(
                title: "Предметов",
                value: "\(viewModel.subjectAverages.count)",
                color: .orange,
                systemImage: "book.fill"
            )
        }
    }

    private func diaryHeaderStatItem(
        title: String,
        value: String,
        color: Color,
        systemImage: String
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption2)
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)

                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var averagesView: some View {
        VStack(spacing: 0) {
            if viewModel.subjectAverages.isEmpty {
                Text("Нет данных для расчёта средних оценок")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 4) {
                    Text("Предмет")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("Кол")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 28, alignment: .center)

                    Text("Сегодня")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 58, alignment: .center)

                    Text("Ср")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 42, alignment: .trailing)

                    Text("Чтв")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 32, alignment: .center)

                    Text("Год")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 32, alignment: .center)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .background(.blue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                if viewModel.isLoadingCalculatedGrades {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.75)

                        Text("Итоговые оценки рассчитываются в фоне")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }

                ForEach(Array(viewModel.subjectAverages.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 4) {
                        Text(item.subjectName)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("\(item.gradesCount)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 28, alignment: .center)

                        Text(item.todayGradesText)
                            .font(.caption2)
                            .fontWeight(item.todayGradesText == "—" ? .regular : .bold)
                            .foregroundColor(item.todayGradesText == "—" ? Color.secondary : Color.blue)
                            .frame(width: 58, alignment: .center)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        Text(item.averageText)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(averageColor(item.average))
                            .frame(width: 42, alignment: .trailing)
                            .minimumScaleFactor(0.85)

                        calculatedGradeTableBadge(item.calculatedQuarterGradeText)
                            .frame(width: 32, alignment: .center)

                        calculatedGradeTableBadge(item.calculatedYearGradeText)
                            .frame(width: 32, alignment: .center)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)

                    if index != viewModel.subjectAverages.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }

    private var gradesTableView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.tableRows.isEmpty || viewModel.dateColumns.isEmpty {
                Text("Нет оценок для таблицы")
                    .foregroundStyle(.secondary)
            } else {
                HStack(alignment: .top, spacing: 0) {
                    fixedSubjectColumn

                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: true) {
                            scrollableGradesColumns
                        }
                        .onAppear {
                            scrollToFocusedDate(with: proxy)
                        }
                        .onChange(of: viewModel.dateColumns) {
                            scrollToFocusedDate(with: proxy)
                        }
                        .onChange(of: viewModel.selectedPeriod) {
                            scrollToFocusedDate(with: proxy)
                        }
                        .onChange(of: viewModel.selectedStudentID) {
                            scrollToFocusedDate(with: proxy)
                        }
                        .onChange(of: viewModel.selectedSubjectID) {
                            scrollToFocusedDate(with: proxy)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var fixedSubjectColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Предмет")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .padding(.horizontal, 6)
                .frame(width: 92, height: 50, alignment: .leading)
                .background(.blue.opacity(0.08))

            Divider()

            ForEach(viewModel.tableRows) { row in
                Text(row.subjectName)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 6)
                    .frame(width: 92, height: 46, alignment: .leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .background(Color(uiColor: .systemBackground))

                Divider()
            }
        }
        .frame(width: 92, alignment: .leading)
        .fixedSize(horizontal: true, vertical: false)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(.separator.opacity(0.45))
                .frame(width: 1)
        }
        .zIndex(1)
    }

    private var scrollableGradesColumns: some View {
        VStack(alignment: .leading, spacing: 0) {
            scrollableTableHeader

            Divider()

            ForEach(viewModel.tableRows) { row in
                scrollableTableRow(row)
                Divider()
            }
        }
    }

    private var scrollableTableHeader: some View {
        HStack(spacing: 0) {
            ForEach(viewModel.dateColumns, id: \.self) { date in
                VStack(spacing: 2) {
                    Text(viewModel.monthTitle(for: date))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Text(viewModel.dayTitle(for: date))
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .frame(width: 54, height: 50)
                .background(date == focusedTableDate ? .blue.opacity(0.16) : .blue.opacity(0.08))
                .id(date)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func scrollableTableRow(_ row: DiaryViewModel.DiaryTableRow) -> some View {
        HStack(spacing: 0) {
            ForEach(viewModel.dateColumns, id: \.self) { date in
                let grades = row.gradesByDate[date] ?? []

                VStack(spacing: 2) {
                    if grades.isEmpty {
                        Text("—")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    } else {
                        ForEach(grades.prefix(2)) { grade in
                            Button {
                                selectedTableGrade = grade
                            } label: {
                                Text(grade.grade_value)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .frame(width: 30, height: 22)
                                    .background(gradeColor(grade.grade_value).opacity(0.15))
                                    .foregroundStyle(gradeColor(grade.grade_value))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                            .simultaneousGesture(
                                TapGesture()
                                    .onEnded {
                                        selectedTableGrade = grade
                                    }
                            )
                            .accessibilityLabel("Оценка \(grade.grade_value). Нажмите, чтобы посмотреть подробности.")
                        }

                        if grades.count > 2 {
                            Button {
                                selectedTableGrade = grades[2]
                            } label: {
                                Text("+\(grades.count - 2)")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Ещё \(grades.count - 2) оценок. Нажмите, чтобы посмотреть следующую.")
                        }
                    }
                }
                .frame(width: 54, height: 46)
                .background(date == focusedTableDate ? Color.blue.opacity(0.045) : Color.clear)
            }
        }
    }

    private var focusedTableDate: String? {
        let columns = viewModel.dateColumns

        guard !columns.isEmpty else {
            return nil
        }

        let today = Self.tableDateFormatter.string(from: Date())

        if columns.contains(today) {
            return today
        }

        return columns.last
    }

    private func scrollToFocusedDate(with proxy: ScrollViewProxy) {
        guard let focusedTableDate else {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo(focusedTableDate, anchor: .center)
            }
        }
    }

    private var detailsSection: some View {
        Section("Подробно") {
            if viewModel.isLoading || !viewModel.hasLoadedOnce {
                HStack {
                    Spacer()
                    ProgressView("Загрузка...")
                    Spacer()
                }
                .padding(.vertical)
            } else if let errorMessage = viewModel.errorMessage {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Ошибка", systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundStyle(.orange)

                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button("Повторить") {
                        Task {
                            await viewModel.loadGrades(api: appState.api)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.vertical)
            } else if viewModel.filteredGrades.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)

                    Text("Оценки не найдены")
                        .font(.headline)

                    Text("За выбранный период оценок нет.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            } else {
                ForEach(viewModel.filteredGrades) { grade in
                    DiaryGradeRowView(
                        grade: grade,
                        gradeTypeTitle: viewModel.gradeTypeTitle(grade.grade_type)
                    )
                }
            }
        }
    }

    private func calculatedGradeInfoBadge(title: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.caption)
                .fontWeight(.bold)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(calculatedGradeColor(value).opacity(0.14))
                .foregroundStyle(calculatedGradeColor(value))
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func calculatedGradeTableBadge(_ value: String) -> some View {
        Text(value)
            .font(.caption2)
            .fontWeight(.bold)
            .frame(width: 24, height: 22)
            .background(calculatedGradeColor(value).opacity(0.14))
            .foregroundStyle(calculatedGradeColor(value))
            .clipShape(Capsule())
    }

    private static let tableDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    private func gradeColor(_ value: String) -> Color {
        guard let number = Int(value) else {
            return .blue
        }

        switch number {
        case 5:
            return .green
        case 4:
            return .blue
        case 3:
            return .orange
        default:
            return .red
        }
    }

    private func averageColor(_ value: Double?) -> Color {
        guard let value else {
            return .secondary
        }

        switch value {
        case 4.5...:
            return .green
        case 3.5..<4.5:
            return .blue
        case 2.5..<3.5:
            return .orange
        default:
            return .red
        }
    }

    private func calculatedGradeColor(_ value: String) -> Color {
        switch value {
        case "5":
            return .green
        case "4":
            return .blue
        case "3":
            return .orange
        case "2":
            return .red
        default:
            return .secondary
        }
    }
}

struct DiaryGradeRowView: View {
    let grade: DiaryGradeDTO
    let gradeTypeTitle: String

    var body: some View {
        HStack(spacing: 12) {
            gradeBadge

            VStack(alignment: .leading, spacing: 4) {
                Text(grade.subject_name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(grade.student_name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("\(grade.class_name) · \(gradeTypeTitle)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(grade.grade_date)
                    .font(.caption)
                    .foregroundStyle(.blue)

                if let commentText = grade.comment, !commentText.isEmpty {
                    Label(commentText, systemImage: "text.bubble.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .padding(.top, 2)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var gradeBadge: some View {
        Text(grade.grade_value)
            .font(.title3)
            .fontWeight(.bold)
            .frame(width: 48, height: 48)
            .background(gradeColor.opacity(0.15))
            .foregroundStyle(gradeColor)
            .clipShape(Circle())
    }

    private var gradeColor: Color {
        guard let value = Int(grade.grade_value) else {
            return .blue
        }

        switch value {
        case 5:
            return .green
        case 4:
            return .blue
        case 3:
            return .orange
        default:
            return .red
        }
    }
}

struct DiaryGradeDetailsSheetView: View {
    let grade: DiaryGradeDTO
    let gradeTypeTitle: String

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Text(grade.grade_value)
                            .font(.system(size: 34, weight: .black))
                            .frame(width: 64, height: 64)
                            .background(gradeColor.opacity(0.15))
                            .foregroundStyle(gradeColor)
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 5) {
                            Text(grade.subject_name)
                                .font(.headline)
                                .foregroundStyle(.primary)

                            Text(grade.student_name)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text(grade.grade_date)
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Основное") {
                    detailRow(title: "Тип оценки", value: gradeTypeTitle)
                    detailRow(title: "Предмет", value: grade.subject_name)
                    detailRow(title: "Ученик", value: grade.student_name)
                    detailRow(title: "Класс", value: grade.class_name)
                    detailRow(title: "Дата", value: grade.grade_date)

                    if let weight = grade.gradeWeightText {
                        detailRow(title: "Вес", value: weight)
                    }

                    if let period = grade.periodDisplayName {
                        detailRow(title: "Период", value: period)
                    }
                }

                if grade.teacherDisplayName != nil
                    || grade.lessonTopicText != nil
                    || grade.homeworkTitleText != nil {
                    Section("Дополнительно") {
                        if let teacher = grade.teacherDisplayName {
                            detailRow(title: "Кто поставил", value: teacher)
                        }

                        if let topic = grade.lessonTopicText {
                            detailRow(title: "Тема урока", value: topic)
                        }

                        if let homework = grade.homeworkTitleText {
                            detailRow(title: "Домашнее задание", value: homework)
                        }
                    }
                }

                if let comment = grade.commentText {
                    Section("Комментарий") {
                        Text(comment)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if grade.createdAtText != nil || grade.updatedAtText != nil {
                    Section("Служебная информация") {
                        detailRow(title: "ID оценки", value: "\(grade.id)")

                        if let createdAt = grade.createdAtText {
                            detailRow(title: "Создано", value: createdAt)
                        }

                        if let updatedAt = grade.updatedAtText {
                            detailRow(title: "Обновлено", value: updatedAt)
                        }
                    }
                }
            }
            .navigationTitle("Оценка")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }

    private var gradeColor: Color {
        guard let value = Int(grade.grade_value) else {
            return .blue
        }

        switch value {
        case 5:
            return .green
        case 4:
            return .blue
        case 3:
            return .orange
        default:
            return .red
        }
    }
}