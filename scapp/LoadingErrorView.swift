import SwiftUI

struct LoadingErrorView<Content: View>: View {
    let isLoading: Bool
    let errorMessage: String?
    let retryTitle: String
    let onRetry: (() -> Void)?
    let content: () -> Content

    init(
        isLoading: Bool,
        errorMessage: String?,
        retryTitle: String = "Повторить",
        onRetry: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.retryTitle = retryTitle
        self.onRetry = onRetry
        self.content = content
    }

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Загрузка...")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.orange)

                    Text("Ошибка")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    if let onRetry {
                        Button(retryTitle) {
                            onRetry()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                content()
            }
        }
    }
}
