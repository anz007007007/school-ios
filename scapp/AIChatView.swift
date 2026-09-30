import SwiftUI
import SchoolAPIClient
import UIKit
import Speech

struct AIChatView: View {
    @EnvironmentObject var appState: AppState

    @StateObject private var viewModel = AIChatViewModel()
    @StateObject private var speechService = SpeechRecognitionService()

    @State private var showClearConfirmation = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            warningBanner

            if speechService.errorMessage != nil {
                speechErrorBanner
            }

            messagesList

            if let previewResponse = viewModel.previewResponse {
                commandPreviewSection(previewResponse)
            }

            promptChips
        }
        .safeAreaInset(edge: .bottom) {
            inputBar
        }
        .navigationTitle("ИИ-команды")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    hideKeyboard()
                    showClearConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Очистить диалог с ИИ-помощником")
            }

            ToolbarItemGroup(placement: .keyboard) {
                Spacer()

                Button("Готово") {
                    hideKeyboard()
                }
                .fontWeight(.bold)
            }
        }
        .confirmationDialog(
            "Очистить текущий диалог с ИИ-помощником?",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Очистить", role: .destructive) {
                hideKeyboard()
                viewModel.clearDialog()
            }

            Button("Отмена", role: .cancel) {}
        }
        .appScreenBackground()
        .appNavigationStyle()
        .onChange(of: speechService.recognizedText) { newValue in
            let cleanText = newValue.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !cleanText.isEmpty else {
                return
            }

            viewModel.inputText = cleanText
        }
        .onDisappear {
            speechService.stopRecording()
        }
    }

    private var warningBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checklist.checked")
                .foregroundStyle(AppTheme.warning)

            Text("ИИ-помощник выполняет только команды учителя: поставить оценку или создать домашнее задание. Перед записью данных обязательно проверьте preview.")
                .font(.caption)
                .foregroundStyle(AppTheme.brownText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.warningSoft.opacity(0.95))
        .overlay(
            Rectangle()
                .fill(AppTheme.border.opacity(0.45))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private var speechErrorBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "mic.slash.fill")
                .foregroundStyle(AppTheme.danger)

            Text(speechService.errorMessage ?? "")
                .font(.caption)
                .foregroundStyle(AppTheme.danger)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            Button {
                speechService.errorMessage = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(AppTheme.danger)
            }
            .accessibilityLabel("Скрыть ошибку голосового ввода")
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.dangerSoft.opacity(0.95))
        .overlay(
            Rectangle()
                .fill(AppTheme.danger.opacity(0.25))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        AIChatMessageBubble(
                            message: message,
                            onCopy: {
                                UIPasteboard.general.string = message.content
                            },
                            onRetry: {
                                hideKeyboard()

                                Task {
                                    await viewModel.retryLastUserMessage(api: appState.api)
                                }
                            }
                        )
                        .id(message.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .contentShape(Rectangle())
            .onTapGesture {
                hideKeyboard()
            }
            .onChange(of: viewModel.messages.count) {
                scrollToBottom(proxy)
            }
            .onChange(of: viewModel.isSending) {
                scrollToBottom(proxy)
            }
            .onChange(of: viewModel.isApplying) {
                scrollToBottom(proxy)
            }
        }
    }

    private func commandPreviewSection(_ preview: AITeacherCommandPreviewResponseDTO) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Проверка команды", systemImage: "doc.text.magnifyingglass")
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)

                    Spacer()

                    Text(statusTitle(preview.status))
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(statusColor(preview.status).opacity(0.14))
                        .foregroundStyle(statusColor(preview.status))
                        .clipShape(Capsule())
                }

                previewExplanation(preview)

                ForEach(preview.commands) { command in
                    AITeacherCommandPreviewCard(
                        command: command,
                        onSelectClass: { option in
                            viewModel.selectClassOption(option, commandID: command.id)
                        },
                        onSelectStudent: { option in
                            viewModel.selectStudentOption(option, commandID: command.id)
                        },
                        onSelectSubject: { option in
                            viewModel.selectSubjectOption(option, commandID: command.id)
                        },
                        onSelectGradeValue: { option in
                            viewModel.selectGradeValueOption(option, commandID: command.id)
                        },
                        onSelectGradeType: { option in
                            viewModel.selectGradeTypeOption(option, commandID: command.id)
                        }
                    )
                }

                if preview.status != "ready" {
                    missingFieldsBlock(preview)
                }

                if preview.status == "ready" {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Все обязательные данные найдены. Если всё верно, нажмите «Выполнить».")
                            .font(.caption)
                            .foregroundStyle(AppTheme.success)

                        Text("Если нужно изменить данные, напишите коротко: «поменяй дату на завтра», «замени оценку на 4», «измени предмет на русский язык».")
                            .font(.caption)
                            .foregroundStyle(AppTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: 10) {
                        Button {
                            hideKeyboard()
                            viewModel.startNewCommand()
                        } label: {
                            Text("Новая")
                        }
                        .buttonStyle(AppSecondaryButtonStyle())
                        .disabled(viewModel.isApplying)

                        Button {
                            hideKeyboard()
                            viewModel.cancelPreview()
                        } label: {
                            Text("Отмена")
                        }
                        .buttonStyle(AppSecondaryButtonStyle())
                        .disabled(viewModel.isApplying)

                        Button {
                            hideKeyboard()

                            Task {
                                await viewModel.applyCommands(api: appState.api)
                            }
                        } label: {
                            if viewModel.isApplying {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Выполнить")
                            }
                        }
                        .buttonStyle(AppPrimaryButtonStyle())
                        .disabled(!viewModel.canApplyCommands)
                    }
                } else if preview.status == "need_clarification" {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Можно уточнить одним коротким сообщением. Повторять всю команду не нужно.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.muted)

                        if let question = viewModel.clarificationQuestion {
                            Text(question)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(AppTheme.warning)
                        }
                    }
                } else {
                    Text("Кнопка «Выполнить» появится, когда команда будет полностью готова.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                }
            }
            .padding()
        }
        .frame(maxHeight: 360)
        .background(AppTheme.card.opacity(0.98))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radius)
                .stroke(AppTheme.border.opacity(0.75), lineWidth: 1)
        )
        .shadow(color: AppTheme.accentDark.opacity(0.12), radius: 16, x: 0, y: 8)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func previewExplanation(_ preview: AITeacherCommandPreviewResponseDTO) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if preview.status == "ready" {
                Label("Команда готова к выполнению.", systemImage: "checkmark.circle.fill")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.success)

                Text("Проверьте значения в карточке: ученика, класс, предмет, оценку или домашнее задание и срок.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            } else if preview.status == "need_clarification" {
                Label("Нужно уточнение.", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.warning)

                Text(preview.message ?? "ИИ не смог однозначно определить все данные.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            } else if preview.status == "unsupported" {
                Label("Команда не поддерживается.", systemImage: "xmark.circle.fill")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.warning)

                Text("Сейчас можно только ставить оценки и создавать домашние задания.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            } else {
                Label("Ошибка разбора команды.", systemImage: "xmark.octagon.fill")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.danger)

                Text(preview.message ?? "Попробуйте сформулировать команду иначе.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            }
        }
    }

    private func missingFieldsBlock(_ preview: AITeacherCommandPreviewResponseDTO) -> some View {
        let missing = preview.commands.flatMap { missingFields(for: $0) }

        return VStack(alignment: .leading, spacing: 8) {
            if preview.status == "need_clarification" || !missing.isEmpty {
                Label("Что нужно уточнить", systemImage: "questionmark.circle.fill")
                    .font(.footnote)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.warning)

                if missing.isEmpty {
                    Text("Backend вернул status = need_clarification, но все основные поля выглядят заполненными. Проверьте текст сообщения сервера выше или уточните команду более явно.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(Array(Set(missing)).sorted(), id: \.self) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(AppTheme.warning)

                            Text(item)
                                .font(.caption)
                                .foregroundStyle(AppTheme.warning)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                Text("Напишите новую команду с уточнением. Например: «Поставь Иванову Ивану из 5А 5 по математике сегодня за контрольную».")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func missingFields(for command: AITeacherCommandDTO) -> [String] {
        var result: [String] = []

        if command.type == "create_grade" {
            if command.student_id == nil {
                result.append("Не определён ученик.")
            }

            if command.class_id == nil {
                result.append("Не определён класс.")
            }

            if command.subject_id == nil {
                result.append("Не определён предмет.")
            }

            if isBlank(command.grade_value) {
                result.append("Не указана оценка.")
            }

            if isBlank(command.grade_date) {
                result.append("Не указана дата оценки.")
            }
        } else if command.type == "create_homework" {
            if command.class_id == nil {
                result.append("Не определён класс.")
            }

            if command.subject_id == nil {
                result.append("Не определён предмет.")
            }

            if isBlank(command.homework_description) {
                result.append("Не указано описание домашнего задания.")
            }

            if isBlank(command.due_date) {
                result.append("Не указан срок домашнего задания.")
            }
        } else {
            result.append("Неподдерживаемый тип команды: \(command.type).")
        }

        if !command.isReady {
            result.append(command.message ?? "Backend пометил команду как неготовую.")
        }

        return result
    }

    private var promptChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.promptTemplates, id: \.self) { prompt in
                    Button {
                        viewModel.insertPrompt(prompt)
                        isInputFocused = true
                    } label: {
                        Text(shortPromptTitle(prompt))
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                    .appChip()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(AppTheme.backgroundWarm.opacity(0.9))
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField(
                speechService.isRecording ? "Говорите..." : "Команда или правка: поменяй дату на завтра...",
                text: $viewModel.inputText,
                axis: .vertical
            )
            .lineLimit(1...5)
            .focused($isInputFocused)
            .submitLabel(.send)
            .onSubmit {
                sendCurrentCommand()
            }
            .appField()
            .accessibilityLabel("Введите команду для ИИ-помощника")

            Button {
                hideKeyboard()

                Task {
                    await speechService.toggleRecording()
                }
            } label: {
                Image(systemName: speechService.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Color.white)
                    .frame(width: 48, height: 48)
                    .background(
                        speechService.isRecording
                        ? AppTheme.dangerGradient
                        : AppTheme.buttonGradient
                    )
                    .clipShape(Circle())
                    .shadow(
                        color: speechService.isRecording
                        ? AppTheme.danger.opacity(0.25)
                        : AppTheme.primaryDark.opacity(0.25),
                        radius: 10,
                        x: 0,
                        y: 6
                    )
            }
            .disabled(viewModel.isSending || viewModel.isApplying)
            .accessibilityLabel(speechService.isRecording ? "Остановить голосовой ввод" : "Начать голосовой ввод")

            Button {
                sendCurrentCommand()
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Color.white)
                    .frame(width: 48, height: 48)
                    .background(
                        viewModel.canSend
                        ? AppTheme.buttonGradient
                        : LinearGradient(
                            colors: [AppTheme.muted.opacity(0.45)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(Circle())
                    .shadow(
                        color: AppTheme.primaryDark.opacity(viewModel.canSend ? 0.25 : 0),
                        radius: 10,
                        x: 0,
                        y: 6
                    )
            }
            .disabled(!viewModel.canSend)
            .accessibilityLabel("Отправить команду ИИ-помощнику")
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(AppTheme.card.opacity(0.97))
        .overlay(
            Rectangle()
                .fill(AppTheme.border.opacity(0.45))
                .frame(height: 1),
            alignment: .top
        )
    }

    private func sendCurrentCommand() {
        hideKeyboard()
        speechService.stopRecording()

        Task {
            await viewModel.sendMessage(api: appState.api)
        }
    }

    private func hideKeyboard() {
        isInputFocused = false
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        guard let lastID = viewModel.messages.last?.id else {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.easeOut(duration: 0.22)) {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        }
    }

    private func shortPromptTitle(_ value: String) -> String {
        let lower = value.lowercased()

        if lower.contains("поставь") || lower.contains("выставь") {
            return "Оценка"
        }

        if lower.contains("задай") || lower.contains("домашнее") || lower.contains("домаш") {
            return "Домашка"
        }

        return "Команда"
    }

    private func statusTitle(_ status: String) -> String {
        switch status {
        case "ready":
            return "Готово"
        case "need_clarification":
            return "Уточнить"
        case "unsupported":
            return "Не поддерживается"
        case "error":
            return "Ошибка"
        default:
            return status
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "ready":
            return AppTheme.success
        case "need_clarification":
            return AppTheme.warning
        case "unsupported":
            return AppTheme.warning
        case "error":
            return AppTheme.danger
        default:
            return AppTheme.muted
        }
    }

    private func isBlank(_ value: String?) -> Bool {
        guard let value else {
            return true
        }

        return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct AITeacherCommandPreviewCard: View {
    let command: AITeacherCommandDTO

    let onSelectClass: (AITeacherCommandOptionDTO) -> Void
    let onSelectStudent: (AITeacherCommandOptionDTO) -> Void
    let onSelectSubject: (AITeacherCommandOptionDTO) -> Void
    let onSelectGradeValue: (AITeacherCommandStringOptionDTO) -> Void
    let onSelectGradeType: (AITeacherCommandStringOptionDTO) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(command.typeTitle, systemImage: commandIcon)
                .font(.headline)
                .foregroundStyle(AppTheme.heading)

            Divider()

            if command.type == "create_grade" {
                previewRow("Ученик", command.student_name, isMissing: command.student_id == nil)
                optionButtons(command.available_students, title: "Выберите ученика", action: onSelectStudent)

                previewRow("Класс", command.class_name, isMissing: command.class_id == nil)
                optionButtons(command.available_classes, title: "Выберите класс", action: onSelectClass)

                previewRow("Предмет", command.subject_name, isMissing: command.subject_id == nil)
                optionButtons(command.available_subjects, title: "Выберите предмет", action: onSelectSubject)

                previewRow("Оценка", command.grade_value, isMissing: isBlank(command.grade_value))
                stringOptionButtons(command.available_grade_values, title: "Выберите оценку", action: onSelectGradeValue)

                previewRow("Тип", command.gradeTypeTitle, isMissing: false)
                stringOptionButtons(command.available_grade_types, title: "Выберите тип оценки", action: onSelectGradeType)

                previewRow("Дата", command.formattedGradeDate, isMissing: isBlank(command.grade_date))
                previewRow("Комментарий", command.comment, isMissing: false)
            } else if command.type == "create_homework" {
                previewRow("Класс", command.class_name, isMissing: command.class_id == nil)
                optionButtons(command.available_classes, title: "Выберите класс", action: onSelectClass)

                previewRow("Предмет", command.subject_name, isMissing: command.subject_id == nil)
                optionButtons(command.available_subjects, title: "Выберите предмет", action: onSelectSubject)

                previewRow("Название", command.homework_title, isMissing: false)
                previewRow("Описание", command.homework_description, isMissing: isBlank(command.homework_description))
                previewRow("Срок", command.formattedDueDate, isMissing: isBlank(command.due_date))
            } else {
                previewRow("Тип команды", command.type, isMissing: false)
            }

            missingFieldsView

            if let message = command.message, !message.isEmpty {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(command.isReady ? AppTheme.success : AppTheme.warning)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(AppTheme.cardSoft.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(command.isReady ? AppTheme.success.opacity(0.35) : AppTheme.warning.opacity(0.45), lineWidth: 1)
        )
    }

    private var missingFieldsView: some View {
        let missing = command.missingFields()

        return VStack(alignment: .leading, spacing: 6) {
            if !missing.isEmpty {
                Text("Нужно уточнить:")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.warning)

                ForEach(missing) { field in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.warning)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(field.title)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(AppTheme.warning)

                            Text(field.hint)
                                .font(.caption2)
                                .foregroundStyle(AppTheme.muted)
                        }
                    }
                }
            }
        }
    }

    private var commandIcon: String {
        switch command.type {
        case "create_grade":
            return "star.circle.fill"
        case "create_homework":
            return "pencil.and.list.clipboard"
        default:
            return "questionmark.circle.fill"
        }
    }

    private func optionButtons(
        _ options: [AITeacherCommandOptionDTO]?,
        title: String,
        action: @escaping (AITeacherCommandOptionDTO) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let options, !options.isEmpty {
                Text(title)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.muted)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(options) { option in
                            Button {
                                action(option)
                            } label: {
                                Text(option.name)
                                    .font(.caption)
                                    .fontWeight(.bold)
                            }
                            .appChip()
                        }
                    }
                }
            }
        }
    }

    private func stringOptionButtons(
        _ options: [AITeacherCommandStringOptionDTO]?,
        title: String,
        action: @escaping (AITeacherCommandStringOptionDTO) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let options, !options.isEmpty {
                Text(title)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.muted)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(options) { option in
                            Button {
                                action(option)
                            } label: {
                                Text(option.name)
                                    .font(.caption)
                                    .fontWeight(.bold)
                            }
                            .appChip()
                        }
                    }
                }
            }
        }
    }

    private func previewRow(_ title: String, _ value: String?, isMissing: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            HStack(spacing: 4) {
                if isMissing {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.warning)
                }

                Text(title)
                    .font(.caption)
                    .foregroundStyle(isMissing ? AppTheme.warning : AppTheme.muted)
            }
            .frame(width: 106, alignment: .leading)

            Text(cleanValue(value))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(isMissing ? AppTheme.warning : AppTheme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func cleanValue(_ value: String?) -> String {
        guard let value else {
            return "Не определено"
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Не определено" : trimmed
    }

    private func isBlank(_ value: String?) -> Bool {
        guard let value else {
            return true
        }

        return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct AIChatMessageBubble: View {
    let message: AIChatMessage
    let onCopy: () -> Void
    let onRetry: () -> Void

    @State private var didCopy = false

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 40)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                HStack(spacing: 6) {
                    if message.role != .user {
                        Image(systemName: iconName)
                            .font(.caption)
                            .foregroundStyle(iconColor)
                    }

                    Text(senderTitle)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(AppTheme.muted)
                }

                Text(message.content)
                    .font(.body)
                    .foregroundStyle(textColor)
                    .textSelection(.enabled)
                    .padding(12)
                    .background(background)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(borderColor, lineWidth: 1)
                    )

                HStack(spacing: 12) {
                    Text(timeText(message.createdAt))
                        .font(.caption2)
                        .foregroundStyle(AppTheme.muted)

                    if message.role == .assistant && message.status == .sent {
                        Button {
                            onCopy()
                            didCopy = true

                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                                didCopy = false
                            }
                        } label: {
                            Label(didCopy ? "Скопировано" : "Скопировать", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                                .font(.caption2)
                        }
                        .appPlainListButton()
                    }

                    if message.status == .error {
                        Button {
                            onRetry()
                        } label: {
                            Label("Повторить", systemImage: "arrow.clockwise")
                                .font(.caption2)
                        }
                        .appPlainListButton()
                    }
                }
            }

            if message.role != .user {
                Spacer(minLength: 40)
            }
        }
    }

    private var senderTitle: String {
        switch message.role {
        case .user:
            return "Вы"
        case .assistant:
            return "ИИ-помощник"
        case .system:
            return "Система"
        }
    }

    private var iconName: String {
        switch message.role {
        case .assistant:
            return "sparkles"
        case .system:
            return "exclamationmark.triangle.fill"
        case .user:
            return "person.fill"
        }
    }

    private var iconColor: Color {
        switch message.role {
        case .assistant:
            return AppTheme.primaryDark
        case .system:
            return AppTheme.danger
        case .user:
            return AppTheme.control
        }
    }

    private var background: Color {
        switch message.role {
        case .user:
            return AppTheme.primaryDark
        case .assistant:
            return AppTheme.card
        case .system:
            return AppTheme.dangerSoft
        }
    }

    private var textColor: Color {
        switch message.role {
        case .user:
            return .white
        case .assistant:
            return AppTheme.text
        case .system:
            return AppTheme.danger
        }
    }

    private var borderColor: Color {
        switch message.role {
        case .user:
            return Color.white.opacity(0.22)
        case .assistant:
            return AppTheme.border.opacity(0.65)
        case .system:
            return AppTheme.danger.opacity(0.35)
        }
    }

    private func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date)
    }
}