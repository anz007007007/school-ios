//
//  AIChatViewModel.swift
//  scapp
//
//  Created by on 2026.
//

import Foundation
import Combine
import SchoolAPIClient

@MainActor
final class AIChatViewModel: ObservableObject {
    @Published var messages: [AIChatMessage] = []
    @Published var inputText = ""
    @Published var isSending = false
    @Published var isApplying = false
    @Published var errorMessage: String?
    @Published var previewResponse: AITeacherCommandPreviewResponseDTO?
    @Published var applyResults: [AITeacherCommandApplyResultDTO] = []

    private var dialogBaseCommandText: String?
    private var dialogClarifications: [String] = []

    let promptTemplates: [String] = [
        "Поставь Иванову Иван 5 по математике сегодня",
        "Поставь Петровой Анне 4 по русскому языку за диктант",
        "Выставь Сидорову 3 по истории за вчера, комментарий: нужно повторить тему",
        "Задай 5А по математике на завтра решить номера 10, 11, 12",
        "Создай домашнее задание для 6Б по английскому до понедельника: выучить слова по теме Food",
        "Дай 7А по истории на 10 сентября прочитать параграф 4 и ответить на вопросы"
    ]

    var canSend: Bool {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !text.isEmpty && text.count <= 4000 && !isSending && !isApplying
    }

    var canApplyCommands: Bool {
        guard let previewResponse else {
            return false
        }

        return previewResponse.status == "ready"
            && !previewResponse.commands.isEmpty
            && previewResponse.commands.allSatisfy { $0.isReady && $0.isSupported }
            && !isSending
            && !isApplying
    }

    var currentMissingFields: [AITeacherCommandMissingField] {
        guard let previewResponse else {
            return []
        }

        let fields = previewResponse.commands.flatMap { $0.missingFields() }
        return Array(Set(fields)).sorted { $0.rawValue < $1.rawValue }
    }

    var clarificationQuestion: String? {
        guard previewResponse?.status == "need_clarification" else {
            return nil
        }

        if let first = currentMissingFields.first {
            return first.question
        }

        return previewResponse?.message ?? "Уточните недостающие данные"
    }

    init() {
        resetToGreeting()
    }

    func resetToGreeting() {
        messages = [
            AIChatMessage(
                role: .assistant,
                content: """
                Здравствуйте! Я ИИ-помощник учителя.

                Я могу помочь:
                • поставить оценку ученику;
                • создать домашнее задание для класса.

                Если мне не хватит данных, я задам уточняющий вопрос. Вам не нужно повторять всю команду — можно написать только дополнение.
                """
            )
        ]

        inputText = ""
        errorMessage = nil
        previewResponse = nil
        applyResults = []
        dialogBaseCommandText = nil
        dialogClarifications = []
        isSending = false
        isApplying = false
    }

    func insertPrompt(_ prompt: String) {
        inputText = prompt
    }

    func clearDialog() {
        resetToGreeting()
    }

    func startNewCommand() {
        previewResponse = nil
        applyResults = []
        dialogBaseCommandText = nil
        dialogClarifications = []

        messages.append(
            AIChatMessage(
                role: .system,
                content: "Начинаем новую команду.",
                status: .sent
            )
        )
    }

    func cancelPreview() {
        previewResponse = nil
        applyResults = []
        dialogBaseCommandText = nil
        dialogClarifications = []

        messages.append(
            AIChatMessage(
                role: .system,
                content: "Команда отменена.",
                status: .sent
            )
        )
    }

    func selectClassOption(_ option: AITeacherCommandOptionDTO, commandID: UUID) {
        updateCommand(commandID: commandID) { command in
            command.class_id = option.id
            command.class_name = option.name
        }

        addClarification("Класс: \(option.name)")
        refreshReadinessAfterLocalSelection()
    }

    func selectStudentOption(_ option: AITeacherCommandOptionDTO, commandID: UUID) {
        updateCommand(commandID: commandID) { command in
            command.student_id = option.id
            command.student_name = option.name
        }

        addClarification("Ученик: \(option.name)")
        refreshReadinessAfterLocalSelection()
    }

    func selectSubjectOption(_ option: AITeacherCommandOptionDTO, commandID: UUID) {
        updateCommand(commandID: commandID) { command in
            command.subject_id = option.id
            command.subject_name = option.name
        }

        addClarification("Предмет: \(option.name)")
        refreshReadinessAfterLocalSelection()
    }

    func selectGradeValueOption(_ option: AITeacherCommandStringOptionDTO, commandID: UUID) {
        updateCommand(commandID: commandID) { command in
            command.grade_value = option.id.isEmpty ? option.name : option.id
        }

        addClarification("Оценка: \(option.name)")
        refreshReadinessAfterLocalSelection()
    }

    func selectGradeTypeOption(_ option: AITeacherCommandStringOptionDTO, commandID: UUID) {
        updateCommand(commandID: commandID) { command in
            command.grade_type = option.id
        }

        addClarification("Тип оценки: \(option.name)")
        refreshReadinessAfterLocalSelection()
    }

    func retryLastUserMessage(api: SchoolAPI) async {
        guard let lastUserMessage = messages.last(where: { $0.role == .user }) else {
            return
        }

        messages.removeAll { message in
            message.status == .error || message.role == .system
        }

        inputText = lastUserMessage.content
        await sendMessage(api: api)
    }

    func sendMessage(api: SchoolAPI) async {
        let cleanMessage = inputText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanMessage.isEmpty else {
            return
        }

        guard cleanMessage.count <= 4000 else {
            errorMessage = "Команда слишком длинная. Сократите текст до 4000 символов."
            return
        }

        guard !isSending && !isApplying else {
            return
        }

        errorMessage = nil
        applyResults = []
        isSending = true

        let previousPreviewResponse = previewResponse
        let textForBackend = buildDialogMessage(from: cleanMessage)

        messages.append(
            AIChatMessage(
                role: .user,
                content: cleanMessage,
                status: .sent
            )
        )

        inputText = ""

        let loadingMessage = AIChatMessage(
            role: .assistant,
            content: previewResponse == nil ? "Разбираю команду..." : "Обновляю команду...",
            status: .sending
        )

        messages.append(loadingMessage)

        do {
            let response = try await previewCommand(
                api: api,
                message: textForBackend
            )

            let normalizedResponse = normalizePreviewResponse(
                response,
                previousResponse: previousPreviewResponse,
                userText: cleanMessage
            )

            messages.removeAll { $0.id == loadingMessage.id }
            previewResponse = normalizedResponse

            handlePreviewResponse(normalizedResponse)
        } catch {
            messages.removeAll { $0.id == loadingMessage.id }

            let readableError = mapError(error)
            errorMessage = readableError

            messages.append(
                AIChatMessage(
                    role: .system,
                    content: readableError,
                    status: .error
                )
            )
        }

        isSending = false
    }

    func applyCommands(api: SchoolAPI) async {
        guard let previewResponse else {
            return
        }

        guard canApplyCommands else {
            messages.append(
                AIChatMessage(
                    role: .system,
                    content: "Команда не готова к выполнению. Уточните недостающие данные.",
                    status: .error
                )
            )
            return
        }

        isApplying = true
        errorMessage = nil
        applyResults = []

        let loadingMessage = AIChatMessage(
            role: .assistant,
            content: "Выполняю команду...",
            status: .sending
        )

        messages.append(loadingMessage)

        do {
            let response = try await applyCommandsRequest(
                api: api,
                commands: previewResponse.commands
            )

            messages.removeAll { $0.id == loadingMessage.id }

            applyResults = response.results

            messages.append(
                AIChatMessage(
                    role: .assistant,
                    content: makeApplyResultText(response.results),
                    status: .sent
                )
            )

            self.previewResponse = nil
            dialogBaseCommandText = nil
            dialogClarifications = []
        } catch {
            messages.removeAll { $0.id == loadingMessage.id }

            let readableError = mapError(error)
            errorMessage = readableError

            messages.append(
                AIChatMessage(
                    role: .system,
                    content: readableError,
                    status: .error
                )
            )
        }

        isApplying = false
    }

    private func buildDialogMessage(from userText: String) -> String {
        guard let previewResponse else {
            dialogBaseCommandText = userText
            dialogClarifications = []
            return userText
        }

        if dialogBaseCommandText == nil {
            dialogBaseCommandText = lastMeaningfulUserCommandBeforeClarification() ?? userText
        }

        dialogClarifications.append(userText)

        let currentCommandText = previewResponse.commands
            .enumerated()
            .map { index, command in
                commandContextText(command, index: index + 1)
            }
            .joined(separator: "\n\n")

        return """
        У учителя уже есть разобранная команда. Это НЕ новая команда, а уточнение или правка текущей команды.

        Исходная команда учителя:
        \(dialogBaseCommandText ?? "")

        Текущая разобранная команда:
        \(currentCommandText)

        История уточнений и правок учителя:
        \(dialogClarifications.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))

        Последняя правка учителя:
        \(userText)

        Задача:
        1. Обнови текущую команду с учётом последней правки.
        2. Верни ПОЛНУЮ команду, а не только изменённые поля.
        3. В ответе обязательно должны быть все уже известные поля: type, student_id, student_name, class_id, class_name, subject_id, subject_name, grade_value, grade_type, grade_date, comment, homework_title, homework_description, due_date.
        4. Сохрани ВСЕ уже известные поля, если учитель явно не просит их изменить.
        5. Никогда не очищай student_id, student_name, class_id, class_name, subject_id, subject_name, grade_value, grade_type, grade_date, comment, homework_title, homework_description, due_date без явной просьбы учителя.
        6. Если учитель пишет "поменяй дату на завтра" — измени только grade_date для оценки или due_date для домашнего задания.
        7. Если учитель пишет "замени оценку на 4" — измени только grade_value, не меняй grade_type, дату, ученика, класс и предмет.
        8. Если учитель пишет "другой предмет: русский язык" — измени только subject_id и subject_name, не меняй оценку, тип оценки, дату, ученика и класс.
        9. Если учитель пишет "описание: решить номера 5 и 6" — измени только homework_description.
        10. Если все обязательные поля заполнены, верни status = ready.
        11. Не проси уточнять дату, если grade_date или due_date уже заполнены.
        12. Не проси повторять всю команду заново.
        13. Верни команду в обычном формате preview.
        """
    }

    private func commandContextText(_ command: AITeacherCommandDTO, index: Int) -> String {
        var lines: [String] = []

        lines.append("Команда \(index): \(command.typeTitle)")
        lines.append("type: \(command.type)")
        lines.append("status: \(command.status)")

        if command.type == "create_grade" {
            lines.append("student_id: \(command.student_id.map(String.init) ?? "null")")
            lines.append("student_name: \(command.student_name ?? "null")")
            lines.append("class_id: \(command.class_id.map(String.init) ?? "null")")
            lines.append("class_name: \(command.class_name ?? "null")")
            lines.append("subject_id: \(command.subject_id.map(String.init) ?? "null")")
            lines.append("subject_name: \(command.subject_name ?? "null")")
            lines.append("grade_value: \(command.grade_value ?? "null")")
            lines.append("grade_type: \(command.grade_type ?? "null")")
            lines.append("grade_date: \(command.grade_date ?? "null")")
            lines.append("comment: \(command.comment ?? "null")")
        } else if command.type == "create_homework" {
            lines.append("class_id: \(command.class_id.map(String.init) ?? "null")")
            lines.append("class_name: \(command.class_name ?? "null")")
            lines.append("subject_id: \(command.subject_id.map(String.init) ?? "null")")
            lines.append("subject_name: \(command.subject_name ?? "null")")
            lines.append("homework_title: \(command.homework_title ?? "null")")
            lines.append("homework_description: \(command.homework_description ?? "null")")
            lines.append("due_date: \(command.due_date ?? "null")")
        }

        if let message = command.message, !message.isEmpty {
            lines.append("message: \(message)")
        }

        return lines.joined(separator: "\n")
    }

    private func normalizePreviewResponse(
        _ response: AITeacherCommandPreviewResponseDTO,
        previousResponse: AITeacherCommandPreviewResponseDTO?,
        userText: String
    ) -> AITeacherCommandPreviewResponseDTO {
        let userIntent = detectEditIntent(userText)

        let sourceCommands: [AITeacherCommandDTO]

        if response.commands.isEmpty, let previousResponse {
            sourceCommands = previousResponse.commands
        } else {
            sourceCommands = response.commands
        }

        var normalizedCommands = sourceCommands.enumerated().map { index, newCommand in
            let oldCommand = previousResponse?.commands[safe: index]

            return normalizeCommand(
                newCommand,
                oldCommand: oldCommand,
                userIntent: userIntent
            )
        }

        normalizedCommands = applyLocalUserEditIfNeeded(
            commands: normalizedCommands,
            userText: userText,
            userIntent: userIntent
        )

        normalizedCommands = normalizedCommands.map { command in
            var mutable = command

            if mutable.missingFields().isEmpty && mutable.isSupported {
                mutable.status = "ready"
                mutable.message = "Команда готова к выполнению."
            }

            return mutable
        }

        let allCommandsReady = !normalizedCommands.isEmpty
            && normalizedCommands.allSatisfy {
                $0.isSupported && $0.missingFields().isEmpty
            }

        return AITeacherCommandPreviewResponseDTO(
            status: allCommandsReady ? "ready" : response.status,
            message: allCommandsReady ? "Команды готовы к выполнению." : response.message,
            provider: response.provider,
            model: response.model,
            commands: normalizedCommands,
            raw: response.raw
        )
    }

    private func normalizeCommand(
        _ newCommand: AITeacherCommandDTO,
        oldCommand: AITeacherCommandDTO?,
        userIntent: AICommandEditIntent
    ) -> AITeacherCommandDTO {
        guard let oldCommand else {
            var command = newCommand

            if command.missingFields().isEmpty && command.isSupported {
                command.status = "ready"
                command.message = "Команда готова к выполнению."
            }

            return command
        }

        var command = newCommand

        command.type = cleanOptional(command.type) ?? oldCommand.type

        if command.type != "create_grade" && command.type != "create_homework" {
            command.type = oldCommand.type
        }

        if command.type == "create_grade" {
            mergeGradeCommand(
                command: &command,
                oldCommand: oldCommand,
                userIntent: userIntent
            )
        } else if command.type == "create_homework" {
            mergeHomeworkCommand(
                command: &command,
                oldCommand: oldCommand,
                userIntent: userIntent
            )
        }

        command.available_students = command.available_students ?? oldCommand.available_students
        command.available_classes = command.available_classes ?? oldCommand.available_classes
        command.available_subjects = command.available_subjects ?? oldCommand.available_subjects
        command.available_grade_values = command.available_grade_values ?? oldCommand.available_grade_values
        command.available_grade_types = command.available_grade_types ?? oldCommand.available_grade_types

        if command.missingFields().isEmpty && command.isSupported {
            command.status = "ready"
            command.message = "Команда готова к выполнению."
        }

        return command
    }

    private func mergeGradeCommand(
        command: inout AITeacherCommandDTO,
        oldCommand: AITeacherCommandDTO,
        userIntent: AICommandEditIntent
    ) {
        if userIntent != .student {
            command.student_id = command.student_id ?? oldCommand.student_id
            command.student_name = cleanOptional(command.student_name) ?? oldCommand.student_name
        } else {
            command.student_id = command.student_id ?? oldCommand.student_id
            command.student_name = cleanOptional(command.student_name) ?? oldCommand.student_name
        }

        if userIntent != .class {
            command.class_id = command.class_id ?? oldCommand.class_id
            command.class_name = cleanOptional(command.class_name) ?? oldCommand.class_name
        } else {
            command.class_id = command.class_id ?? oldCommand.class_id
            command.class_name = cleanOptional(command.class_name) ?? oldCommand.class_name
        }

        if userIntent != .subject {
            command.subject_id = command.subject_id ?? oldCommand.subject_id
            command.subject_name = cleanOptional(command.subject_name) ?? oldCommand.subject_name
        } else {
            command.subject_id = command.subject_id ?? oldCommand.subject_id
            command.subject_name = cleanOptional(command.subject_name) ?? oldCommand.subject_name
        }

        if userIntent != .gradeValue {
            command.grade_value = cleanOptional(command.grade_value) ?? oldCommand.grade_value
        } else {
            command.grade_value = cleanOptional(command.grade_value) ?? oldCommand.grade_value
        }

        if userIntent != .gradeType {
            command.grade_type = cleanOptional(command.grade_type) ?? oldCommand.grade_type
        } else {
            command.grade_type = cleanOptional(command.grade_type) ?? oldCommand.grade_type
        }

        if userIntent != .gradeDate {
            command.grade_date = cleanOptional(command.grade_date) ?? oldCommand.grade_date
        } else {
            command.grade_date = cleanOptional(command.grade_date) ?? oldCommand.grade_date
        }

        if userIntent != .comment {
            command.comment = cleanOptional(command.comment) ?? oldCommand.comment
        } else {
            command.comment = cleanOptional(command.comment) ?? oldCommand.comment
        }

        command.homework_title = nil
        command.homework_description = nil
        command.due_date = nil
    }

    private func mergeHomeworkCommand(
        command: inout AITeacherCommandDTO,
        oldCommand: AITeacherCommandDTO,
        userIntent: AICommandEditIntent
    ) {
        if userIntent != .class {
            command.class_id = command.class_id ?? oldCommand.class_id
            command.class_name = cleanOptional(command.class_name) ?? oldCommand.class_name
        } else {
            command.class_id = command.class_id ?? oldCommand.class_id
            command.class_name = cleanOptional(command.class_name) ?? oldCommand.class_name
        }

        if userIntent != .subject {
            command.subject_id = command.subject_id ?? oldCommand.subject_id
            command.subject_name = cleanOptional(command.subject_name) ?? oldCommand.subject_name
        } else {
            command.subject_id = command.subject_id ?? oldCommand.subject_id
            command.subject_name = cleanOptional(command.subject_name) ?? oldCommand.subject_name
        }

        if userIntent != .homeworkTitle {
            command.homework_title = cleanOptional(command.homework_title) ?? oldCommand.homework_title
        } else {
            command.homework_title = cleanOptional(command.homework_title) ?? oldCommand.homework_title
        }

        if userIntent != .homeworkDescription {
            command.homework_description = cleanOptional(command.homework_description) ?? oldCommand.homework_description
        } else {
            command.homework_description = cleanOptional(command.homework_description) ?? oldCommand.homework_description
        }

        if userIntent != .dueDate {
            command.due_date = cleanOptional(command.due_date) ?? oldCommand.due_date
        } else {
            command.due_date = cleanOptional(command.due_date) ?? oldCommand.due_date
        }

        command.student_id = nil
        command.student_name = nil
        command.grade_value = nil
        command.grade_type = nil
        command.grade_date = nil
        command.comment = nil
    }

    private func applyLocalUserEditIfNeeded(
        commands: [AITeacherCommandDTO],
        userText: String,
        userIntent: AICommandEditIntent
    ) -> [AITeacherCommandDTO] {
        commands.map { command in
            var mutable = command

            switch userIntent {
            case .gradeValue:
                if mutable.type == "create_grade",
                   let gradeValue = extractGradeValue(from: userText) {
                    mutable.grade_value = gradeValue
                }

            case .gradeDate:
                if mutable.type == "create_grade",
                   let dateValue = extractRelativeDate(from: userText) {
                    mutable.grade_date = dateValue
                }

            case .dueDate:
                if mutable.type == "create_homework",
                   let dateValue = extractRelativeDate(from: userText) {
                    mutable.due_date = dateValue
                }

            case .comment:
                if mutable.type == "create_grade",
                   let comment = extractTextAfterKeyword(
                    from: userText,
                    keywords: ["комментарий", "коммент", "с комментарием", "пояснение", "заметка"]
                   ) {
                    mutable.comment = comment
                }

            case .homeworkDescription:
                if mutable.type == "create_homework",
                   let description = extractHomeworkDescription(from: userText) {
                    mutable.homework_description = description
                }

            case .homeworkTitle:
                if mutable.type == "create_homework",
                   let title = extractTextAfterKeyword(
                    from: userText,
                    keywords: ["название", "заголовок", "тема"]
                   ) {
                    mutable.homework_title = title
                }

            case .student, .class, .subject, .gradeType, .unknown:
                break
            }

            if mutable.missingFields().isEmpty && mutable.isSupported {
                mutable.status = "ready"
                mutable.message = "Команда готова к выполнению."
            }

            return mutable
        }
    }

    private func extractGradeValue(from text: String) -> String? {
        let lower = text.lowercased()

        let patterns = [
            #"оценк[а-я\s]*на\s*([2345])"#,
            #"замен[а-я\s]*оценк[а-я\s]*на\s*([2345])"#,
            #"замен[а-я\s]*на\s*([2345])"#,
            #"поменя[а-я\s]*оценк[а-я\s]*на\s*([2345])"#,
            #"поменя[а-я\s]*на\s*([2345])"#,
            #"исправ[а-я\s]*оценк[а-я\s]*на\s*([2345])"#,
            #"исправ[а-я\s]*на\s*([2345])"#,
            #"постав[а-я\s]*([2345])"#,
            #"выстав[а-я\s]*([2345])"#,
            #"^\s*([2345])\s*$"#
        ]

        for pattern in patterns {
            if let value = firstRegexGroup(in: lower, pattern: pattern) {
                return value
            }
        }

        return nil
    }

    private func extractRelativeDate(from text: String) -> String? {
        let lower = text.lowercased()
        let calendar = Calendar.current
        let today = Date()

        if lower.contains("сегодня") {
            return Self.apiDateFormatter.string(from: today)
        }

        if lower.contains("завтра") {
            let date = calendar.date(byAdding: .day, value: 1, to: today) ?? today
            return Self.apiDateFormatter.string(from: date)
        }

        if lower.contains("послезавтра") {
            let date = calendar.date(byAdding: .day, value: 2, to: today) ?? today
            return Self.apiDateFormatter.string(from: date)
        }

        if lower.contains("вчера") {
            let date = calendar.date(byAdding: .day, value: -1, to: today) ?? today
            return Self.apiDateFormatter.string(from: date)
        }

        if let date = extractDateByDotFormat(from: lower) {
            return Self.apiDateFormatter.string(from: date)
        }

        return nil
    }

    private func extractDateByDotFormat(from text: String) -> Date? {
        guard let value = firstRegexGroup(
            in: text,
            pattern: #"(\d{1,2}\.\d{1,2}(?:\.\d{2,4})?)"#
        ) else {
            return nil
        }

        let formats = [
            "dd.MM.yyyy",
            "d.M.yyyy",
            "dd.MM.yy",
            "d.M.yy",
            "dd.MM",
            "d.M"
        ]

        for format in formats {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "ru_RU")

            if let date = formatter.date(from: value) {
                if format == "dd.MM" || format == "d.M" {
                    let calendar = Calendar.current
                    let year = calendar.component(.year, from: Date())
                    var components = calendar.dateComponents([.day, .month], from: date)
                    components.year = year
                    return calendar.date(from: components)
                }

                return date
            }
        }

        return nil
    }

    private func extractHomeworkDescription(from text: String) -> String? {
        if let value = extractTextAfterKeyword(
            from: text,
            keywords: ["описание", "задание", "домашка", "домашнее задание"]
        ) {
            return value
        }

        let lower = text.lowercased()

        if lower.contains("решить")
            || lower.contains("прочитать")
            || lower.contains("выучить")
            || lower.contains("номера")
            || lower.contains("параграф") {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
    }

    private func extractTextAfterKeyword(
        from text: String,
        keywords: [String]
    ) -> String? {
        let lower = text.lowercased()

        for keyword in keywords {
            if let range = lower.range(of: keyword) {
                let raw = String(text[range.upperBound...])
                    .replacingOccurrences(of: ":", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                let cleaned = removeLeadingServiceWords(raw)

                if !cleaned.isEmpty {
                    return cleaned
                }
            }
        }

        return nil
    }

    private func removeLeadingServiceWords(_ value: String) -> String {
        var result = value.trimmingCharacters(in: .whitespacesAndNewlines)

        let prefixes = [
            "на ",
            "на:",
            "-",
            "—"
        ]

        for prefix in prefixes {
            if result.lowercased().hasPrefix(prefix) {
                result = String(result.dropFirst(prefix.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return result
    }

    private func firstRegexGroup(
        in text: String,
        pattern: String
    ) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)

        guard let match = regex.firstMatch(in: text, range: nsRange),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }

        return String(text[range])
    }

    private static let apiDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    private func detectEditIntent(_ text: String) -> AICommandEditIntent {
        let lower = text.lowercased()

        // 1. Сначала проверяем ученика
        if lower.contains("ученик")
            || lower.contains("ученика")
            || lower.contains("ученицу")
            || lower.contains("ребен")
            || lower.contains("ребён")
            || lower.contains("иванов")
            || lower.contains("петров")
            || lower.contains("сидоров") {
            return .student
        }

        // 2. Проверяем класс
        if lower.contains("класс")
            || lower.contains("5а")
            || lower.contains("5б")
            || lower.contains("6а")
            || lower.contains("6б")
            || lower.contains("7а")
            || lower.contains("7б")
            || lower.contains("8а")
            || lower.contains("8б")
            || lower.contains("9а")
            || lower.contains("9б") {
            return .class
        }

        // 3. Проверяем предмет
        if lower.contains("предмет")
            || lower.contains("математ")
            || lower.contains("русск")
            || lower.contains("литерат")
            || lower.contains("истори")
            || lower.contains("англий")
            || lower.contains("биолог")
            || lower.contains("географ")
            || lower.contains("физик")
            || lower.contains("хими")
            || lower.contains("информат") {
            return .subject
        }

        // 4. Проверяем дату (ДО проверки оценки!)
        if lower.contains("дат")
            || lower.contains("сегодня")
            || lower.contains("завтра")
            || lower.contains("послезавтра")
            || lower.contains("вчера")
            || lower.contains("понедельник")
            || lower.contains("вторник")
            || lower.contains("сред")
            || lower.contains("четверг")
            || lower.contains("пятниц")
            || lower.contains("суббот")
            || lower.contains("воскрес")
            || lower.range(of: #"\d{1,2}\.\d{1,2}"#, options: .regularExpression) != nil
            || lower.range(of: #"\d{1,2}\s+(январ|феврал|март|апрел|ма|июн|июл|август|сентябр|октябр|ноябр|декабр)"#, options: .regularExpression) != nil {
            if previewResponse?.commands.first?.type == "create_homework" {
                return .dueDate
            }

            return .gradeDate
        }

        // 5. Проверяем оценку (после даты)
        if lower.contains("оценк")
            || lower.contains("балл")
            || lower.range(of: #"замен[а-я\s]*на\s*[2345]"#, options: .regularExpression) != nil
            || lower.range(of: #"замен[а-я\s]*оценк[а-я\s]*на\s*[2345]"#, options: .regularExpression) != nil
            || lower.range(of: #"поменя[а-я\s]*на\s*[2345]"#, options: .regularExpression) != nil
            || lower.range(of: #"поменя[а-я\s]*оценк[а-я\s]*на\s*[2345]"#, options: .regularExpression) != nil
            || lower.range(of: #"исправ[а-я\s]*на\s*[2345]"#, options: .regularExpression) != nil
            || lower.range(of: #"исправ[а-я\s]*оценк[а-я\s]*на\s*[2345]"#, options: .regularExpression) != nil
            || lower == "5"
            || lower == "4"
            || lower == "3"
            || lower == "2" {
            return .gradeValue
        }

        // 6. Проверяем тип оценки
        if lower.contains("тип")
            || lower.contains("контрольн")
            || lower.contains("самостоятельн")
            || lower.contains("домашн")
            || lower.contains("тест")
            || lower.contains("экзамен") {
            return .gradeType
        }

        // 7. Проверяем комментарий
        if lower.contains("коммент") {
            return .comment
        }

        // 8. Проверяем заголовок домашки
        if lower.contains("название")
            || lower.contains("заголовок") {
            return .homeworkTitle
        }

        // 9. Проверяем описание домашки
        if lower.contains("описание")
            || lower.contains("задание")
            || lower.contains("решить")
            || lower.contains("прочитать")
            || lower.contains("выучить")
            || lower.contains("номера")
            || lower.contains("параграф") {
            return .homeworkDescription
        }

        // 10. Проверяем срок выполнения
        if lower.contains("срок")
            || lower.contains("до ")
            || lower.contains("на завтра")
            || lower.contains("к понедельнику") {
            return .dueDate
        }

        return .unknown
    }

    private func cleanOptional(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func lastMeaningfulUserCommandBeforeClarification() -> String? {
        messages
            .filter { $0.role == .user }
            .last?
            .content
    }

    private func handlePreviewResponse(_ response: AITeacherCommandPreviewResponseDTO) {
        switch response.status {
        case "ready":
            messages.append(
                AIChatMessage(
                    role: .assistant,
                    content: "Команда готова. Проверьте данные ниже. Если нужно что-то изменить, напишите коротко: «поменяй дату на завтра», «замени оценку на 4», «измени предмет на русский язык».",
                    status: .sent
                )
            )

        case "need_clarification":
            messages.append(
                AIChatMessage(
                    role: .assistant,
                    content: makeClarificationText(response),
                    status: .sent
                )
            )

        case "unsupported":
            messages.append(
                AIChatMessage(
                    role: .assistant,
                    content: "Эта команда пока не поддерживается. Сейчас можно только ставить оценки и создавать домашние задания.",
                    status: .sent
                )
            )

        case "error":
            messages.append(
                AIChatMessage(
                    role: .system,
                    content: response.message ?? "Не удалось разобрать команду. Попробуйте сформулировать иначе.",
                    status: .error
                )
            )

        default:
            messages.append(
                AIChatMessage(
                    role: .system,
                    content: response.message ?? "Неизвестный статус ответа сервера: \(response.status)",
                    status: .error
                )
            )
        }
    }

    private func makeClarificationText(_ response: AITeacherCommandPreviewResponseDTO) -> String {
        let missing = Array(Set(response.commands.flatMap { $0.missingFields() }))
            .sorted { $0.rawValue < $1.rawValue }

        if let first = missing.first {
            return """
            Нужно уточнение: \(first.title).

            \(first.hint)

            Напишите только недостающую часть. Повторять всю команду не нужно.
            """
        }

        if let message = response.message, !message.isEmpty {
            return """
            \(message)

            Напишите уточнение одним сообщением. Повторять всю команду не нужно.
            """
        }

        return "Нужно уточнение. Напишите недостающую часть, повторять всю команду не нужно."
    }

    private func updateCommand(commandID: UUID, update: (inout AITeacherCommandDTO) -> Void) {
        guard var response = previewResponse else {
            return
        }

        response = AITeacherCommandPreviewResponseDTO(
            status: response.status,
            message: response.message,
            provider: response.provider,
            model: response.model,
            commands: response.commands.map { command in
                var mutable = command

                if mutable.id == commandID {
                    update(&mutable)
                }

                return mutable
            },
            raw: response.raw
        )

        previewResponse = response
    }

    private func addClarification(_ text: String) {
        dialogClarifications.append(text)

        messages.append(
            AIChatMessage(
                role: .user,
                content: text,
                status: .sent
            )
        )
    }

    private func refreshReadinessAfterLocalSelection() {
        guard let response = previewResponse else {
            return
        }

        let updatedCommands = response.commands.map { command -> AITeacherCommandDTO in
            var mutable = command

            if mutable.missingFields().isEmpty && mutable.isSupported {
                mutable.status = "ready"
                mutable.message = "Команда готова к выполнению."
            }

            return mutable
        }

        let allReady = !updatedCommands.isEmpty && updatedCommands.allSatisfy {
            $0.status == "ready" && $0.isSupported && $0.missingFields().isEmpty
        }

        previewResponse = AITeacherCommandPreviewResponseDTO(
            status: allReady ? "ready" : response.status,
            message: allReady ? "Команды готовы к выполнению." : response.message,
            provider: response.provider,
            model: response.model,
            commands: updatedCommands,
            raw: response.raw
        )

        if allReady {
            messages.append(
                AIChatMessage(
                    role: .assistant,
                    content: "Теперь все обязательные данные заполнены. Проверьте карточку и нажмите «Выполнить».",
                    status: .sent
                )
            )
        }
    }

    private func previewCommand(
        api: SchoolAPI,
        message: String
    ) async throws -> AITeacherCommandPreviewResponseDTO {
        let body = AITeacherCommandPreviewRequestDTO(message: message)

        let data = try await sendJSONRequest(
            api: api,
            path: "/api/v1/ai/teacher/commands/preview",
            method: "POST",
            body: body,
            logPrefix: "AI TEACHER COMMAND PREVIEW"
        )

        do {
            return try JSONDecoder().decode(AITeacherCommandPreviewResponseDTO.self, from: data)
        } catch {
            let responseText = String(data: data, encoding: .utf8) ?? ""
            print("AI TEACHER COMMAND PREVIEW DECODING ERROR:", error.localizedDescription)
            print("AI TEACHER COMMAND PREVIEW RAW BODY:", responseText)
            throw AIChatError.decodingError(responseText.isEmpty ? error.localizedDescription : responseText)
        }
    }

    private func applyCommandsRequest(
        api: SchoolAPI,
        commands: [AITeacherCommandDTO]
    ) async throws -> AITeacherCommandApplyResponseDTO {
        let body = AITeacherCommandApplyRequestDTO(commands: commands)

        let data = try await sendJSONRequest(
            api: api,
            path: "/api/v1/ai/teacher/commands/apply",
            method: "POST",
            body: body,
            logPrefix: "AI TEACHER COMMAND APPLY"
        )

        do {
            return try JSONDecoder().decode(AITeacherCommandApplyResponseDTO.self, from: data)
        } catch {
            let responseText = String(data: data, encoding: .utf8) ?? ""
            print("AI TEACHER COMMAND APPLY DECODING ERROR:", error.localizedDescription)
            print("AI TEACHER COMMAND APPLY RAW BODY:", responseText)
            throw AIChatError.decodingError(responseText.isEmpty ? error.localizedDescription : responseText)
        }
    }

    private func sendJSONRequest<Body: Encodable>(
        api: SchoolAPI,
        path: String,
        method: String,
        body: Body,
        logPrefix: String
    ) async throws -> Data {
        guard let token = api.authToken else {
            AuthSessionEvents.notifySessionExpired()
            throw AIChatError.noToken
        }

        guard let url = URL(string: "https://sc.it-status.ru\(path)") else {
            throw AIChatError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 60
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.applyMobileClientHeaders()
        request.httpBody = try JSONEncoder().encode(body)

        #if DEBUG
        print("\(logPrefix) REQUEST:", method, url.absoluteString)
        #endif

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIChatError.badResponse
        }

        let responseText = String(data: data, encoding: .utf8) ?? ""

        #if DEBUG
        print("\(logPrefix) RESPONSE STATUS:", httpResponse.statusCode)
        print("\(logPrefix) RESPONSE BODY:", responseText)
        #endif

        if httpResponse.statusCode == 401 {
            AuthSessionEvents.notifySessionExpired()
            throw AIChatError.serverError(statusCode: httpResponse.statusCode, text: responseText)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw AIChatError.serverError(statusCode: httpResponse.statusCode, text: responseText)
        }

        return data
    }

    private func makeApplyResultText(_ results: [AITeacherCommandApplyResultDTO]) -> String {
        guard !results.isEmpty else {
            return "Команда выполнена, но сервер не вернул подробный результат."
        }

        return results.map { result in
            let message = result.message ?? defaultResultMessage(result)

            switch result.status {
            case "created":
                return "Готово: \(message)"
            case "skipped":
                return "Команда пропущена: \(message)"
            case "error":
                return "Ошибка: \(message)"
            default:
                return "\(result.statusTitle): \(message)"
            }
        }
        .joined(separator: "\n")
    }

    private func defaultResultMessage(_ result: AITeacherCommandApplyResultDTO) -> String {
        switch result.type {
        case "create_grade":
            return result.status == "created" ? "оценка создана." : "оценка не создана."
        case "create_homework":
            return result.status == "created" ? "домашнее задание создано." : "домашнее задание не создано."
        default:
            return "команда обработана."
        }
    }

    private func mapError(_ error: Error) -> String {
        if let aiError = error as? AIChatError {
            switch aiError {
            case .noToken:
                return "Сессия истекла. Войдите заново."

            case .badURL:
                return "Некорректный адрес сервера."

            case .badResponse:
                return "Некорректный ответ сервера."

            case .decodingError(let text):
                if text.localizedCaseInsensitiveContains("unauthorized") {
                    return "Сессия истекла. Войдите заново."
                }

                if text.localizedCaseInsensitiveContains("forbidden") {
                    return "Нет прав на выполнение команды. Проверьте доступ к классу и предмету."
                }

                return "Сервер вернул ответ в неожиданном формате. Попробуйте ещё раз или сообщите разработчику."

            case .serverError(let statusCode, let text):
                switch statusCode {
                case 401:
                    return "Сессия истекла. Войдите заново."
                case 403:
                    return "Нет прав на выполнение команды. Проверьте, что у вас есть доступ к этому классу и предмету."
                case 422:
                    return text.isEmpty ? "Команду нужно уточнить." : text
                case 429:
                    return "Слишком много запросов. Подождите немного и попробуйте снова."
                case 500, 502, 503:
                    return "ИИ-помощник временно недоступен. Попробуйте позже."
                default:
                    return text.isEmpty ? "Не удалось выполнить команду. Проверьте интернет и попробуйте ещё раз." : text
                }
            }
        }

        let nsError = error as NSError

        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet:
                return "Нет подключения к интернету. Проверьте сеть и попробуйте снова."
            case NSURLErrorTimedOut:
                return "Ответ занимает слишком много времени. Попробуйте повторить команду."
            default:
                return "Не удалось выполнить команду. Проверьте интернет и попробуйте ещё раз."
            }
        }

        return "Не удалось выполнить команду. Попробуйте ещё раз."
    }
}

enum AIChatError: LocalizedError {
    case noToken
    case badURL
    case badResponse
    case decodingError(String)
    case serverError(statusCode: Int, text: String)

    var errorDescription: String? {
        switch self {
        case .noToken:
            return "Нет токена авторизации."
        case .badURL:
            return "Некорректный URL."
        case .badResponse:
            return "Некорректный ответ сервера."
        case .decodingError(let text):
            return "Ошибка чтения ответа: \(text)"
        case .serverError(let statusCode, let text):
            if text.isEmpty {
                return "Ошибка сервера: \(statusCode)"
            }

            return "Ошибка сервера: \(statusCode). \(text)"
        }
    }
}

private enum AICommandEditIntent: Equatable {
    case student
    case `class`
    case subject
    case gradeValue
    case gradeType
    case gradeDate
    case comment
    case homeworkTitle
    case homeworkDescription
    case dueDate
    case unknown
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else {
            return nil
        }

        return self[index]
    }
}