import Foundation
import Combine
import SchoolAPIClient

@MainActor
final class DiaryViewModel: ObservableObject {
    @Published var grades: [DiaryGradeDTO] = []
    @Published var averageGrades: [DiaryGradeDTO] = []
    @Published var gradeTypes: [DiaryGradeTypeDTO] = []
    @Published var diaryFilters: DiaryFiltersResponseDTO?
    @Published var selectedSubjectID: Int = 0
    @Published var selectedStudentID: Int = 0
    @Published var selectedPeriod: DiaryPeriod = .quarter
    @Published var searchText = ""
    @Published var calculatedGradesBySubjectID: [Int: DiaryCalculatedGrades] = [:]
    @Published var isLoading = false
    @Published var isLoadingCalculatedGrades = false
    @Published var hasLoadedOnce = false
    @Published var errorMessage: String?

    @Published private(set) var filteredGradesSnapshot: [DiaryGradeDTO] = []
    @Published private(set) var dateColumnsSnapshot: [String] = []
    @Published private(set) var tableRowsSnapshot: [DiaryTableRow] = []
    @Published private(set) var subjectAveragesSnapshot: [DiarySubjectAverage] = []
    @Published private(set) var totalAverageTextSnapshot: String = "—"

    private var loadGeneration = UUID()
    private var calculatedGradesTask: Task<Void, Never>?
    private var searchCancellable: AnyCancellable?

    init() {
        searchCancellable = $searchText
            .removeDuplicates()
            .debounce(for: .milliseconds(180), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.rebuildSnapshots()
                }
            }
    }

    deinit {
        calculatedGradesTask?.cancel()
    }

    enum DiaryPeriod: String, CaseIterable, Identifiable {
        case today = "Сегодня"
        case week = "Неделя"
        case month = "Месяц"
        case quarter = "Четверть"
        case year = "Год"
        case all = "Все"

        var id: String {
            rawValue
        }
    }

    struct DiaryCalculatedGrades: Hashable {
        let quarter: GradeCalculatedPeriodResponseDTO?
        let year: GradeCalculatedPeriodResponseDTO?
    }

    struct DiarySubjectAverage: Identifiable, Hashable {
        let subjectID: Int
        let subjectName: String
        let average: Double?
        let gradesCount: Int
        let todayGradesText: String
        let calculatedQuarterGrade: GradeCalculatedPeriodResponseDTO?
        let calculatedYearGrade: GradeCalculatedPeriodResponseDTO?

        var id: Int {
            subjectID
        }

        var averageText: String {
            guard let average else {
                return "—"
            }

            return String(format: "%.2f", average)
        }

        var calculatedQuarterGradeText: String {
            calculatedQuarterGrade?.calculatedGradeText ?? "—"
        }

        var calculatedYearGradeText: String {
            calculatedYearGrade?.calculatedGradeText ?? "—"
        }
    }

    struct DiaryTableRow: Identifiable, Hashable {
        let subjectID: Int
        let subjectName: String
        let gradesByDate: [String: [DiaryGradeDTO]]
        let calculatedQuarterGrade: GradeCalculatedPeriodResponseDTO?
        let calculatedYearGrade: GradeCalculatedPeriodResponseDTO?

        var id: Int {
            subjectID
        }

        var calculatedQuarterGradeText: String {
            calculatedQuarterGrade?.calculatedGradeText ?? "—"
        }

        var calculatedYearGradeText: String {
            calculatedYearGrade?.calculatedGradeText ?? "—"
        }
    }

    var students: [(id: Int, name: String)] {
        if let filterStudents = diaryFilters?.students,
           !filterStudents.isEmpty {
            return filterStudents
                .filter { $0.id != 0 }
                .map { student in
                    (
                        id: student.id,
                        name: student.name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                            ? student.name!
                            : "Ученик \(student.id)"
                    )
                }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        let pairs = grades.map { ($0.student_id, $0.student_name) }
        var seen = Set<Int>()
        var result: [(id: Int, name: String)] = []

        for pair in pairs {
            if !seen.contains(pair.0) {
                seen.insert(pair.0)
                result.append((id: pair.0, name: pair.1))
            }
        }

        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var subjects: [(id: Int, name: String)] {
        if let filterSubjects = diaryFilters?.subjects,
           !filterSubjects.isEmpty {
            return filterSubjects
                .filter { $0.id != 0 }
                .map { subject in
                    (
                        id: subject.id,
                        name: subject.name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                            ? subject.name!
                            : "Предмет \(subject.id)"
                    )
                }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        let pairs = grades.map { ($0.subject_id, $0.subject_name) }
        var seen = Set<Int>()
        var result: [(id: Int, name: String)] = []

        for pair in pairs {
            if !seen.contains(pair.0) {
                seen.insert(pair.0)
                result.append((id: pair.0, name: pair.1))
            }
        }

        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var filteredGrades: [DiaryGradeDTO] {
        filteredGradesSnapshot
    }

    var dateColumns: [String] {
        dateColumnsSnapshot
    }

    var tableRows: [DiaryTableRow] {
        tableRowsSnapshot
    }

    var subjectAverages: [DiarySubjectAverage] {
        subjectAveragesSnapshot
    }

    var totalAverageText: String {
        totalAverageTextSnapshot
    }

    private var averageSourceGrades: [DiaryGradeDTO] {
        filteredAverageSourceGrades()
    }

    var periodTitle: String {
        guard let range = selectedDateRange else {
            return "Все даты"
        }

        let from = Self.dateFormatter.string(from: range.start)
        let to = Self.dateFormatter.string(from: range.end)

        if from == to {
            return from
        }

        return "\(from) — \(to)"
    }

    var selectedDateRange: (start: Date, end: Date)? {
        let calendar = Calendar.current
        let now = Date()

        switch selectedPeriod {
        case .today:
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: start) ?? start
            return (start, end)

        case .week:
            let interval = calendar.dateInterval(of: .weekOfYear, for: now)
            guard let interval else {
                return nil
            }

            let end = calendar.date(byAdding: .second, value: -1, to: interval.end) ?? interval.end
            return (interval.start, end)

        case .month:
            let interval = calendar.dateInterval(of: .month, for: now)
            guard let interval else {
                return nil
            }

            let end = calendar.date(byAdding: .second, value: -1, to: interval.end) ?? interval.end
            return (interval.start, end)

        case .quarter:
            guard let currentTerm = diaryFilters?.current_term,
                  currentTerm.isQuarter,
                  let range = currentTerm.dateRange else {
                return nil
            }

            let end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: range.end) ?? range.end
            return (range.start, end)

        case .year:
            let interval = calendar.dateInterval(of: .year, for: now)
            guard let interval else {
                return nil
            }

            let end = calendar.date(byAdding: .second, value: -1, to: interval.end) ?? interval.end
            return (interval.start, end)

        case .all:
            return nil
        }
    }

    func loadGrades(api: SchoolAPI) async {
        let generation = UUID()
        loadGeneration = generation
        calculatedGradesTask?.cancel()

        isLoading = true
        errorMessage = nil
        calculatedGradesBySubjectID = [:]
        isLoadingCalculatedGrades = false

        if diaryFilters == nil {
            await loadDiaryFilters(api: api)
        }

        selectDefaultStudentIfNeeded()

        if gradeTypes.isEmpty {
            await loadGradeTypes(api: api)
        }

        do {
            var queryItems: [URLQueryItem] = []

            if let range = selectedDateRange {
                queryItems.append(URLQueryItem(name: "date_from", value: Self.dateFormatter.string(from: range.start)))
                queryItems.append(URLQueryItem(name: "date_to", value: Self.dateFormatter.string(from: range.end)))
            }

            if selectedStudentID != 0 {
                queryItems.append(URLQueryItem(name: "student_id", value: "\(selectedStudentID)"))
            }

            if selectedSubjectID != 0 {
                queryItems.append(URLQueryItem(name: "subject_id", value: "\(selectedSubjectID)"))
            }

            async let gradesDataTask = sendRequest(
                api: api,
                path: "/api/v1/diary/grades",
                method: "GET",
                queryItems: queryItems
            )

            async let averageGradesTask = loadAverageGradesData(api: api)

            let gradesData = try await gradesDataTask

            guard loadGeneration == generation else {
                return
            }

            let decoded = try JSONDecoder().decode(DiaryGradesResponseDTO.self, from: gradesData)
            grades = decoded.items

            if selectedStudentID != 0,
               !students.contains(where: { $0.id == selectedStudentID }) {
                selectedStudentID = students.first?.id ?? 0
            }

            if selectedSubjectID != 0,
               !subjects.contains(where: { $0.id == selectedSubjectID }) {
                selectedSubjectID = 0
            }

            averageGrades = (try? await averageGradesTask) ?? []
            rebuildSnapshots()

            hasLoadedOnce = true
            isLoading = false

            startCalculatedGradesLoading(api: api, generation: generation)
        } catch {
            guard loadGeneration == generation else {
                return
            }

            errorMessage = "Не удалось загрузить оценки: \(error.localizedDescription)"
            grades = []
            averageGrades = []
            calculatedGradesBySubjectID = [:]
            rebuildSnapshots()
            hasLoadedOnce = true
            isLoading = false
            isLoadingCalculatedGrades = false
        }
    }

    private func loadAverageGradesData(api: SchoolAPI) async throws -> [DiaryGradeDTO] {
        var queryItems: [URLQueryItem] = []

        if selectedStudentID != 0 {
            queryItems.append(URLQueryItem(name: "student_id", value: "\(selectedStudentID)"))
        }

        if selectedSubjectID != 0 {
            queryItems.append(URLQueryItem(name: "subject_id", value: "\(selectedSubjectID)"))
        }

        if let currentTerm = diaryFilters?.current_term,
           currentTerm.isQuarter {
            queryItems.append(URLQueryItem(name: "date_from", value: currentTerm.starts_at))
            queryItems.append(URLQueryItem(name: "date_to", value: currentTerm.ends_at))
        }

        let data = try await sendRequest(
            api: api,
            path: "/api/v1/diary/grades",
            method: "GET",
            queryItems: queryItems
        )

        let decoded = try JSONDecoder().decode(DiaryGradesResponseDTO.self, from: data)
        return decoded.items
    }

    private func startCalculatedGradesLoading(
        api: SchoolAPI,
        generation: UUID
    ) {
        guard selectedStudentID != 0 else {
            calculatedGradesBySubjectID = [:]
            rebuildSnapshots()
            return
        }

        let subjectIDs = Array(Set(filteredAverageSourceGrades().map { $0.subject_id }))
            .sorted()

        guard !subjectIDs.isEmpty else {
            calculatedGradesBySubjectID = [:]
            rebuildSnapshots()
            return
        }

        let studentID = selectedStudentID
        isLoadingCalculatedGrades = true

        calculatedGradesTask = Task { [weak self] in
            guard let self else {
                return
            }

            var result: [Int: DiaryCalculatedGrades] = [:]

            for chunk in subjectIDs.chunked(into: 3) {
                if Task.isCancelled {
                    return
                }

                await withTaskGroup(of: (Int, DiaryCalculatedGrades).self) { group in
                    for subjectID in chunk {
                        group.addTask { [weak self] in
                            guard let self else {
                                return (
                                    subjectID,
                                    DiaryCalculatedGrades(quarter: nil, year: nil)
                                )
                            }

                            async let quarterGrade = self.loadCalculatedPeriodGrade(
                                api: api,
                                studentID: studentID,
                                subjectID: subjectID,
                                periodType: "quarter"
                            )

                            async let yearGrade = self.loadCalculatedPeriodGrade(
                                api: api,
                                studentID: studentID,
                                subjectID: subjectID,
                                periodType: "year"
                            )

                            return (
                                subjectID,
                                DiaryCalculatedGrades(
                                    quarter: await quarterGrade,
                                    year: await yearGrade
                                )
                            )
                        }
                    }

                    for await item in group {
                        result[item.0] = item.1
                    }
                }

                await MainActor.run {
                    guard self.loadGeneration == generation else {
                        return
                    }

                    self.calculatedGradesBySubjectID = result
                    self.rebuildSnapshots()
                }
            }

            await MainActor.run {
                guard self.loadGeneration == generation else {
                    return
                }

                self.isLoadingCalculatedGrades = false
            }
        }
    }

    func loadDiaryFilters(api: SchoolAPI) async {
        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/diary/filters",
                method: "GET"
            )

            diaryFilters = try JSONDecoder().decode(DiaryFiltersResponseDTO.self, from: data)
        } catch {
            // Не блокируем дневник полностью: без фильтров будут работать остальные периоды.
        }
    }

    func loadGradeTypes(api: SchoolAPI) async {
        // Сначала пробуем общий справочник
        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/dictionaries/grade-types",
                method: "GET"
            )

            let decoded = try JSONDecoder().decode(DiaryGradeTypesResponseDTO.self, from: data)
            gradeTypes = normalizeGradeTypes(decoded.items)
            rebuildSnapshots()
            return
        } catch {
            print("DIARY DICTIONARY GRADE TYPES LOAD ERROR:", error.localizedDescription)
        }

        // Если общий справочник недоступен, пробуем teacher endpoint
        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/teacher/grade-types",
                method: "GET"
            )

            let decoded = try JSONDecoder().decode(DiaryGradeTypesResponseDTO.self, from: data)
            gradeTypes = normalizeGradeTypes(decoded.items)
            rebuildSnapshots()
        } catch {
            // Не блокируем дневник: если справочник типов недоступен,
            // ниже сработает fallback в gradeTypeTitle(_:).
            print("DIARY TEACHER GRADE TYPES LOAD ERROR:", error.localizedDescription)
        }
    }

    private func normalizeGradeTypes(_ items: [DiaryGradeTypeDTO]) -> [DiaryGradeTypeDTO] {
        items
            .filter { $0.is_active ?? true }
            .sorted {
                if ($0.sort_order ?? Int.max) == ($1.sort_order ?? Int.max) {
                    return $0.displayName < $1.displayName
                }

                return ($0.sort_order ?? Int.max) < ($1.sort_order ?? Int.max)
            }
    }

    func reloadForFilters(api: SchoolAPI) async {
        selectDefaultStudentIfNeeded()
        await loadGrades(api: api)
    }

    private func selectDefaultStudentIfNeeded() {
        let availableStudents = students

        guard !availableStudents.isEmpty else {
            selectedStudentID = 0
            return
        }

        if selectedStudentID == 0
            || !availableStudents.contains(where: { $0.id == selectedStudentID }) {
            selectedStudentID = availableStudents.first?.id ?? 0
        }
    }

    private func rebuildSnapshots() {
        let filtered = makeFilteredGrades()
        filteredGradesSnapshot = filtered

        dateColumnsSnapshot = Set(filtered.map { $0.grade_date })
            .sorted {
                dateForSorting($0) < dateForSorting($1)
            }

        tableRowsSnapshot = makeTableRows(from: filtered)
        subjectAveragesSnapshot = makeSubjectAverages(from: filteredAverageSourceGrades())

        let numbers = filtered.compactMap { gradeNumber($0.grade_value) }

        if numbers.isEmpty {
            totalAverageTextSnapshot = "—"
        } else {
            let average = numbers.reduce(0, +) / Double(numbers.count)
            totalAverageTextSnapshot = String(format: "%.2f", average)
        }
    }

    private func makeFilteredGrades() -> [DiaryGradeDTO] {
        var result = grades

        if let range = selectedDateRange {
            result = result.filter { grade in
                guard let date = parseGradeDate(grade.grade_date) else {
                    return false
                }

                return date >= range.start && date <= range.end
            }
        }

        if selectedStudentID != 0 {
            result = result.filter { $0.student_id == selectedStudentID }
        }

        if selectedSubjectID != 0 {
            result = result.filter { $0.subject_id == selectedSubjectID }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        if !query.isEmpty {
            result = result.filter { gradeMatchesSearch($0, query: query) }
        }

        return result.sorted {
            let lhsDate = dateForSorting($0.grade_date)
            let rhsDate = dateForSorting($1.grade_date)

            if lhsDate == rhsDate {
                if $0.subject_name == $1.subject_name {
                    return $0.id > $1.id
                }

                return $0.subject_name < $1.subject_name
            }

            return lhsDate > rhsDate
        }
    }

    private func filteredAverageSourceGrades() -> [DiaryGradeDTO] {
        var result = averageGrades

        if selectedStudentID != 0 {
            result = result.filter { $0.student_id == selectedStudentID }
        }

        if selectedSubjectID != 0 {
            result = result.filter { $0.subject_id == selectedSubjectID }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        if !query.isEmpty {
            result = result.filter { gradeMatchesSearch($0, query: query) }
        }

        return result
    }

    private func gradeMatchesSearch(
        _ grade: DiaryGradeDTO,
        query: String
    ) -> Bool {
        grade.student_name.localizedCaseInsensitiveContains(query)
        || grade.subject_name.localizedCaseInsensitiveContains(query)
        || grade.class_name.localizedCaseInsensitiveContains(query)
        || grade.grade_value.localizedCaseInsensitiveContains(query)
        || grade.grade_type.localizedCaseInsensitiveContains(query)
        || gradeTypeTitle(grade.grade_type).localizedCaseInsensitiveContains(query)
        || (grade.commentText?.localizedCaseInsensitiveContains(query) ?? false)
        || grade.grade_date.localizedCaseInsensitiveContains(query)
    }

    private func makeTableRows(from grades: [DiaryGradeDTO]) -> [DiaryTableRow] {
        let groupedBySubject = Dictionary(grouping: grades) { grade in
            grade.subject_id
        }

        return groupedBySubject.compactMap { subjectID, grades in
            guard let subjectName = grades.first?.subject_name else {
                return nil
            }

            let byDate = Dictionary(grouping: grades) { grade in
                grade.grade_date
            }

            let calculated = calculatedGradesBySubjectID[subjectID]

            return DiaryTableRow(
                subjectID: subjectID,
                subjectName: subjectName,
                gradesByDate: byDate,
                calculatedQuarterGrade: calculated?.quarter,
                calculatedYearGrade: calculated?.year
            )
        }
        .sorted { $0.subjectName < $1.subjectName }
    }

    private func makeSubjectAverages(from grades: [DiaryGradeDTO]) -> [DiarySubjectAverage] {
        let grouped = Dictionary(grouping: grades) { grade in
            grade.subject_id
        }

        let today = Self.dateFormatter.string(from: Date())

        return grouped.compactMap { subjectID, grades in
            guard let subjectName = grades.first?.subject_name else {
                return nil
            }

            let values = grades.compactMap { gradeNumber($0.grade_value) }

            let average: Double?
            if values.isEmpty {
                average = nil
            } else {
                average = values.reduce(0, +) / Double(values.count)
            }

            let todayGrades = grades
                .filter { grade in
                    guard let gradeDate = parseGradeDate(grade.grade_date) else {
                        return false
                    }

                    return Self.dateFormatter.string(from: gradeDate) == today
                }
                .sorted {
                    $0.id < $1.id
                }
                .map(\.grade_value)

            let calculated = calculatedGradesBySubjectID[subjectID]

            return DiarySubjectAverage(
                subjectID: subjectID,
                subjectName: subjectName,
                average: average,
                gradesCount: grades.count,
                todayGradesText: todayGrades.isEmpty ? "—" : todayGrades.joined(separator: ", "),
                calculatedQuarterGrade: calculated?.quarter,
                calculatedYearGrade: calculated?.year
            )
        }
        .sorted { $0.subjectName < $1.subjectName }
    }

    private func loadCalculatedPeriodGrade(
        api: SchoolAPI,
        studentID: Int,
        subjectID: Int,
        periodType: String
    ) async -> GradeCalculatedPeriodResponseDTO? {
        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/mobile/grades/calculated-period-grade",
                method: "GET",
                queryItems: [
                    URLQueryItem(name: "student_id", value: "\(studentID)"),
                    URLQueryItem(name: "subject_id", value: "\(subjectID)"),
                    URLQueryItem(name: "period_type", value: periodType)
                ]
            )

            return try JSONDecoder().decode(GradeCalculatedPeriodResponseDTO.self, from: data)
        } catch {
            print("DIARY CALCULATED GRADE LOAD ERROR:", error.localizedDescription)
            return nil
        }
    }

    func gradeTypeTitle(_ value: String) -> String {
        let cleanValue = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if let gradeType = gradeTypes.first(where: { $0.code == cleanValue }) {
            return gradeType.displayName
        }

        switch cleanValue {
        case "regular":
            return "Текущая"
        case "lesson":
            return "Урок"
        case "homework":
            return "Домашняя"
        case "test":
            return "Контрольная"
        case "exam":
            return "Аттестация"
        case "term":
            return "Итоговая"
        case "rabota_urok":
            return "Работа на уроке"
        case "rabotaosh":
            return "Работа над ошибками"
        case "test1":
            return "Test"
        default:
            return cleanValue
        }
    }

    func monthTitle(for dateString: String) -> String {
        guard let date = parseGradeDate(dateString) else {
            return ""
        }

        return Self.monthFormatter.string(from: date)
    }

    func dayTitle(for dateString: String) -> String {
        guard let date = parseGradeDate(dateString) else {
            return dateString
        }

        return Self.dayFormatter.string(from: date)
    }

    func gradeNumber(_ value: String) -> Double? {
        Double(value.replacingOccurrences(of: ",", with: "."))
    }

    private func dateForSorting(_ value: String) -> Date {
        parseGradeDate(value) ?? Date.distantPast
    }

    private func parseGradeDate(_ value: String) -> Date? {
        if let date = Self.dateFormatter.date(from: value) {
            return date
        }

        for formatter in Self.fallbackDateFormatters {
            if let date = formatter.date(from: value) {
                return date
            }
        }

        return nil
    }

    private func sendRequest(
        api: SchoolAPI,
        path: String,
        method: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> Data {
        guard let token = api.authToken else {
            throw DiaryError.noToken
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "sc.it-status.ru"
        components.path = path
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw DiaryError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.applyMobileClientHeaders()

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DiaryError.badResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw DiaryError.serverError(statusCode: httpResponse.statusCode, text: text)
        }

        return data
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    private static let fallbackDateFormatters: [DateFormatter] = {
        let formats = [
            "dd.MM.yyyy",
            "dd.MM.yyyy HH:mm:ss",
            "dd.MM.yyyy HH:mm",
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm"
        ]

        return formats.map { format in
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "ru_RU")
            formatter.timeZone = TimeZone.current
            return formatter
        }
    }()

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter
    }()
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else {
            return [self]
        }

        return stride(from: 0, to: count, by: size).map { index in
            Array(self[index..<Swift.min(index + size, count)])
        }
    }
}

enum DiaryError: LocalizedError {
    case noToken
    case badURL
    case badResponse
    case serverError(statusCode: Int, text: String)

    var errorDescription: String? {
        switch self {
        case .noToken:
            return "Нет токена авторизации. Войдите снова."
        case .badURL:
            return "Некорректный URL."
        case .badResponse:
            return "Некорректный ответ сервера."
        case .serverError(let statusCode, let text):
            if text.isEmpty {
                return "Ошибка сервера: \(statusCode)"
            } else {
                return "Ошибка сервера: \(statusCode). \(text)"
            }
        }
    }
}