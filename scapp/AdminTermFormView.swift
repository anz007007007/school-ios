import SwiftUI

struct AdminTermFormData {
    var name: String = ""
    var academicYear: String = AdminDateInput.currentAcademicYear
    var termType: String = "quarter"
    /// Даты в форме — `дд.мм.гггг`; в ISO переводятся при сохранении.
    var startsAt: String = ""
    var endsAt: String = ""
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

            Picker("Тип периода", selection: $formData.termType) {
                Text("Четверть").tag("quarter")
                Text("Триместр").tag("trimester")
                Text("Семестр").tag("semester")
                Text("Год").tag("year")
            }

            Toggle("Активен", isOn: $formData.isActive)
        }

        Section("Даты") {
            TextField("Дата начала, например 01.09.2026", text: $formData.startsAt)
                .keyboardType(.numbersAndPunctuation)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            TextField("Дата окончания, например 31.10.2026", text: $formData.endsAt)
                .keyboardType(.numbersAndPunctuation)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }

        Section {
            Text("Даты вводятся в формате ДД.ММ.ГГГГ.")
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
