import SwiftUI

struct AccountView: View {
    @EnvironmentObject private var account: Account
    @Environment(\.dismiss) private var dismiss
    @State private var projectKey = ""
    @State private var email = ""
    @State private var password = ""
    @State private var creating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Account")
                    .font(.harold(size: 26, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button("Close", systemImage: "xmark") { dismiss() }
                    .labelStyle(.iconOnly)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 32, height: 32)
                    .buttonStyle(HoverButtonStyle(fill: Palette.panel, radius: 16))
                    .keyboardShortcut(.cancelAction)
            }

            if let user = account.user {
                VStack(alignment: .leading, spacing: 4) {
                    SmallLabel(text: "Signed in as")
                    Text(user.email).font(.harold(size: 16, weight: .bold))
                        .textSelection(.enabled)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .modifier(Surface(radius: 16))
                primary("Sign out", disabled: account.busy, action: account.signOut)
            } else if account.apiKey.isEmpty {
                Text("Connect your Firebase project to enable email sign-in.")
                    .font(.harold(size: 14))
                    .foregroundStyle(Palette.secondary)
                field("Firebase Web API key") {
                    TextField("Firebase Web API key", text: $projectKey)
                }
                primary("Connect Firebase", disabled: projectKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                    account.configure(projectKey)
                    if !account.apiKey.isEmpty { projectKey = "" }
                }
                Link("Open Firebase Console", destination: URL(string: "https://console.firebase.google.com/")!)
                    .font(.harold(size: 13, weight: .bold))
                    .foregroundStyle(Palette.teal)
            } else {
                Text(creating ? "Create your Harold account" : "Sign in to Harold")
                    .font(.harold(size: 16, weight: .bold))
                field("Email") {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                }
                field("Password") {
                    SecureField("Password", text: $password)
                        .textContentType(creating ? .newPassword : .password)
                }
                primary(creating ? "Create account" : "Sign in",
                        disabled: account.busy || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty) {
                    Task {
                        await account.authenticate(email: email, password: password, creating: creating)
                        if account.user != nil { password = "" }
                    }
                }
                HStack {
                    Button(creating ? "Use an existing account" : "Create account") {
                        creating.toggle()
                        password = ""
                        account.clearMessage()
                    }
                    if !creating {
                        Spacer()
                        Button("Reset password") { Task { await account.reset(email: email) } }
                            .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(Palette.teal)
                .font(.harold(size: 13, weight: .bold))
                .disabled(account.busy)
                Button("Change Firebase project", action: account.disconnect)
                    .buttonStyle(.plain)
                    .foregroundStyle(Palette.muted)
                    .font(.harold(size: 12, weight: .medium))
                    .disabled(account.busy)
            }

            if account.busy { ProgressView().controlSize(.small) }
            if let error = account.error {
                Text(error).font(.harold(size: 13)).foregroundStyle(Palette.amber)
            }
            if let notice = account.notice {
                Text(notice).font(.harold(size: 13)).foregroundStyle(Palette.teal)
            }
        }
        .padding(24)
        .frame(width: 440)
        .foregroundStyle(Palette.text)
        .background(Palette.background)
    }

    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.harold(size: 13, weight: .bold))
            content()
                .textFieldStyle(.plain)
                .font(.harold(size: 14))
                .padding(10)
                .modifier(Surface(radius: 12))
                .disabled(account.busy)
        }
    }

    private func primary(_ title: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.harold(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
        }
        .buttonStyle(HoverButtonStyle(fill: Palette.accent, hover: .white.opacity(0.12), radius: 20))
        .keyboardShortcut(.defaultAction)
        .disabled(disabled)
        .opacity(disabled ? 0.54 : 1)
    }
}
