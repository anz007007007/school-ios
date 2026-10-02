# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

iOS SwiftUI client ("Scapp", bundle `com.itstatus.sc`) for a school/kindergarten information platform backed by `https://sc.it-status.ru`. UI strings and user-facing error messages are in Russian. There is no test target.

## Build

Always open/build via the **workspace** (CocoaPods is used for Firebase):

```sh
pod install                      # after Podfile changes
xcodebuild -workspace scapp.xcworkspace -scheme Scapp \
  -destination 'generic/platform=iOS Simulator' build
```

- Pods: `Firebase/Core`, `Firebase/Messaging` (static frameworks). The Podfile `post_install` disables `ENABLE_USER_SCRIPT_SANDBOXING` — keep it, the Firebase build scripts fail otherwise.
- The `scapp/` folder is an Xcode **file-system synchronized group**: any `.swift` file dropped into it is compiled automatically; no pbxproj edits needed to add files.
- `GoogleService-Info.plist` and `scapp.entitlements` (push) live in `scapp/`.

## API layer (two parallel mechanisms)

1. **`SchoolAPIClient` local Swift package** in `SchoolAPIClient/` inside this repo (referenced by relative path from the xcodeproj). It contains an OpenAPI‑generated client (`swift-openapi-generator`, from `openapi.yaml`) plus a hand-written wrapper `SchoolAPI` (`Sources/SchoolAPIClient/SchoolAPIClient.swift`) that holds the bearer token and exposes a few typed calls (login, current user, etc.). Regenerate with:
   ```sh
   cd SchoolAPIClient
   rm -rf Sources/SchoolAPIClient/Generated
   swift-openapi-generator generate openapi.yaml --config generate-config.yaml \
     --output-directory ./Sources/SchoolAPIClient/Generated
   ```
   `API_see_not_for_project/` holds a reference copy of the generated code (not in the build). The generated code (~60k lines) lives only in the package: don't hand-edit them and don't read them in full; grep for the schema/operation you need. Feature code uses the package's types (`SchoolAPIClient.Components.Schemas…`).

2. **Hand-rolled REST calls** — the dominant pattern in feature code. Most features use `*DTO.swift` Codable structs (snake_case properties matching JSON) and build requests via `APIRequestService.shared.request/decode(api:path:method:...)`, while many ViewModels still carry their own private `URLSession` helper doing the same thing. Every request must:
   - take the token from `api.authToken` (the `SchoolAPI` instance lives in `AppState.api`, passed into ViewModel methods as `api:`),
   - call `request.applyMobileClientHeaders()` (`x-client-type: mobile`, `x-platform: ios`),
   - on missing token or HTTP 401 call `AuthSessionEvents.notifySessionExpired()` — `AppState` listens for this and logs the user out.
   Prefer `APIRequestService` for new code; `APIRequestError` provides Russian user-readable messages.

## App structure

- `scappApp` → `RootView` with `AppState` and `PushNotificationService.shared` injected as environment objects. The app is forced to light mode.
- **`AppState`** (`AppState.swift`) is the central store: auth/session restore, current user, role flags (`isAdmin/isTeacher/isStudent/isParent/isCook/isManager` from `role_code`), permission checks (`hasPermission`, `hasAnyPermission`, many `canXxx` computed properties — admin always passes), unread-notification counts per section, mobile-config feature flags, and push deep-link routing (`PushRoute`, `openPushRoute`). Gate new screens/actions through a `canXxx` property here rather than inline role checks.
- **`MainTabView`** builds the role/permission-dependent tab set (`MainTabSelection`) and reacts to `appState.pushRoute`.
- Features follow `XxxView` + `XxxViewModel` (`@MainActor final class … ObservableObject`, `@Published` state incl. `isLoading`, `errorMessage`, `successMessage`) + `XxxDTO`, with `XxxFormView` for create/edit sheets. `Admin*` files are the admin panel sections; `Teacher*` the teacher cabinet.
- Push: `AppDelegate` + `PushNotificationService` (Firebase Messaging); registration is re-ensured on launch, on becoming active, and after login.
- Styling: use `AppTheme` colors (`AppTheme.swift`, yellow/brown palette). `app.css` is the web frontend's palette kept for reference.
- Login lockout/remember-login lives in `LoginSecurityService` (UserDefaults). Consent toggles on the login screen start off on purpose (152-FZ).
- In Release `print` is a no-op (`ReleaseLogging.swift`), so debug prints never reach device logs.
