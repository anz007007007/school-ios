import SwiftUI

struct AdminTermFormData {
    var name: String = ""
    var academicYear: String = "2025-2026"
    var termType: String = "quarter"
    var startsAt: String = "2025-09-01"
    var endsAt: String = "2025-10-31"
    var isActive: Bool = true
}

struct AdminTermFormFieldsView: View {
    @Binding var formData: AdminTermFormData

    var body: some View {
        Section("Период") {
            TextField("Название", text: $formData.name)

            TextField("Учебный год", text: $formData.academicYear)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Picker("Тип", selection: $formData.termType) {
                Text("Четверть").tag("quarter")
                Text("Триместр").tag("trimester")
                Text("Семестр").tag("semester")
                Text("Год").tag("year")
            }

            Toggle("Активен", isOn: $formData.isActive)
        }

        Section("Даты") {
            TextField("Дата начала, например 2025-09-01", text: $formData.startsAt)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            TextField("Дата окончания, например 2025-10-31", text: $formData.endsAt)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }

        Section {
            Text("Формат дат должен быть YYYY-MM-DD.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

struct AdminTermFormView: View {
    @Binding var formData: AdminTermFormData

    var body: some View {
        Form {
            AdminTermFormFieldsView(formData: $formData)
        }
    }
}
