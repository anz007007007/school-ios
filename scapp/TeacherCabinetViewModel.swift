import Foundation
import Combine
import SchoolAPIClient

@MainActor
final class TeacherCabinetViewModel: ObservableObject {
    @Published var classes: [TeacherClassDTO] = []
    @Published var subjects: [TeacherSubjectDTO] = []
    @Published var gradeTypes: [TeacherGradeTypeDTO] = []
    @Published var students: [TeacherStudentDTO] = []
    @Published var grades: [TeacherGradeDTO] = []
    @Published var homework: [TeacherHomeworkDTO] = []
    @Published var attendance: [TeacherAttendanceDTO] = []
    @Published var terms: [TeacherTermDTO] = []
    @Published var schedule: [TeacherScheduleLessonDTO] = []
    @Published var gradebook: [TeacherGradebookStudentDTO] = []
    @Published var access: TeacherAccessResponseDTO?

    @Published var selectedClassID: Int = 0
    @Published var selectedSubjectID: Int = 0
    @Published var selectedStudentID: Int = 0
    @Published var selectedJournalDate: Date = Date()
    @Published var gradesSelectedClassID: Int = 0
    @Published var gradesSelectedSubjectID: Int = 0
    @Published var gradesSelectedStudentID: Int = 0
    @Published var gradesSelectedType: String = "all"
    @Published var gradesDateFilter: GradesDateFilter = .currentWeek
    @Published var gradesSearchText = ""
    @Published var finalGradesSelectedTermID: Int = 0
    @Published var finalGradesGradeScope: FinalGradeScope = .term
    @Published var finalGradesAcademicYear: String = ""
    @Published var isLoadingGradebook = false

    @Published var attendanceSelectedClassID: Int = 0
    @Published var attendanceSelectedLessonID: Int = 0
    @Published var attendanceSelectedDate: Date = Date()
    @Published var attendanceLessons: [TeacherScheduleLessonDTO] = []
    @Published var isLoadingAttendance = false

    @Published var homeworkSelectedClassID: Int = 0
    @Published var homeworkSelectedSubjectID: Int = 0
    @Published var homeworkSubjects: [TeacherSubjectDTO] = []
    @Published var homeworkDateFilter: HomeworkDateFilter = .currentWeek
    @Published var homeworkSearchText = ""
    @Published var isLoadingHomework = false

    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var attendanceWarningMessage: String?

    enum HomeworkDateFilter: String, CaseIterable, Identifiable {
        case today = "Сегодня"
        case tomorrow = "Завтра"
        case currentWeek = "Неделя"
        case nextWeek = "Следующая"
        case all = "Все"

        var id: String {
            rawValue
        }
    }

    enum GradesDateFilter: String, CaseIterable, Identifiable {
        case today = "Сегодня"
        case currentWeek = "Неделя"
        case currentMonth = "Месяц"
        case all = "Все"

        var id: String {
            rawValue
        }
    }

    enum FinalGradeScope: String, CaseIterable, Identifiable {
        case term = "term"
        case year = "year"

        var id: String {
            rawValue
        }

        var title: String {
            switch self {
            case .term:
                return "За период"
            case .year:
                return "Годовая"
            }
        }
    }

    var filteredStudents: [TeacherStudentDTO] {
        let sorted = students.sorted { $0.full_name < $1.full_name }

        guard selectedClassID != 0 else {
            return sorted
        }

        return sorted.filter { student in
            if let classID = student.class_id, classID != 0 {
                return classID == selectedClassID
            }

            return true
        }
    }

    var filteredTeacherGrades: [TeacherGradeDTO] {
        var result = grades

        if gradesSelectedClassID != 0 {
            result = result.filter { $0.class_id == gradesSelectedClassID }
        } else if selectedClassID != 0 {
            result = result.filter { $0.class_id == selectedClassID }
        }

        if gradesSelectedSubjectID != 0 {
            result = result.filter { $0.subject_id == gradesSelectedSubjectID }
        } else if selectedSubjectID != 0 {
            result = result.filter { $0.subject_id == selectedSubjectID }
        }

        if gradesSelectedStudentID != 0 {
            result = result.filter { $0.student_id == gradesSelectedStudentID }
        }

        if gradesSelectedType != "all" {
            result = result.filter { ($0.grade_type ?? "") == gradesSelectedType }
        }

        result = result.filter { grade in
            isGradeDate(grade.grade_date, inside: gradesDateFilter)
        }

        let query = gradesSearchText.trimmingCharacters(in: .whitespacesAndNewlines)

        if !query.isEmpty {
            result = result.filter { grade in
                grade.student_name.localizedCaseInsensitiveContains(query)
                || grade.class_name.localizedCaseInsensitiveContains(query)
                || grade.subject_name.localizedCaseInsensitiveContains(query)
                || grade.grade_value.localizedCaseInsensitiveContains(query)
                || (grade.grade_type ?? "").localizedCaseInsensitiveContains(query)
                || grade.grade_date.localizedCaseInsensitiveContains(query)
                || (grade.comment ?? "").localizedCaseInsensitiveContains(query)
            }
        }

        return result.sorted {
            if $0.grade_date == $1.grade_date {
                return $0.student_name < $1.student_name
            }

            return $0.grade_date > $1.grade_date
        }
    }

    var teacherGradesGroupedByStudent: [TeacherGradesStudentGroup] {
        let grouped = Dictionary(grouping: filteredTeacherGrades) { $0.student_id }

        return grouped.map { studentID, grades in
            TeacherGradesStudentGroup(
                studentID: studentID,
                studentName: grades.first?.student_name ?? "Ученик \(studentID)",
                className: grades.first?.class_name ?? "Класс",
                grades: grades.sorted {
                    if $0.grade_date == $1.grade_date {
                        return $0.id > $1.id
                    }

                    return $0.grade_date > $1.grade_date
                }
            )
        }
        .sorted { $0.studentName < $1.studentName }
    }

    var teacherGradesAverageText: String {
        let values = filteredTeacherGrades.compactMap {
            Double($0.grade_value.replacingOccurrences(of: ",", with: "."))
        }

        guard !values.isEmpty else {
            return "—"
        }

        let average = values.reduce(0, +) / Double(values.count)
        return String(format: "%.2f", average)
    }

    var teacherGradesFiveCount: Int {
        filteredTeacherGrades.filter { $0.grade_value == "5" }.count
    }

    var teacherGradesFourCount: Int {
        filteredTeacherGrades.filter { $0.grade_value == "4" }.count
    }

    var teacherGradesThreeCount: Int {
        filteredTeacherGrades.filter { $0.grade_value == "3" }.count
    }

    var teacherGradesBadCount: Int {
        filteredTeacherGrades.filter { value in
            guard let numeric = Double(value.grade_value.replacingOccurrences(of: ",", with: ".")) else {
                return false
            }

            return numeric < 3
        }.count
    }

    var availableGradeTypesForFilter: [TeacherGradeTypeDTO] {
        gradeTypes.sorted {
            ($0.sort_order ?? Int.max, $0.name) < ($1.sort_order ?? Int.max, $1.name)
        }
    }

    var selectedClassName: String {
        if selectedClassID == 0 {
            return "Все классы"
        }

        return classes.first { $0.id == selectedClassID }?.name ?? "Класс"
    }

    var selectedFinalGradesTermName: String {
        if finalGradesSelectedTermID == 0 {
            return "Период не выбран"
        }

        return terms.first { $0.id == finalGradesSelectedTermID }?.name ?? "Период \(finalGradesSelectedTermID)"
    }

    var selectedFinalGradesTerm: TeacherTermDTO? {
        guard finalGradesSelectedTermID != 0 else {
            return nil
        }

        return terms.first { $0.id == finalGradesSelectedTermID }
    }

    var selectedFinalGradesPeriodTitle: String {
        guard let selectedFinalGradesTerm else {
            return "Период не выбран"
        }

        return "\(selectedFinalGradesTerm.name) · \(selectedFinalGradesTerm.dateRangeTitle)"
    }

    var selectedSubjectName: String {
        if selectedSubjectID == 0 {
            return "Все предметы"
        }

        return subjects.first { $0.id == selectedSubjectID }?.name ?? "Предмет"
    }

    var selectedAttendanceClassName: String {
        if attendanceSelectedClassID == 0 {
            return "Класс не выбран"
        }

        return classes.first { $0.id == attendanceSelectedClassID }?.name ?? "Класс \(attendanceSelectedClassID)"
    }

    var selectedAttendanceLesson: TeacherScheduleLessonDTO? {
        attendanceLessons.first { $0.id == attendanceSelectedLessonID }
    }

    var selectedAttendanceLessonTitle: String {
        selectedAttendanceLesson?.displayTitle ?? "Урок не выбран"
    }

    var attendanceDateString: String {
        Self.dateFormatter.string(from: attendanceSelectedDate)
    }

    var attendanceWeekday: Int {
        Self.backendWeekday(from: attendanceSelectedDate)
    }

    var attendanceDateTitle: String {
        Self.fullDateFormatter.string(from: attendanceSelectedDate)
    }

    var attendanceWeekdayTitle: String {
        Self.weekdayFormatter.string(from: attendanceSelectedDate)
    }

    var attendanceByStudentID: [Int: TeacherAttendanceDTO] {
        Dictionary(uniqueKeysWithValues: attendance.map { ($0.student_id, $0) })
    }

    var selectedHomeworkClassName: String {
        if homeworkSelectedClassID == 0 {
            return "Класс не выбран"
        }

        return classes.first { $0.id == homeworkSelectedClassID }?.name ?? "Класс \(homeworkSelectedClassID)"
    }

    var selectedHomeworkSubjectName: String {
        if homeworkSelectedSubjectID == 0 {
            return "Все мои предметы"
        }

        return homeworkSubjects.first { $0.id == homeworkSelectedSubjectID }?.name
            ?? subjects.first { $0.id == homeworkSelectedSubjectID }?.name
            ?? "Предмет \(homeworkSelectedSubjectID)"
    }

    var filteredHomework: [TeacherHomeworkDTO] {
        let allowedSubjectIDs = Set(homeworkSubjects.map { $0.id })

        var result = homework.filter { item in
            guard !allowedSubjectIDs.isEmpty else {
                return false
            }

            return allowedSubjectIDs.contains(item.subject_id)
        }

        result = result.filter { item in
            isHomeworkDate(item.due_date, inside: homeworkDateFilter)
        }

        let query = homeworkSearchText.trimmingCharacters(in: .whitespacesAndNewlines)

        if !query.isEmpty {
            result = result.filter { item in
                item.title.localizedCaseInsensitiveContains(query)
                || item.description.localizedCaseInsensitiveContains(query)
                || item.class_name.localizedCaseInsensitiveContains(query)
                || item.subject_name.localizedCaseInsensitiveContains(query)
                || (item.teacher_name ?? "").localizedCaseInsensitiveContains(query)
                || item.due_date.localizedCaseInsensitiveContains(query)
                || (item.created_at ?? "").localizedCaseInsensitiveContains(query)
            }
        }

        return result.sorted {
            let firstDate = Self.dateFormatter.date(from: $0.due_date) ?? .distantPast
            let secondDate = Self.dateFormatter.date(from: $1.due_date) ?? .distantPast

            if firstDate == secondDate {
                return ($0.created_at ?? "") > ($1.created_at ?? "")
            }

            return firstDate > secondDate
        }
    }

    var homeworkTotalCount: Int {
        homework.count
    }

    var homeworkVisibleCount: Int {
        filteredHomework.count
    }

    var homeworkOverdueCount: Int {
        homework.filter { item in
            guard let dueDate = Self.dateFormatter.date(from: item.due_date) else {
                return false
            }

            return dueDate < Calendar.current.startOfDay(for: Date())
        }.count
    }

    var homeworkTodayCount: Int {
        homework.filter { item in
            guard let dueDate = Self.dateFormatter.date(from: item.due_date) else {
                return false
            }

            return Calendar.current.isDateInToday(dueDate)
        }.count
    }

    var canManageGrades: Bool {
        access?.resolvedCanManageGrades ?? true
    }

    var canManageHomework: Bool {
        access?.resolvedCanManageHomework ?? true
    }

    var canManageAttendance: Bool {
        access?.resolvedCanManageAttendance ?? true
    }

    var canManageFinalGrades: Bool {
        access?.resolvedCanManageFinalGrades ?? false
    }

    func loadAll(api: SchoolAPI) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        async let classesTask: Void = loadClasses(api: api)
        async let subjectsTask: Void = loadSubjects(api: api)
        async let gradeTypesTask: Void = loadGradeTypes(api: api)
        async let scheduleTask: Void = loadSchedule(api: api)

        _ = await (classesTask, subjectsTask, gradeTypesTask, scheduleTask)

        if selectedClassID == 0 {
            selectedClassID = classes.first?.id ?? 0
        }

        if selectedSubjectID == 0 {
            selectedSubjectID = subjects.first?.id ?? 0
        }

        if gradesSelectedClassID == 0 {
            gradesSelectedClassID = selectedClassID
        }

        if gradesSelectedSubjectID == 0 {
            gradesSelectedSubjectID = selectedSubjectID
        }

        async let accessTask: Void = loadAccess(api: api)
        async let studentsTask: Void = loadStudents(api: api)
        async let gradesTask: Void = loadGrades(api: api)
        async let termsTask: Void = loadTerms(api: api)

        _ = await (accessTask, studentsTask, gradesTask, termsTask)

        if finalGradesSelectedTermID == 0 {
            finalGradesSelectedTermID = terms.first(where: { $0.is_active == true })?.id
                ?? terms.first?.id
                ?? 0
        }
        await loadGradebook(api: api)

        isLoading = false
    }

    func applyJournalFilters(
        api: SchoolAPI,
        classID: Int,
        subjectID: Int,
        date: Date
    ) async {
        let resolvedClassID = classID != 0 ? classID : (classes.first?.id ?? 0)
        let resolvedSubjectID = subjectID != 0 ? subjectID : (subjects.first?.id ?? 0)

        selectedClassID = resolvedClassID
        selectedSubjectID = resolvedSubjectID
        selectedStudentID = 0
        selectedJournalDate = date

        isLoading = true
        errorMessage = nil
        successMessage = nil

        async let accessTask: Void = loadAccess(api: api)
        async let studentsTask: Void = loadStudents(api: api)
        async let gradeTypesTask: Void = loadGradeTypes(api: api)
        async let gradesTask: Void = loadGrades(api: api)

        _ = await (accessTask, studentsTask, gradeTypesTask, gradesTask)

        await loadGradebook(api: api)

        isLoading = false
    }

    func loadSectionData(api: SchoolAPI, sectionRawValue: String) async {
        switch sectionRawValue {
        case "Сегодня":
            await loadSchedule(api: api)

        case "Классы":
            await loadClasses(api: api)
            await loadStudents(api: api)

        case "Оценки":
            await loadGradeTypes(api: api)
            await loadGrades(api: api)

        case "Домашка":
            await loadHomeworkScreen(api: api)

        case "Посещаемость":
            await loadAttendanceScreen(api: api)

        case "Итоговые":
            await loadFinalGradesScreen(api: api)

        case "Периоды":
            await loadTerms(api: api)

        default:
            break
        }
    }

    func loadFinalGradesScreen(api: SchoolAPI) async {
        isLoadingGradebook = true
        errorMessage = nil
        successMessage = nil

        if classes.isEmpty {
            await loadClasses(api: api)
        }

        if subjects.isEmpty {
            await loadSubjects(api: api)
        }

        if selectedClassID == 0 {
            selectedClassID = gradesSelectedClassID != 0
                ? gradesSelectedClassID
                : (classes.first?.id ?? 0)
        }

        if selectedSubjectID == 0 {
            selectedSubjectID = gradesSelectedSubjectID != 0
                ? gradesSelectedSubjectID
                : (subjects.first?.id ?? 0)
        }

        if gradesSelectedClassID == 0 {
            gradesSelectedClassID = selectedClassID
        }

        if gradesSelectedSubjectID == 0 {
            gradesSelectedSubjectID = selectedSubjectID
        }

        await loadTerms(api: api)

        if finalGradesSelectedTermID == 0 {
            finalGradesSelectedTermID = terms.first(where: { $0.is_active == true })?.id
                ?? terms.first?.id
                ?? 0
        }

        await loadGradebook(api: api)

        isLoadingGradebook = false
    }

    func loadAccess(api: SchoolAPI) async {
        do {
            let classID = selectedClassID != 0
                ? selectedClassID
                : (classes.first?.id ?? 0)

            guard classID != 0 else {
                return
            }

            let data = try await sendRequest(
                api: api,
                path: "/api/v1/teacher/access",
                method: "GET",
                queryItems: [
                    URLQueryItem(name: "class_id", value: "\(classID)")
                ]
            )

            access = try JSONDecoder.teacherCabinetDecoder.decode(
                TeacherAccessResponseDTO.self,
                from: data
            )
        } catch {
            // Не блокируем кабинет, если endpoint прав недоступен.
        }
    }

    func loadClasses(api: SchoolAPI) async {
        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/teacher/classes",
                method: "GET"
            )

            let decodedClasses = try decodeList(
                data,
                responseType: TeacherClassesResponseDTO.self,
                itemType: TeacherClassDTO.self
            )

            if decodedClasses.isEmpty {
                await loadAdminClassesFallback(api: api)
            } else {
                classes = decodedClasses
            }
        } catch {
            await loadAdminClassesFallback(api: api)

            if classes.isEmpty {
                errorMessage = "Не удалось загрузить классы: \(error.localizedDescription)"
            }
        }
    }

    private func loadAdminClassesFallback(api: SchoolAPI) async {
        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/admin/classes",
                method: "GET"
            )

            classes = try decodeList(
                data,
                responseType: TeacherClassesResponseDTO.self,
                itemType: TeacherClassDTO.self
            )
        } catch {
            // Если нет прав администратора — оставляем текущий список.
        }
    }

    func loadSubjects(
        api: SchoolAPI,
        classID: Int? = nil
    ) async {
        do {
            var queryItems: [URLQueryItem] = []

            if let classID, classID != 0 {
                queryItems.append(URLQueryItem(name: "class_id", value: "\(classID)"))
            }

            let data = try await sendRequest(
                api: api,
                path: "/api/v1/teacher/subjects",
                method: "GET",
                queryItems: queryItems
            )

            let decodedSubjects = try decodeList(
                data,
                responseType: TeacherSubjectsResponseDTO.self,
                itemType: TeacherSubjectDTO.self
            )

            if let classID, classID != 0 {
                homeworkSubjects = decodedSubjects
            } else if decodedSubjects.isEmpty {
                await loadAdminSubjectsFallback(api: api)
            } else {
                subjects = decodedSubjects
            }
        } catch {
            if let classID, classID != 0 {
                homeworkSubjects = []
            } else {
                await loadAdminSubjectsFallback(api: api)

                if subjects.isEmpty {
                    errorMessage = "Не удалось загрузить предметы: \(error.localizedDescription)"
                }
            }
        }
    }

    func loadHomeworkSubjects(api: SchoolAPI) async {
        do {
            let classID = homeworkSelectedClassID != 0
                ? homeworkSelectedClassID
                : (selectedClassID != 0 ? selectedClassID : (classes.first?.id ?? 0))

            var queryItems: [URLQueryItem] = []

            if classID != 0 {
                queryItems.append(URLQueryItem(name: "class_id", value: "\(classID)"))
            }

            let data = try await sendRequest(
                api: api,
                path: "/api/v1/teacher/subjects",
                method: "GET",
                queryItems: queryItems
            )

            let decodedSubjects = try decodeList(
                data,
                responseType: TeacherSubjectsResponseDTO.self,
                itemType: TeacherSubjectDTO.self
            )
            .filter { $0.id != 0 }
            .sorted { $0.name < $1.name }

            if decodedSubjects.isEmpty, !queryItems.isEmpty {
                await loadSubjects(api: api)

                homeworkSubjects = subjects
                    .filter { $0.id != 0 }
                    .sorted { $0.name < $1.name }
            } else {
                subjects = mergeSubjects(subjects, decodedSubjects)
                homeworkSubjects = decodedSubjects
            }
        } catch {
            homeworkSubjects = subjects.filter { $0.id != 0 }

            if homeworkSubjects.isEmpty {
                errorMessage = "Не удалось загрузить предметы учителя: \(readableTeacherError(error))"
            }
        }
    }

    private func mergeSubjects(
        _ current: [TeacherSubjectDTO],
        _ loaded: [TeacherSubjectDTO]
    ) -> [TeacherSubjectDTO] {
        var result = current
        var seenIDs = Set(current.map(\.id))

        for subject in loaded where !seenIDs.contains(subject.id) {
            result.append(subject)
            seenIDs.insert(subject.id)
        }

        return result
            .filter { $0.id != 0 }
            .sorted { $0.name < $1.name }
    }

    func loadGradeTypes(api: SchoolAPI) async {
        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/teacher/grade-types",
                method: "GET"
            )

            let loaded = try decodeList(
                data,
                responseType: TeacherGradeTypesResponseDTO.self,
                itemType: TeacherGradeTypeDTO.self
            )
            .filter { !$0.code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted {
                ($0.sort_order ?? Int.max, $0.name) < ($1.sort_order ?? Int.max, $1.name)
            }

            if loaded.isEmpty {
                gradeTypes = [TeacherGradeTypeDTO.fallback]
            } else {
                gradeTypes = loaded
            }
        } catch {
            print("TEACHER GRADE TYPES LOAD ERROR:", error.localizedDescription)
            gradeTypes = [TeacherGradeTypeDTO.fallback]
        }
    }

    private func loadAdminSubjectsFallback(api: SchoolAPI) async {
        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/admin/subjects",
                method: "GET"
            )

            subjects = try decodeList(
                data,
                responseType: TeacherSubjectsResponseDTO.self,
                itemType: TeacherSubjectDTO.self
            )
        } catch {
            // Если нет прав администратора — оставляем текущий список.
        }
    }

    func loadStudents(api: SchoolAPI) async {
        do {
            var queryItems: [URLQueryItem] = []

            if selectedClassID != 0 {
                queryItems.append(URLQueryItem(name: "class_id", value: "\(selectedClassID)"))
            }

            let data = try await sendRequest(
                api: api,
                path: "/api/v1/teacher/students",
                method: "GET",
                queryItems: queryItems
            )

            let decodedStudents = try decodeList(
                data,
                responseType: TeacherStudentsResponseDTO.self,
                itemType: TeacherStudentDTO.self
            )

            if decodedStudents.isEmpty {
                await loadAdminStudentsFallback(api: api)
            } else {
                students = decodedStudents
            }
        } catch {
            await loadAdminStudentsFallback(api: api)

            if students.isEmpty {
                errorMessage = "Не удалось загрузить учеников: \(error.localizedDescription)"
            }
        }
    }

    private func loadAdminStudentsFallback(api: SchoolAPI) async {
        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/admin/students",
                method: "GET"
            )

            let allStudents = try decodeList(
                data,
                responseType: TeacherStudentsResponseDTO.self,
                itemType: TeacherStudentDTO.self
            )

            if selectedClassID != 0 {
                students = allStudents.filter { student in
                    if let classID = student.class_id {
                        return classID == selectedClassID
                    }

                    return false
                }
            } else {
                students = allStudents
            }
        } catch {
            // Если нет прав администратора — оставляем текущий список.
        }
    }

    func loadGrades(api: SchoolAPI) async {
        do {
            var queryItems: [URLQueryItem] = []

            if selectedClassID != 0 {
                queryItems.append(URLQueryItem(name: "class_id", value: "\(selectedClassID)"))
            }

            if selectedSubjectID != 0 {
                queryItems.append(URLQueryItem(name: "subject_id", value: "\(selectedSubjectID)"))
            }

            if selectedStudentID != 0 {
                queryItems.append(URLQueryItem(name: "student_id", value: "\(selectedStudentID)"))
            }

            let data = try await sendRequest(
                api: api,
                path: "/api/v1/teacher/grades",
                method: "GET",
                queryItems: queryItems
            )

            grades = try decodeList(
                data,
                responseType: TeacherGradesResponseDTO.self,
                itemType: TeacherGradeDTO.self
            )
        } catch {
            errorMessage = "Не удалось загрузить оценки: \(error.localizedDescription)"
        }
    }

    func createGrade(
        api: SchoolAPI,
        studentID: Int,
        classID: Int,
        subjectID: Int,
        gradeValue: String,
        gradeType: String,
        gradeDate: String
    ) async {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        let resolvedGradeType = gradeType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? TeacherGradeTypeDTO.fallback.code
            : gradeType.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            _ = try await sendRequest(
                api: api,
                path: "/api/v1/teacher/grades",
                method: "POST",
                body: [
                    "student_id": studentID,
                    "class_id": classID,
                    "subject_id": subjectID,
                    "grade_value": gradeValue,
                    "grade_type": resolvedGradeType,
                    "grade_date": gradeDate
                ]
            )

            selectedClassID = classID
            selectedSubjectID = subjectID

            successMessage = "Оценка сохранена"
            await loadGrades(api: api)
            await loadGradebook(api: api)

            isSaving = false
        } catch {
            errorMessage = "Не удалось поставить оценку: \(error.localizedDescription)"
            isSaving = false
        }
    }

    func replaceGrade(
        api: SchoolAPI,
        originalGradeID: Int,
        studentID: Int,
        classID: Int,
        subjectID: Int,
        gradeValue: String,
        gradeType: String,
        gradeDate: String
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        let resolvedGradeType = gradeType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? TeacherGradeTypeDTO.fallback.code
            : gradeType.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            _ = try await sendRequest(
                api: api,
                path: "/api/v1/teacher/grades",
                method: "POST",
                body: [
                    "student_id": studentID,
                    "class_id": classID,
                    "subject_id": subjectID,
                    "grade_value": gradeValue,
                    "grade_type": resolvedGradeType,
                    "grade_date": gradeDate
                ]
            )

            _ = try await sendRequest(
                api: api,
                path: "/api/v1/teacher/grades/\(originalGradeID)",
                method: "DELETE"
            )

            selectedClassID = classID
            selectedSubjectID = subjectID
            successMessage = "Оценка обновлена"

            await loadGrades(api: api)
            await loadGradebook(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось обновить оценку: \(readableTeacherError(error))"
            await loadGrades(api: api)

            isSaving = false
            return false
        }
    }

    func deleteGrade(api: SchoolAPI, gradeID: Int) async {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await sendRequest(
                api: api,
                path: "/api/v1/teacher/grades/\(gradeID)",
                method: "DELETE"
            )

            successMessage = "Оценка удалена"
            await loadGrades(api: api)
            await loadGradebook(api: api)

            isSaving = false
        } catch {
            errorMessage = "Не удалось удалить оценку: \(error.localizedDescription)"
            isSaving = false
        }
    }

    func loadHomeworkScreen(api: SchoolAPI) async {
        isLoadingHomework = true
        errorMessage = nil
        successMessage = nil

        if classes.isEmpty {
            await loadClasses(api: api)
        }

        if homeworkSelectedClassID == 0 {
            homeworkSelectedClassID = selectedClassID != 0
                ? selectedClassID
                : (classes.first?.id ?? 0)
        }

        guard homeworkSelectedClassID != 0 else {
            homeworkSubjects = []
            homework = []
            isLoadingHomework = false
            return
        }

        selectedClassID = homeworkSelectedClassID

        await loadHomeworkSubjects(api: api)

        if homeworkSelectedSubjectID != 0,
           !homeworkSubjects.contains(where: { $0.id == homeworkSelectedSubjectID }) {
            homeworkSelectedSubjectID = 0
        }

        await loadAccessForHomework(api: api)
        await loadHomework(api: api)

        isLoadingHomework = false
    }

    func selectHomeworkClass(
        api: SchoolAPI,
        classID: Int
    ) async {
        homeworkSelectedClassID = classID
        homeworkSelectedSubjectID = 0
        homework = []

        guard classID != 0 else {
            homeworkSubjects = []
            return
        }

        isLoadingHomework = true
        errorMessage = nil
        successMessage = nil

        selectedClassID = classID

        await loadHomeworkSubjects(api: api)
        await loadAccessForHomework(api: api)
        await loadHomework(api: api)

        isLoadingHomework = false
    }

    func selectHomeworkSubject(
        api: SchoolAPI,
        subjectID: Int
    ) async {
        homeworkSelectedSubjectID = subjectID

        isLoadingHomework = true
        errorMessage = nil
        successMessage = nil

        await loadAccessForHomework(api: api)
        await loadHomework(api: api)

        isLoadingHomework = false
    }

    func selectHomeworkDateFilter(_ filter: HomeworkDateFilter) {
        homeworkDateFilter = filter
    }

    func refreshHomeworkScreen(api: SchoolAPI) async {
        await loadHomeworkScreen(api: api)
    }

    func loadAccessForHomework(api: SchoolAPI) async {
        do {
            guard homeworkSelectedClassID != 0 else {
                return
            }

            var queryItems: [URLQueryItem] = [
                URLQueryItem(name: "class_id", value: "\(homeworkSelectedClassID)")
            ]

            if homeworkSelectedSubjectID != 0 {
                queryItems.append(URLQueryItem(name: "subject_id", value: "\(homeworkSelectedSubjectID)"))
            }

            let data = try await sendRequest(
                api: api,
                path: "/api/v1/teacher/access",
                method: "GET",
                queryItems: queryItems
            )

            access = try JSONDecoder.teacherCabinetDecoder.decode(
                TeacherAccessResponseDTO.self,
                from: data
            )
        } catch {
            // Не блокируем домашку, если проверка доступа недоступна.
        }
    }

    func loadHomework(api: SchoolAPI) async {
        do {
            let classID = homeworkSelectedClassID != 0
                ? homeworkSelectedClassID
                : (selectedClassID != 0 ? selectedClassID : (classes.first?.id ?? 0))

            guard classID != 0 else {
                homework = []
                return
            }

            if homeworkSubjects.isEmpty {
                await loadHomeworkSubjects(api: api)
            }

            let allowedSubjectIDs = Set(homeworkSubjects.map { $0.id }.filter { $0 != 0 })

            guard !allowedSubjectIDs.isEmpty else {
                homework = []
                return
            }

            if homeworkSelectedSubjectID != 0 {
                guard allowedSubjectIDs.contains(homeworkSelectedSubjectID) else {
                    homework = []
                    return
                }

                let items = try await loadHomeworkItems(
                    api: api,
                    classID: classID,
                    subjectID: homeworkSelectedSubjectID
                )

                homework = items.filter { allowedSubjectIDs.contains($0.subject_id) }
                return
            }

            var collected: [TeacherHomeworkDTO] = []

            for subjectID in allowedSubjectIDs.sorted() {
                let items = try await loadHomeworkItems(
                    api: api,
                    classID: classID,
                    subjectID: subjectID
                )

                collected.append(contentsOf: items)
            }

            var seen = Set<Int>()

            homework = collected
                .filter { allowedSubjectIDs.contains($0.subject_id) }
                .filter { item in
                    if seen.contains(item.id) {
                        return false
                    }

                    seen.insert(item.id)
                    return true
                }
        } catch {
            errorMessage = "Не удалось загрузить домашние задания: \(readableTeacherError(error))"
        }
    }

    private func loadHomeworkItems(
        api: SchoolAPI,
        classID: Int,
        subjectID: Int
    ) async throws -> [TeacherHomeworkDTO] {
        let data = try await sendRequest(
            api: api,
            path: "/api/v1/teacher/homework",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "class_id", value: "\(classID)"),
                URLQueryItem(name: "subject_id", value: "\(subjectID)")
            ]
        )

        return try decodeList(
            data,
            responseType: TeacherHomeworkResponseDTO.self,
            itemType: TeacherHomeworkDTO.self
        )
    }

    func createHomework(
        api: SchoolAPI,
        classID: Int,
        subjectID: Int,
        title: String,
        description: String,
        dueDate: String
    ) async {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)

        guard classID != 0 else {
            errorMessage = "Выберите класс"
            isSaving = false
            return
        }

        guard subjectID != 0 else {
            errorMessage = "Выберите предмет"
            isSaving = false
            return
        }

        guard cleanTitle.count >= 2 else {
            errorMessage = "Заголовок должен быть не короче 2 символов"
            isSaving = false
            return
        }

        do {
            _ = try await sendRequest(
                api: api,
                path: "/api/v1/teacher/homework",
                method: "POST",
                body: [
                    "class_id": classID,
                    "subject_id": subjectID,
                    "title": cleanTitle,
                    "description": cleanDescription,
                    "due_date": dueDate
                ]
            )

            selectedClassID = classID
            selectedSubjectID = subjectID
            homeworkSelectedClassID = classID
            homeworkSelectedSubjectID = subjectID

            successMessage = "Домашнее задание создано"
            await loadHomeworkSubjects(api: api)
            await loadAccessForHomework(api: api)
            await loadHomework(api: api)

            isSaving = false
        } catch {
            errorMessage = "Не удалось добавить домашнее задание: \(readableTeacherError(error))"
            isSaving = false
        }
    }

    func deleteHomework(api: SchoolAPI, homeworkID: Int) async {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        do {
            _ = try await sendRequest(
                api: api,
                path: "/api/v1/teacher/homework/\(homeworkID)",
                method: "DELETE"
            )

            homework.removeAll { $0.id == homeworkID }
            successMessage = "Домашнее задание удалено"
            await loadHomework(api: api)

            isSaving = false
        } catch {
            errorMessage = "Не удалось удалить домашнее задание: \(readableTeacherError(error))"
            isSaving = false
        }
    }

    // MARK: - Attendance Methods

    func loadAttendanceScreen(api: SchoolAPI) async {
        isLoadingAttendance = true
        errorMessage = nil
        successMessage = nil
        attendanceWarningMessage = nil

        if classes.isEmpty {
            await loadClasses(api: api)
        }

        if attendanceSelectedClassID == 0 {
            attendanceSelectedClassID = selectedClassID != 0
                ? selectedClassID
                : (classes.first?.id ?? 0)
        }

        guard attendanceSelectedClassID != 0 else {
            students = []
            attendanceLessons = []
            attendance = []
            attendanceWarningMessage = "Выберите класс для отметки посещаемости."
            isLoadingAttendance = false
            return
        }

        selectedClassID = attendanceSelectedClassID
        selectedJournalDate = attendanceSelectedDate

        await loadStudents(api: api)
        await loadAttendanceLessons(api: api)

        if attendanceSelectedLessonID == 0 {
            attendanceSelectedLessonID = attendanceLessons.first?.id ?? 0
        }

        await loadAttendance(api: api)

        isLoadingAttendance = false
    }

    func selectAttendanceClass(
        api: SchoolAPI,
        classID: Int
    ) async {
        attendanceSelectedClassID = classID
        attendanceSelectedLessonID = 0
        attendanceLessons = []
        attendance = []

        guard classID != 0 else {
            students = []
            attendanceWarningMessage = "Выберите класс для отметки посещаемости."
            return
        }

        isLoadingAttendance = true
        errorMessage = nil
        successMessage = nil
        attendanceWarningMessage = nil

        selectedClassID = classID
        await loadStudents(api: api)
        await loadAttendanceLessons(api: api)

        attendanceSelectedLessonID = attendanceLessons.first?.id ?? 0
        await loadAttendance(api: api)

        isLoadingAttendance = false
    }

    func selectAttendanceLesson(
        api: SchoolAPI,
        lessonID: Int
    ) async {
        attendanceSelectedLessonID = lessonID

        isLoadingAttendance = true
        errorMessage = nil
        successMessage = nil
        attendanceWarningMessage = nil

        await loadAttendance(api: api)

        isLoadingAttendance = false
    }

    func selectAttendanceDate(
        api: SchoolAPI,
        date: Date
    ) async {
        attendanceSelectedDate = date
        selectedJournalDate = date
        attendanceSelectedLessonID = 0
        attendanceLessons = []
        attendance = []

        isLoadingAttendance = true
        errorMessage = nil
        successMessage = nil
        attendanceWarningMessage = nil

        await loadAttendanceLessons(api: api)

        attendanceSelectedLessonID = attendanceLessons.first?.id ?? 0

        await loadAttendance(api: api)

        isLoadingAttendance = false
    }

    func loadAttendanceLessons(api: SchoolAPI) async {
        do {
            guard attendanceSelectedClassID != 0 else {
                attendanceLessons = []
                attendanceWarningMessage = "Выберите класс."
                return
            }

            let selectedWeekday = Self.backendWeekday(from: attendanceSelectedDate)

            let data = try await sendRequest(
                api: api,
                path: "/api/v1/teacher/schedule",
                method: "GET",
                queryItems: [
                    URLQueryItem(name: "class_id", value: "\(attendanceSelectedClassID)")
                ]
            )

            let decoded = try decodeList(
                data,
                responseType: TeacherScheduleResponseDTO.self,
                itemType: TeacherScheduleLessonDTO.self
            )

            attendanceLessons = decoded
                .filter { lesson in
                    let belongsToClass: Bool

                    if let classID = lesson.class_id {
                        belongsToClass = classID == attendanceSelectedClassID
                    } else {
                        belongsToClass = true
                    }

                    return belongsToClass && lesson.weekday == selectedWeekday
                }
                .sorted {
                    if ($0.lesson_number ?? 0) == ($1.lesson_number ?? 0) {
                        return ($0.starts_at ?? "") < ($1.starts_at ?? "")
                    }

                    return ($0.lesson_number ?? 0) < ($1.lesson_number ?? 0)
                }

            if attendanceLessons.isEmpty {
                attendanceSelectedLessonID = 0
                attendance = []
                attendanceWarningMessage = "На эту дату уроков нет."
            } else if !attendanceLessons.contains(where: { $0.id == attendanceSelectedLessonID }) {
                attendanceSelectedLessonID = attendanceLessons.first?.id ?? 0
                attendanceWarningMessage = nil
            }
        } catch {
            attendanceLessons = []
            attendanceSelectedLessonID = 0
            attendance = []
            errorMessage = "Не удалось загрузить уроки: \(readableTeacherError(error))"
        }
    }

    func loadAttendance(api: SchoolAPI) async {
        attendanceWarningMessage = nil

        do {
            let classID = attendanceSelectedClassID != 0
                ? attendanceSelectedClassID
                : (selectedClassID != 0 ? selectedClassID : (classes.first?.id ?? 0))

            guard classID != 0 else {
                attendance = []
                attendanceWarningMessage = "Выберите класс."
                return
            }

            guard !attendanceLessons.isEmpty else {
                attendance = []
                attendanceWarningMessage = "На эту дату уроков нет."
                return
            }

            guard attendanceSelectedLessonID != 0 else {
                attendance = []
                attendanceWarningMessage = "Выберите урок для отметки посещаемости."
                return
            }

            guard attendanceLessons.contains(where: { $0.id == attendanceSelectedLessonID }) else {
                attendance = []
                attendanceSelectedLessonID = attendanceLessons.first?.id ?? 0
                attendanceWarningMessage = "Выбранный урок не относится к этой дате. Выберите урок из списка."
                return
            }

            let data = try await sendRequest(
                api: api,
                path: "/api/v1/teacher/attendance",
                method: "GET",
                queryItems: [
                    URLQueryItem(name: "class_id", value: "\(classID)"),
                    URLQueryItem(name: "lesson_id", value: "\(attendanceSelectedLessonID)"),
                    URLQueryItem(name: "attendance_date", value: attendanceDateString)
                ]
            )

            attendance = try decodeList(
                data,
                responseType: TeacherAttendanceResponseDTO.self,
                itemType: TeacherAttendanceDTO.self
            )
        } catch {
            attendance = []
            attendanceWarningMessage = "Посещаемость ещё не заполнена. Можно отметить учеников и сохранить."
            print("TEACHER ATTENDANCE LOAD ERROR:", readableTeacherError(error))
        }
    }

    func createAttendance(
        api: SchoolAPI,
        studentID: Int,
        date: String,
        status: String,
        comment: String?
    ) async {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        let classID = selectedClassID != 0
            ? selectedClassID
            : (students.first { $0.id == studentID }?.class_id ?? classes.first?.id ?? 0)

        var body: [String: Any] = [
            "student_id": studentID,
            "class_id": classID,
            "attendance_date": date,
            "status": status
        ]

        if let comment, !comment.isEmpty {
            body["comment"] = comment
        }

        do {
            _ = try await sendRequest(
                api: api,
                path: "/api/v1/teacher/attendance",
                method: "POST",
                body: body
            )

            selectedClassID = classID
            selectedJournalDate = Self.dateFormatter.date(from: date) ?? selectedJournalDate

            successMessage = "Посещаемость сохранена"
            await loadAttendance(api: api)

            isSaving = false
        } catch {
            errorMessage = "Не удалось сохранить посещаемость: \(error.localizedDescription)"
            isSaving = false
        }
    }

    func saveLessonAttendance(
        api: SchoolAPI,
        classID: Int,
        lessonID: Int,
        attendanceDate: String,
        items: [TeacherLessonAttendanceItemDraft]
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil
        attendanceWarningMessage = nil

        guard classID != 0 else {
            errorMessage = "Выберите класс"
            isSaving = false
            return false
        }

        guard !attendanceLessons.isEmpty else {
            errorMessage = "На выбранную дату уроков нет"
            isSaving = false
            return false
        }

        guard lessonID != 0 else {
            errorMessage = "Выберите урок"
            isSaving = false
            return false
        }

        guard attendanceLessons.contains(where: { $0.id == lessonID }) else {
            errorMessage = "Выбранный урок не относится к выбранной дате"
            isSaving = false
            return false
        }

        guard !items.isEmpty else {
            errorMessage = "Нет учеников для сохранения посещаемости"
            isSaving = false
            return false
        }

        do {
            let body: [String: Any] = [
                "lesson_id": lessonID,
                "class_id": classID,
                "attendance_date": attendanceDate,
                "items": items.map { item in
                    [
                        "student_id": item.studentID,
                        "status": item.status,
                        "comment": item.comment as Any
                    ] as [String: Any]
                }
            ]

            _ = try await sendRequest(
                api: api,
                path: "/api/v1/teacher/attendance",
                method: "POST",
                body: body
            )

            attendanceSelectedClassID = classID
            attendanceSelectedLessonID = lessonID
            attendanceSelectedDate = Self.dateFormatter.date(from: attendanceDate) ?? attendanceSelectedDate
            selectedClassID = classID
            selectedJournalDate = attendanceSelectedDate

            successMessage = "Посещаемость сохранена"
            await loadAttendance(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось сохранить посещаемость: \(readableTeacherError(error))"
            isSaving = false
            return false
        }
    }

    func saveAttendanceExceptions(
        api: SchoolAPI,
        date: String,
        exceptions: [TeacherAttendanceExceptionDraft]
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        let classID = selectedClassID != 0
            ? selectedClassID
            : (classes.first?.id ?? 0)

        guard classID != 0 else {
            errorMessage = "Выберите класс"
            isSaving = false
            return false
        }

        do {
            for item in exceptions {
                var body: [String: Any] = [
                    "student_id": item.studentID,
                    "class_id": classID,
                    "attendance_date": date,
                    "status": item.status
                ]

                if let comment = item.comment,
                   !comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    body["comment"] = comment.trimmingCharacters(in: .whitespacesAndNewlines)
                }

                _ = try await sendRequest(
                    api: api,
                    path: "/api/v1/teacher/attendance",
                    method: "POST",
                    body: body
                )
            }

            selectedJournalDate = Self.dateFormatter.date(from: date) ?? selectedJournalDate
            successMessage = exceptions.isEmpty
                ? "Все ученики отмечены присутствующими по умолчанию"
                : "Посещаемость сохранена: \(exceptions.count)"

            await loadAttendance(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось сохранить посещаемость: \(error.localizedDescription)"
            isSaving = false
            return false
        }
    }

    func loadTerms(api: SchoolAPI) async {
        do {
            var queryItems: [URLQueryItem] = []

            let cleanAcademicYear = finalGradesAcademicYear.trimmingCharacters(in: .whitespacesAndNewlines)

            if !cleanAcademicYear.isEmpty {
                queryItems.append(URLQueryItem(name: "academic_year", value: cleanAcademicYear))
            }

            let data = try await sendRequest(
                api: api,
                path: "/api/v1/teacher/terms",
                method: "GET",
                queryItems: queryItems
            )

            terms = try decodeList(
                data,
                responseType: TeacherTermsResponseDTO.self,
                itemType: TeacherTermDTO.self
            )
            .sorted {
                if ($0.academic_year ?? "") == ($1.academic_year ?? "") {
                    return ($0.term_number ?? 0, $0.starts_at ?? "") < ($1.term_number ?? 0, $1.starts_at ?? "")
                }

                return ($0.academic_year ?? "") > ($1.academic_year ?? "")
            }

            if finalGradesSelectedTermID == 0 {
                finalGradesSelectedTermID = terms.first(where: { $0.is_active == true })?.id
                    ?? terms.first?.id
                    ?? 0
            }
        } catch {
            errorMessage = "Не удалось загрузить периоды: \(error.localizedDescription)"
        }
    }

    func loadGradebook(api: SchoolAPI) async {
        isLoadingGradebook = true
        errorMessage = nil

        do {
            let classID = selectedClassID != 0
                ? selectedClassID
                : (classes.first?.id ?? 0)

            let subjectID = selectedSubjectID != 0
                ? selectedSubjectID
                : (subjects.first?.id ?? 0)

            guard classID != 0, subjectID != 0 else {
                gradebook = []
                isLoadingGradebook = false
                return
            }

            if terms.isEmpty {
                await loadTerms(api: api)
            }

            let selectedTerm = selectedFinalGradesTerm

            let dateFrom = selectedTerm?.starts_at
                ?? Self.dateFormatter.string(
                    from: Calendar.current.date(
                        byAdding: .day,
                        value: -30,
                        to: selectedJournalDate
                    ) ?? selectedJournalDate
                )

            let dateTo = selectedTerm?.ends_at
                ?? Self.dateFormatter.string(from: selectedJournalDate)

            var queryItems: [URLQueryItem] = [
                URLQueryItem(name: "class_id", value: "\(classID)"),
                URLQueryItem(name: "subject_id", value: "\(subjectID)"),
                URLQueryItem(name: "date_from", value: dateFrom),
                URLQueryItem(name: "date_to", value: dateTo)
            ]

            if finalGradesSelectedTermID != 0 {
                queryItems.append(URLQueryItem(name: "term_id", value: "\(finalGradesSelectedTermID)"))
            }

            let data = try await sendRequest(
                api: api,
                path: "/api/v1/teacher/gradebook",
                method: "GET",
                queryItems: queryItems
            )

            gradebook = try decodeList(
                data,
                responseType: TeacherGradebookResponseDTO.self,
                itemType: TeacherGradebookStudentDTO.self
            )

            selectedClassID = classID
            selectedSubjectID = subjectID
        } catch {
            errorMessage = "Не удалось загрузить журнал итоговых: \(readableTeacherError(error))"
            gradebook = []
        }

        isLoadingGradebook = false
    }

    func loadSchedule(api: SchoolAPI) async {
        do {
            let data = try await sendRequest(
                api: api,
                path: "/api/v1/teacher/schedule",
                method: "GET"
            )

            let decoded = try decodeList(
                data,
                responseType: TeacherScheduleResponseDTO.self,
                itemType: TeacherScheduleLessonDTO.self
            )

            schedule = deduplicatedScheduleLessons(decoded)
        } catch {
            errorMessage = "Не удалось загрузить расписание: \(error.localizedDescription)"
        }
    }

    private func deduplicatedScheduleLessons(
        _ lessons: [TeacherScheduleLessonDTO]
    ) -> [TeacherScheduleLessonDTO] {
        var seenKeys = Set<String>()
        var result: [TeacherScheduleLessonDTO] = []

        for lesson in lessons {
            let key = [
                "\(lesson.class_id ?? 0)",
                lesson.class_name ?? "",
                "\(lesson.subject_id ?? 0)",
                lesson.subject_name ?? "",
                "\(lesson.weekday ?? 0)",
                "\(lesson.lesson_number ?? 0)",
                lesson.starts_at ?? "",
                lesson.ends_at ?? "",
                lesson.room ?? ""
            ]
            .joined(separator: "|")

            guard !seenKeys.contains(key) else {
                continue
            }

            seenKeys.insert(key)
            result.append(lesson)
        }

        return result.sorted {
            let firstWeekday = $0.weekday ?? 0
            let secondWeekday = $1.weekday ?? 0

            if firstWeekday != secondWeekday {
                return firstWeekday < secondWeekday
            }

            let firstNumber = $0.lesson_number ?? 0
            let secondNumber = $1.lesson_number ?? 0

            if firstNumber != secondNumber {
                return firstNumber < secondNumber
            }

            return ($0.starts_at ?? "") < ($1.starts_at ?? "")
        }
    }

    func saveFinalGrade(
        api: SchoolAPI,
        studentID: Int,
        classID: Int,
        subjectID: Int,
        termID: Int?,
        gradeScope: FinalGradeScope,
        manualGrade: String?,
        comment: String?
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil

        let cleanManualGrade = manualGrade?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let cleanComment = comment?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            var body: [String: Any] = [
                "student_id": studentID,
                "class_id": classID,
                "subject_id": subjectID,
                "grade_scope": gradeScope.rawValue
            ]

            if gradeScope == .term {
                body["term_id"] = termID as Any
            }

            if let cleanManualGrade, !cleanManualGrade.isEmpty {
                body["manual_grade"] = cleanManualGrade
            } else {
                body["manual_grade"] = NSNull()
            }

            if let cleanComment, !cleanComment.isEmpty {
                body["comment"] = cleanComment
            } else {
                body["comment"] = NSNull()
            }

            _ = try await sendRequest(
                api: api,
                path: "/api/v1/teacher/final-grades",
                method: "POST",
                body: body
            )

            selectedClassID = classID
            selectedSubjectID = subjectID

            if let termID {
                finalGradesSelectedTermID = termID
            }

            finalGradesGradeScope = gradeScope
            successMessage = gradeScope == .term
                ? "Итоговая за период сохранена"
                : "Годовая итоговая сохранена"

            await loadGradebook(api: api)

            isSaving = false
            return true
        } catch {
            errorMessage = "Не удалось сохранить итоговую оценку: \(readableTeacherError(error))"
            isSaving = false
            return false
        }
    }

    func gradesFor(studentID: Int, date: String) -> [TeacherGradeDTO] {
        grades.filter { grade in
            grade.student_id == studentID
            && grade.grade_date == date
            && (selectedSubjectID == 0 || grade.subject_id == selectedSubjectID)
        }
    }

    func journalDates(daysBack: Int = 10) -> [String] {
        let calendar = Calendar.current
        let baseDate = calendar.startOfDay(for: selectedJournalDate)

        return (0..<daysBack).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: baseDate)
        }
        .map { Self.dateFormatter.string(from: $0) }
        .reversed()
    }

    private func readableTeacherError(_ error: Error) -> String {
        if let teacherError = error as? TeacherCabinetError {
            return teacherError.errorDescription ?? error.localizedDescription
        }

        return error.localizedDescription
    }

    private func isHomeworkDate(_ value: String, inside filter: HomeworkDateFilter) -> Bool {
        guard let date = Self.dateFormatter.date(from: value) else {
            return filter == .all
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: date)

        switch filter {
        case .today:
            return calendar.isDate(target, inSameDayAs: today)

        case .tomorrow:
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else {
                return false
            }

            return calendar.isDate(target, inSameDayAs: tomorrow)

        case .currentWeek:
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: today) else {
                return false
            }

            return target >= weekInterval.start && target < weekInterval.end

        case .nextWeek:
            guard let currentWeek = calendar.dateInterval(of: .weekOfYear, for: today),
                  let nextWeekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeek.start),
                  let nextWeek = calendar.dateInterval(of: .weekOfYear, for: nextWeekStart) else {
                return false
            }

            return target >= nextWeek.start && target < nextWeek.end

        case .all:
            return true
        }
    }

    private func isGradeDate(_ value: String, inside filter: GradesDateFilter) -> Bool {
        guard let date = Self.dateFormatter.date(from: value) else {
            return filter == .all
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: date)

        switch filter {
        case .today:
            return calendar.isDate(target, inSameDayAs: today)

        case .currentWeek:
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: today) else {
                return false
            }

            return target >= weekInterval.start && target < weekInterval.end

        case .currentMonth:
            return calendar.isDate(target, equalTo: today, toGranularity: .month)

        case .all:
            return true
        }
    }

    private func decodeList<Response: Decodable, Item: Decodable>(
        _ data: Data,
        responseType: Response.Type,
        itemType: Item.Type
    ) throws -> [Item] {
        let decoder = JSONDecoder.teacherCabinetDecoder

        if let wrapped = try? decoder.decode(TeacherListWrapper<Item>.self, from: data) {
            return wrapped.items
        }

        if let direct = try? decoder.decode([Item].self, from: data) {
            return direct
        }

        if let response = try? decoder.decode(responseType, from: data),
           let items = Mirror(reflecting: response)
            .children
            .first(where: { $0.label == "items" })?
            .value as? [Item] {
            return items
        }

        return []
    }

    private func sendRequest(
        api: SchoolAPI,
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        body: [String: Any]? = nil
    ) async throws -> Data {
        guard let token = api.authToken else {
            throw TeacherCabinetError.noToken
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "sc.it-status.ru"
        components.path = path
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw TeacherCabinetError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.applyMobileClientHeaders()

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            #if DEBUG
            print("TEACHER REQUEST:", method, url.absoluteString)
            print("TEACHER BODY:", body)
            #endif
        } else {
            #if DEBUG
            print("TEACHER REQUEST:", method, url.absoluteString)
            #endif
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TeacherCabinetError.badResponse
        }

        let responseText = String(data: data, encoding: .utf8) ?? ""

        #if DEBUG
        print("TEACHER RESPONSE STATUS:", httpResponse.statusCode)
        print("TEACHER RESPONSE BODY:", responseText)
        #endif

        if httpResponse.statusCode == 401 {
            AuthSessionEvents.notifySessionExpired()
            throw TeacherCabinetError.serverError(statusCode: httpResponse.statusCode, text: responseText)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw TeacherCabinetError.serverError(statusCode: httpResponse.statusCode, text: responseText)
        }

        return data
    }

    private static func backendWeekday(from date: Date) -> Int {
        let appleWeekday = Calendar.current.component(.weekday, from: date)
        return ((appleWeekday + 5) % 7) + 1
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter
    }()

    private static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter
    }()
}

struct TeacherGradesStudentGroup: Identifiable, Hashable {
    let studentID: Int
    let studentName: String
    let className: String
    let grades: [TeacherGradeDTO]

    var id: Int {
        studentID
    }

    var averageText: String {
        let values = grades.compactMap {
            Double($0.grade_value.replacingOccurrences(of: ",", with: "."))
        }

        guard !values.isEmpty else {
            return "—"
        }

        let average = values.reduce(0, +) / Double(values.count)
        return String(format: "%.2f", average)
    }
}

struct TeacherLessonAttendanceItemDraft: Hashable {
    let studentID: Int
    let status: String
    let comment: String?
}

struct TeacherAttendanceExceptionDraft: Hashable {
    let studentID: Int
    let status: String
    let comment: String?
}

private struct TeacherListWrapper<Item: Decodable>: Decodable {
    let items: [Item]
}

enum TeacherCabinetError: LocalizedError {
    case noToken
    case badURL
    case badResponse
    case serverError(statusCode: Int, text: String)

    var errorDescription: String? {
        switch self {
        case .noToken:
            return "Нет токена авторизации. Войдите снова."

        case .badURL:
            return "Некорректный адрес запроса."

        case .badResponse:
            return "Некорректный ответ сервера."

        case .serverError(let statusCode, let text):
            let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)

            if statusCode == 401 {
                return "Сессия истекла. Войдите снова."
            }

            if statusCode == 403 {
                return "Нет доступа к этому разделу."
            }

            if statusCode == 404 {
                return "Раздел временно недоступен."
            }

            if statusCode >= 500 {
                return "Ошибка сервера. Попробуйте позже."
            }

            if cleanText.isEmpty {
                return "Ошибка сервера: \(statusCode)"
            }

            return "Ошибка сервера: \(statusCode). \(cleanText)"
        }
    }
}