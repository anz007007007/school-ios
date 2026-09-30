import SwiftUI

struct MenuDishFormView: View {
    enum Mode {
        case create
        case edit

        var title: String {
            switch self {
            case .create:
                return "Новое блюдо"
            case .edit:
                return "Редактирование блюда"
            }
        }

        var saveButtonTitle: String {
            switch self {
            case .create:
                return "Добавить"
            case .edit:
                return "Сохранить"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss

    let mode: Mode
    let dish: MenuDishDTO?
    let isSaving: Bool
    let errorMessage: String?
    let onSave: (MenuDishFormData) -> Void

    @State private var name: String
    @State private var description: String
    @State private var caloriesText: String
    @State private var allergens: String
    @State private var priceAmount: String
    @State private var validationMessage: String?

    init(
        mode: Mode,
        dish: MenuDishDTO?,
        isSaving: Bool,
        errorMessage: String?,
        onSave: @escaping (MenuDishFormData) -> Void
    ) {
        self.mode = mode
        self.dish = dish
        self.isSaving = isSaving
        self.errorMessage = errorMessage
        self.onSave = onSave

        _name = State(initialValue: dish?.name ?? "")
        _description = State(initialValue: dish?.description ?? "")
        _caloriesText = State(initialValue: dish?.calories.map { "\($0)" } ?? "")
        _allergens = State(initialValue: dish?.allergens ?? "")
        _priceAmount = State(initialValue: dish?.price_amount ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Основное") {
                    TextField("Название", text: $name)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Описание")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextEditor(text: $description)
                            .frame(minHeight: 100)
                    }
                }

                Section("Пищевая ценность") {
                    TextField("Калории", text: $caloriesText)
                        .keyboardType(.numberPad)

                    TextField("Аллергены", text: $allergens)
                }

                Section("Стоимость") {
                    TextField("Цена", text: $priceAmount)
                        .keyboardType(.decimalPad)
                }

                if let validationMessage {
                    Section {
                        Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }

                if let errorMessage {
                    Section {
                        Label("Ошибка сохранения", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)

                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text(mode.saveButtonTitle)
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private func save() {
        validationMessage = nil

        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanName.isEmpty else {
            validationMessage = "Введите название блюда"
            return
        }

        let calories = Int(caloriesText.trimmingCharacters(in: .whitespacesAndNewlines))

        let formData = MenuDishFormData(
            name: cleanName,
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            calories: calories,
            allergens: allergens.trimmingCharacters(in: .whitespacesAndNewlines),
            priceAmount: priceAmount.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        onSave(formData)
        dismiss()
    }
}