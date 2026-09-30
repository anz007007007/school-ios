import SwiftUI

struct SchoolMenuView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = SchoolMenuViewModel()

    @State private var selectedItem: WeeklyMenuItemDTO?
    @State private var editingItem: WeeklyMenuItemDTO?
    @State private var editingDish: MenuDishDTO?
    @State private var itemToDelete: WeeklyMenuItemDTO?

    @State private var isShowingCreateDish = false
    @State private var isShowingCreateMenuItem = false
    @State private var isShowingDishes = false
    @State private var isShowingDeleteConfirmation = false

    @State private var isSwitchingWeek = false
    @State private var selectedDayScrollTrigger = UUID()

    private let selectedDaySectionID = "selectedDaySectionID"

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    weekHeaderSection
                    filtersSection

                    if let successMessage = viewModel.successMessage {
                        Section {
                            Label(successMessage, systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }

                    weekGridSection
                    selectedDaySection
                        .id(selectedDaySectionID)
                }
                .appThemedList()
                .navigationTitle("Меню")
                .searchable(text: $viewModel.searchText, prompt: "Поиск блюда")
                .refreshable {
                    await viewModel.loadInitialData(api: appState.api)
                }
                .task {
                    if viewModel.weekItems.isEmpty && viewModel.dishes.isEmpty {
                        await viewModel.loadInitialData(api: appState.api)
                    }
                }
                .onChange(of: selectedDayScrollTrigger) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            proxy.scrollTo(selectedDaySectionID, anchor: .top)
                        }
                    }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        if appState.canManageMenu {
                            Menu {
                                Button {
                                    isShowingCreateMenuItem = true
                                } label: {
                                    Label("Добавить в меню", systemImage: "calendar.badge.plus")
                                }

                                Button {
                                    isShowingCreateDish = true
                                } label: {
                                    Label("Добавить блюдо", systemImage: "fork.knife")
                                }

                                Button {
                                    isShowingDishes = true
                                } label: {
                                    Label("Справочник блюд", systemImage: "list.bullet")
                                }
                            } label: {
                                Image(systemName: "plus")
                            }
                        }

                        Button {
                            Task {
                                await viewModel.loadInitialData(api: appState.api)
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .sheet(isPresented: $isShowingCreateDish) {
                MenuDishFormView(
                    mode: .create,
                    dish: nil,
                    isSaving: viewModel.isSaving,
                    errorMessage: viewModel.errorMessage,
                    onSave: { formData in
                        let safeFormData = MenuDishFormData(
                            name: String(formData.name),
                            description: String(formData.description),
                            calories: formData.calories,
                            allergens: String(formData.allergens),
                            priceAmount: String(formData.priceAmount)
                        )

                        Task { @MainActor in
                            _ = await viewModel.createDish(
                                api: appState.api,
                                formData: safeFormData
                            )
                        }
                    }
                )
            }
            .sheet(item: $editingDish) { dish in
                MenuDishFormView(
                    mode: .edit,
                    dish: dish,
                    isSaving: viewModel.isSaving,
                    errorMessage: viewModel.errorMessage,
                    onSave: { formData in
                        let safeFormData = MenuDishFormData(
                            name: String(formData.name),
                            description: String(formData.description),
                            calories: formData.calories,
                            allergens: String(formData.allergens),
                            priceAmount: String(formData.priceAmount)
                        )

                        Task { @MainActor in
                            _ = await viewModel.updateDish(
                                api: appState.api,
                                dishID: dish.id,
                                formData: safeFormData
                            )
                        }
                    }
                )
            }
            .sheet(isPresented: $isShowingCreateMenuItem) {
                WeeklyMenuItemFormView(
                    mode: .create,
                    item: nil,
                    initialDate: viewModel.selectedDate,
                    dishes: viewModel.dishes,
                    mealTypes: viewModel.orderedMealTypes,
                    classes: viewModel.classes,
                    isSaving: viewModel.isSaving,
                    errorMessage: viewModel.errorMessage,
                    onSave: { formData in
                        let safeFormData = WeeklyMenuItemFormData(
                            menuDate: String(formData.menuDate),
                            mealType: String(formData.mealType),
                            dishID: formData.dishID,
                            classID: formData.classID
                        )

                        Task { @MainActor in
                            _ = await viewModel.createWeeklyMenuItem(
                                api: appState.api,
                                formData: safeFormData
                            )
                        }
                    }
                )
            }
            .sheet(item: $editingItem) { item in
                WeeklyMenuItemFormView(
                    mode: .edit,
                    item: item,
                    initialDate: item.menu_date,
                    dishes: viewModel.dishes,
                    mealTypes: viewModel.orderedMealTypes,
                    classes: viewModel.classes,
                    isSaving: viewModel.isSaving,
                    errorMessage: viewModel.errorMessage,
                    onSave: { formData in
                        let safeFormData = WeeklyMenuItemFormData(
                            menuDate: String(formData.menuDate),
                            mealType: String(formData.mealType),
                            dishID: formData.dishID,
                            classID: formData.classID
                        )

                        Task { @MainActor in
                            _ = await viewModel.updateWeeklyMenuItem(
                                api: appState.api,
                                itemID: item.id,
                                formData: safeFormData
                            )
                        }
                    }
                )
            }
            .sheet(isPresented: $isShowingDishes) {
                dishesSheet
            }
            .confirmationDialog(
                "Удалить пункт меню?",
                isPresented: $isShowingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Удалить", role: .destructive) {
                    guard let itemToDelete else {
                        return
                    }

                    Task {
                        _ = await viewModel.deleteWeeklyMenuItem(
                            api: appState.api,
                            item: itemToDelete
                        )

                        self.itemToDelete = nil
                    }
                }

                Button("Отмена", role: .cancel) {
                    itemToDelete = nil
                }
            } message: {
                if let itemToDelete {
                    Text("Блюдо «\(itemToDelete.dish_name)» будет удалено из меню.")
                }
            }
        }
    }

    private var weekHeaderSection: some View {
        Section {
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    Button {
                        switchWeek {
                            await viewModel.goToPreviousWeek(api: appState.api)
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .disabled(isSwitchingWeek || viewModel.isLoading)

                    Spacer()

                    VStack(spacing: 4) {
                        Text(viewModel.weekRangeTitle())
                            .font(.headline)
                            .multilineTextAlignment(.center)

                        if isSwitchingWeek || viewModel.isLoading {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Неделя")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    Spacer()

                    Button {
                        switchWeek {
                            await viewModel.goToNextWeek(api: appState.api)
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.headline)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .disabled(isSwitchingWeek || viewModel.isLoading)
                }

                Button {
                    switchWeek {
                        await viewModel.goToCurrentWeek(api: appState.api)
                    }
                } label: {
                    Label("Текущая неделя", systemImage: "calendar")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .disabled(isSwitchingWeek || viewModel.isLoading)
            }
            .padding(.vertical, 4)
        }
    }

    private func switchWeek(_ action: @escaping () async -> Void) {
        guard !isSwitchingWeek else {
            return
        }

        isSwitchingWeek = true

        Task {
            await action()
            isSwitchingWeek = false
            selectedDayScrollTrigger = UUID()
        }
    }

    private var filtersSection: some View {
        Section("Фильтры") {
            if viewModel.isLoadingFilters {
                HStack {
                    Spacer()
                    ProgressView("Загрузка фильтров...")
                    Spacer()
                }
            }

            if !viewModel.classes.isEmpty {
                Picker("Класс", selection: $viewModel.selectedClassID) {
                    Text("Все классы").tag(0)

                    ForEach(viewModel.classes) { item in
                        Text(item.name).tag(item.id)
                    }
                }
                .onChange(of: viewModel.selectedClassID) {
                    Task {
                        await viewModel.reload(api: appState.api)
                    }
                }
            }

            Picker("Приём пищи", selection: $viewModel.selectedMealType) {
                Text("Все").tag("all")

                ForEach(viewModel.orderedMealTypes) { item in
                    Text(item.name).tag(item.code)
                }
            }
            .onChange(of: viewModel.selectedMealType) {
                Task {
                    await viewModel.reload(api: appState.api)
                }
            }
        }
    }

    private var weekGridSection: some View {
        Section("Неделя") {
            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ],
                spacing: 12
            ) {
                ForEach(viewModel.weekDays) { day in
                    Button {
                        viewModel.selectedDate = day.dateString
                        selectedDayScrollTrigger = UUID()
                    } label: {
                        MenuDayCardView(
                            day: day,
                            isSelected: viewModel.selectedDate == day.dateString,
                            canManage: appState.canManageMenu
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    private var selectedDaySection: some View {
        Section(viewModel.selectedDate.isEmpty ? "День" : viewModel.dayTitle(viewModel.selectedDate)) {
            if viewModel.isLoading {
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
                            await viewModel.loadInitialData(api: appState.api)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.vertical)
            } else if viewModel.selectedDayItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "fork.knife.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)

                    Text("Меню не заполнено")
                        .font(.headline)

                    Text("На выбранный день блюда не добавлены.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    if appState.canManageMenu {
                        Button {
                            isShowingCreateMenuItem = true
                        } label: {
                            Label("Добавить блюдо", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            } else {
                ForEach(viewModel.selectedDayMealGroups) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "fork.knife")
                                .foregroundStyle(.blue)

                            Text(group.title)
                                .font(.headline)
                                .foregroundStyle(.blue)

                            Spacer()

                            Text("\(group.items.count)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.blue.opacity(0.12))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                        .padding(.top, 4)

                        ForEach(group.items) { item in
                            MenuItemRowView(item: item)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    if appState.canManageMenu {
                                        Button(role: .destructive) {
                                            itemToDelete = item
                                            isShowingDeleteConfirmation = true
                                        } label: {
                                            Label("Удалить", systemImage: "trash")
                                        }

                                        Button {
                                            editingItem = item
                                        } label: {
                                            Label("Изменить", systemImage: "pencil")
                                        }
                                        .tint(.blue)
                                    }
                                }

                            if item.id != group.items.last?.id {
                                Divider()
                                    .padding(.leading, 12)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                if appState.canManageMenu {
                    Button {
                        isShowingCreateMenuItem = true
                    } label: {
                        Label("Добавить блюдо", systemImage: "plus")
                    }
                }
            }
        }
    }

    private var dishesSheet: some View {
        NavigationStack {
            List {
                if viewModel.filteredDishes.isEmpty {
                    ContentUnavailableView(
                        "Блюд нет",
                        systemImage: "fork.knife",
                        description: Text("Добавьте блюда в справочник.")
                    )
                } else {
                    ForEach(viewModel.filteredDishes) { dish in
                        Button {
                            editingDish = dish
                            isShowingDishes = false
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(dish.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                if let description = dish.description, !description.isEmpty {
                                    Text(description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                HStack {
                                    if let calories = dish.calories {
                                        Label("\(calories) ккал", systemImage: "flame.fill")
                                    }

                                    if let price = dish.price_amount, !price.isEmpty {
                                        Label(price, systemImage: "creditcard.fill")
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .appThemedList()
            .navigationTitle("Блюда")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        isShowingDishes = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        isShowingDishes = false

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            isShowingCreateDish = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

struct MenuDayCardView: View {
    let day: SchoolMenuViewModel.MenuDay
    let isSelected: Bool
    let canManage: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(day.title.uppercased())
                        .font(.caption)
                        .fontWeight(.bold)

                    Text(day.subtitle)
                        .font(.headline)
                }

                Spacer()

                Text("\(day.items.count)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(8)
                    .background(isSelected ? .white.opacity(0.25) : .blue.opacity(0.12))
                    .clipShape(Circle())
            }

            if day.items.isEmpty {
                Text("Нет блюд")
                    .font(.caption)
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(day.items.prefix(3)) { item in
                        Text(item.dish_name)
                            .font(.caption)
                            .lineLimit(1)
                    }

                    if day.items.count > 3 {
                        Text("+ ещё \(day.items.count - 3)")
                            .font(.caption2)
                            .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                    }
                }
            }

            Label("Показать меню", systemImage: "arrow.down.circle.fill")
                .font(.caption2)
                .foregroundStyle(isSelected ? .white.opacity(0.9) : .blue)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        .padding()
        .background {
            if isSelected {
                Color.blue
            } else {
                Color.secondary.opacity(0.12)
            }
        }
        .foregroundStyle(isSelected ? .white : .primary)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

struct MenuItemRowView: View {
    let item: WeeklyMenuItemDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.dish_name)
                        .font(.headline)

                    if let description = item.dish_description, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    if let calories = item.calories {
                        Text("\(calories) ккал")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    if let price = item.price_amount, !price.isEmpty {
                        Text(price)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack {
                if let className = item.class_name, !className.isEmpty {
                    Label(className, systemImage: "person.3.fill")
                } else {
                    Label("Все классы", systemImage: "person.3.fill")
                }

                if let allergens = item.allergens, !allergens.isEmpty {
                    Label(allergens, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}