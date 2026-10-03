import SwiftUI

struct WeeklyMenuItemFormView: View {
    enum Mode {
        case create
        case edit

        var title: String {
            switch self {
            case .create:
                return "Добавить в меню"
            case .edit:
                return "Редактировать меню"
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
    @EnvironmentObject var appState: AppState

    let mode: Mode
    let item: WeeklyMenuItemDTO?
    let initialDate: String
    let dishes: [MenuDishDTO]
    let mealTypes: [MealTypeDTO]
    let classes: [MenuClassFilterDTO]
    let isSaving: Bool
    let errorMessage: String?
    let onSave: (WeeklyMenuItemFormData) -> Void

    @State private var menuDate: String
    @State private var mealType: String
    @State private var dishID: Int
    @State private var classID: Int
    @State private var validationMessage: String?
    @State private var divisionAudience: DivisionAudience

    init(
        mode: Mode,
        item: WeeklyMenuItemDTO?,
        initialDate: String,
        dishes: [MenuDishDTO],
        mealTypes: [MealTypeDTO],
        classes: [MenuClassFilterDTO],
        isSaving: Bool,
        errorMessage: String?,
        onSave: @escaping (WeeklyMenuItemFormData) -> Void
    ) {
        self.mode = mode
        self.item = item
        self.initialDate = initialDate
        self.dishes = dishes
        self.mealTypes = mealTypes
        self.classes = classes
        self.isSaving = isSaving
        self.errorMessage = errorMessage
        self.onSave = onSave

        _menuDate = State(initialValue: item?.menu_date ?? initialDate)
        _mealType = State(initialValue: item?.meal_type ?? mealTypes.first?.code ?? "breakfast")
        _dishID = State(initialValue: item?.dish_id ?? dishes.first?.id ?? 0)
        _classID = State(initialValue: item?.class_id ?? 0)
        _divisionAudience = State(initialValue: DivisionAudience(divisionIDs: item?.division_ids))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Когда") {
                    TextField("Дата", text: $menuDate)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Picker("Приём пищи", selection: $mealType) {
                        ForEach(mealTypes) { type in
                            Text(type.name).tag(type.code)
                        }
                    }
                }

                Section("Блюдо") {
                    if dishes.isEmpty {
                        Text("Сначала добавьте блюдо в справочник.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Блюдо", selection: $dishID) {
                            Text("Выберите блюдо").tag(0)

                            ForEach(dishes) { dish in
                                Text(dish.name).tag(dish.id)
                            }
                        }
                    }
                }

                Section("Класс") {
                    Picker("Класс", selection: $classID) {
                        Text("Для всех классов").tag(0)

                        ForEach(classes) { item in
                            Text(item.name).tag(item.id)
                        }
                    }
                }

                // Подразделения — только у общих позиций; позиция класса видна по правилам класса.
                if classID == 0 {
                    DivisionAudienceSection(audience: $divisionAudience)
                }

                if let selectedDish {
                    Section("Информация о блюде") {
                        LabeledContent("Название", value: selectedDish.name)

                        if let calories = selectedDish.calories {
                            LabeledContent("Калории", value: "\(calories)")
                        }

                        if let allergens = selectedDish.allergens, !allergens.isEmpty {
                            LabeledContent("Аллергены", value: allergens)
                        }

                        if let price = selectedDish.price_amount, !price.isEmpty {
                            LabeledContent("Цена", value: price)
                        }
                    }
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
            .loadsDivisionAudience()
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

    private var selectedDish: MenuDishDTO? {
        dishes.first { $0.id == dishID }
    }

    private func save() {
        validationMessage = nil

        guard !menuDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            validationMessage = "Укажите дату"
            return
        }

        guard dishID != 0 else {
            validationMessage = "Выберите блюдо"
            return
        }

        let formData = WeeklyMenuItemFormData(
            menuDate: menuDate.trimmingCharacters(in: .whitespacesAndNewlines),
            mealType: mealType,
            dishID: dishID,
            classID: classID == 0 ? nil : classID,
            divisionIDs: classID == 0 ? divisionAudience.payload(appState: appState) : nil
        )

        onSave(formData)
        dismiss()
    }
}