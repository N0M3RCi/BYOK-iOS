import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink(destination: GeneralSettingsView(viewModel: viewModel)) { Label("General", systemImage: "gear") }
                    NavigationLink(destination: ModelSettingsView(viewModel: viewModel)) { Label("Models", systemImage: "cpu") }
                    NavigationLink(destination: APISettingsView(viewModel: viewModel)) { Label("API", systemImage: "antenna.radiowaves.left.and.right") }
                    NavigationLink(destination: PrivacySettingsView()) { Label("Privacy", systemImage: "hand.raised") }
                    if authViewModel.user?.role == .admin { NavigationLink(destination: StudentSettingsView()) { Label("Students", systemImage: "person.2") } }
                }
                Section("Account") {
                    if let email = authViewModel.user?.email ?? KeychainManager.shared.getEmail() { LabeledContent("Email", value: email) }
                    Button(role: .destructive) { authViewModel.logout() } label: { Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right").foregroundColor(.red) }
                }
                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    HStack { Text("Connection"); Spacer(); Circle().fill(viewModel.isConnected ? Color.green : Color.red).frame(width: 8, height: 8) }
                }
            }
            .navigationTitle("Settings")
            .onAppear { viewModel.checkConnection() }
        }
    }
}

// MARK: - General
struct GeneralSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedLanguage: AppLanguage

    init(viewModel: SettingsViewModel) { self.viewModel = viewModel; _selectedLanguage = State(initialValue: LocalizationManager.shared.currentLanguage) }

    var body: some View {
        Form {
            Section("Language") {
                Picker("Language", selection: $selectedLanguage) { ForEach(AppLanguage.allCases, id: \.self) { Text($0.displayName).tag($0) } }
                    .onChange(of: selectedLanguage) { LocalizationManager.shared.currentLanguage = $0 }
            }
            Section("Theme") {
                Picker("Theme", selection: $themeManager.currentTheme) { ForEach(AppTheme.allCases, id: \.self) { Text($0.displayName).tag($0) } }
            }
            Section("Font Size") { Slider(value: $viewModel.fontSize, in: 12...24, step: 1); Text("Preview: The quick brown fox").font(.system(size: viewModel.fontSize)).foregroundColor(.secondary) }
        }.navigationTitle("General")
    }
}

// MARK: - Model Settings
struct ModelSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var showingAddProvider = false

    var body: some View {
        List {
            Section("Providers") { ForEach(viewModel.providers) { provider in VStack(alignment: .leading) { Text(provider.name).fontWeight(.medium); Text(provider.platform).font(.caption).foregroundColor(.secondary) } } }
            Section { Button(action: { showingAddProvider = true }) { Label("Add Provider", systemImage: "plus") }; NavigationLink(destination: ModelValidationView(viewModel: viewModel)) { Label("Test Model", systemImage: "checkmark.circle") } }
        }
        .navigationTitle("Models")
        .sheet(isPresented: $showingAddProvider) { AddProviderView(viewModel: viewModel) }
        .onAppear { viewModel.loadProviders() }
    }
}

struct AddProviderView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) var dismiss
    @State private var platform = "OPENAI"; @State private var apiKey = ""; @State private var apiUrl = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Platform") { Picker("Platform", selection: $platform) { ForEach(ModelPlatform.allCases, id: \.self) { Text($0.displayName).tag($0.rawValue) } } }
                Section("Credentials") { SecureField("API Key", text: $apiKey); TextField("API URL (optional)", text: $apiUrl) }
            }
            .navigationTitle("Add Provider")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { await viewModel.addProvider(platform: platform, apiKey: apiKey, apiUrl: apiUrl.isEmpty ? nil : apiUrl); dismiss() } }.disabled(apiKey.isEmpty) }
            }
        }
    }
}

struct ModelValidationView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var platform = "OPENAI"; @State private var modelType = "GPT_4O_MINI"; @State private var apiKey = ""; @State private var result: ModelValidationResult?

    var body: some View {
        Form {
            Section("Configuration") { Picker("Platform", selection: $platform) { ForEach(ModelPlatform.allCases, id: \.self) { Text($0.displayName).tag($0.rawValue) } }; Picker("Model", selection: $modelType) { ForEach(ModelType.allCases, id: \.self) { Text($0.displayName).tag($0.rawValue) } }; SecureField("API Key", text: $apiKey) }
            Section { Button("Test Model") { Task { result = await viewModel.validateModel(platform: platform, modelType: modelType, apiKey: apiKey) } }.disabled(apiKey.isEmpty) }
            if let r = result { Section("Result") { LabeledContent("Valid", value: r.isValid ? "Yes" : "No"); if let e = r.error { Text(e).foregroundColor(.red) } } }
        }.navigationTitle("Test Model")
    }
}

// MARK: - API Settings
struct APISettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var endpointURL: String
    init(viewModel: SettingsViewModel) { self.viewModel = viewModel; _endpointURL = State(initialValue: UserDefaults.standard.string(forKey: "brain_endpoint") ?? "https://class.n0m3rci.cc") }

    var body: some View {
        Form {
            Section("Brain Endpoint") { TextField("URL", text: $endpointURL).keyboardType(.URL).autocapitalization(.none).disableAutocorrection(true) }
            Section {
                Button("Check Connection") { endpointURL = viewModel.brainEndpoint; viewModel.checkConnection() }
                HStack { Text("Status"); Spacer(); Circle().fill(viewModel.isConnected ? Color.green : Color.red).frame(width: 8, height: 8); Text(viewModel.isConnected ? "Connected" : "Disconnected").foregroundColor(viewModel.isConnected ? .green : .red) }
            }
            Section { Button("Save") { viewModel.brainEndpoint = endpointURL; viewModel.saveConfig() } }
        }.navigationTitle("API")
    }
}

// MARK: - Privacy
struct PrivacySettingsView: View {
    @State private var biometricEnabled = UserDefaults.standard.bool(forKey: "biometric_enabled")
    var body: some View {
        Form {
            Section("Security") { Toggle("Use Biometrics", isOn: $biometricEnabled).onChange(of: biometricEnabled) { UserDefaults.standard.set($0, forKey: "biometric_enabled") } }
            Section("Data") { Button("Export Data") {}.foregroundColor(.primary) }
            Section { Link("Privacy Policy", destination: URL(string: "https://n0m3rci.cc/privacy")!); Link("Terms of Service", destination: URL(string: "https://n0m3rci.cc/terms")!) }
        }.navigationTitle("Privacy")
    }
}

struct StudentSettingsView: View { var body: some View { AdminUsersView() } }

#Preview { SettingsView().environmentObject(AuthViewModel()).environmentObject(ThemeManager()) }