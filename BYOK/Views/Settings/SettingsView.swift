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
            Section("Providers") {
                if viewModel.providers.isEmpty {
                    Text("No providers added yet").foregroundColor(.secondary)
                }
                ForEach(viewModel.providers) { provider in
                    NavigationLink(destination: ProviderDetailView(viewModel: viewModel, provider: provider)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(provider.name).fontWeight(.medium)
                            Text(provider.platform).font(.caption).foregroundColor(.secondary)
                            if let apiUrl = provider.apiUrl, !apiUrl.isEmpty {
                                Text(apiUrl).font(.caption2).foregroundColor(.gray)
                            }
                            HStack(spacing: 4) {
                                Circle().fill(provider.isActive ? Color.green : Color.gray).frame(width: 6, height: 6)
                                Text(provider.isActive ? "Active" : "Inactive").font(.caption2).foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .onDelete { viewModel.deleteProvider(at: $0) }
            }
            Section {
                Button(action: { showingAddProvider = true }) { Label("Add Provider", systemImage: "plus") }
                NavigationLink(destination: ModelValidationView(viewModel: viewModel)) { Label("Test Model", systemImage: "checkmark.circle") }
            }
        }
        .navigationTitle("Models")
        .sheet(isPresented: $showingAddProvider) { AddProviderView(viewModel: viewModel) }
        .onAppear { viewModel.loadProviders() }
    }
}

// MARK: - Provider Detail
struct ProviderDetailView: View {
    @ObservedObject var viewModel: SettingsViewModel
    let provider: Provider
    @State private var models: [ProviderModel] = []
    @State private var isLoadingModels = false
    @State private var selectedModel: String?
    @State private var modelError: String?

    var body: some View {
        Form {
            Section("Provider Info") {
                LabeledContent("Name", value: provider.name)
                LabeledContent("Platform", value: provider.platform)
                if let apiUrl = provider.apiUrl, !apiUrl.isEmpty {
                    LabeledContent("API URL", value: apiUrl)
                }
                LabeledContent("Status", value: provider.isActive ? "Active" : "Inactive")
            }

            Section("Available Models") {
                if models.isEmpty {
                    Text("No models fetched yet").foregroundColor(.secondary)
                }
                ForEach(models) { model in
                    Button(action: {
                        selectedModel = model.id
                        viewModel.setActiveModel(providerId: provider.id, modelType: model.id)
                    }) {
                        HStack {
                            Text(model.name)
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedModel == model.id || viewModel.selectedModel == model.id {
                                Image(systemName: "checkmark").foregroundColor(.blue)
                            }
                        }
                    }
                }
                if isLoadingModels {
                    HStack { Spacer(); ProgressView(); Spacer() }
                }
                if let error = modelError {
                    Text(error).foregroundColor(.red).font(.caption)
                }
            }

            Section {
                Button(action: { fetchModels() }) {
                    Label("Fetch Models", systemImage: "arrow.down.circle")
                }
                .disabled(isLoadingModels)

                Button(action: { testProvider() }) {
                    Label("Test Connection", systemImage: "bolt.fill")
                }
                .disabled(isLoadingModels)
            }
        }
        .navigationTitle(provider.name)
        .onAppear { fetchModels() }
    }

    private func fetchModels() {
        guard let apiKey = provider.apiKey else { return }
        isLoadingModels = true
        modelError = nil
        Task {
            await viewModel.fetchProviderModels(
                platform: provider.platform,
                apiKey: apiKey,
                apiUrl: provider.apiUrl
            )
            models = viewModel.availableModels
            isLoadingModels = false
        }
    }

    private func testProvider() {
        guard let apiKey = provider.apiKey else { return }
        modelError = nil
        Task {
            let success = await viewModel.testProviderConnection(
                platform: provider.platform,
                apiKey: apiKey,
                apiUrl: provider.apiUrl
            )
            if success {
                modelError = "Connection successful"
            } else {
                modelError = viewModel.testResult ?? "Connection failed"
            }
        }
    }
}

// MARK: - Add Provider
struct AddProviderView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) var dismiss
    @State private var platform = "OPENAI"
    @State private var apiKey = ""
    @State private var apiUrl = ""
    @State private var connectionTested = false
    @State private var connectionSuccess = false
    @State private var modelsFetched = false
    @State private var selectedModelId: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Platform") {
                    Picker("Platform", selection: $platform) {
                        ForEach(ModelPlatform.allCases, id: \.self) { Text($0.displayName).tag($0.rawValue) }
                    }
                }

                Section("Credentials") {
                    SecureField("API Key", text: $apiKey)
                    TextField("API URL (optional)", text: $apiUrl)
                        .keyboardType(.URL).autocapitalization(.none).disableAutocorrection(true)
                }

                // Step 1: Test Connection
                Section {
                    Button(action: testConnection) {
                        HStack {
                            if viewModel.isTesting {
                                ProgressView().scaleEffect(0.8)
                            }
                            Text(connectionTested ? "Retest Connection" : "Test Connection")
                        }
                    }
                    .disabled(apiKey.isEmpty || viewModel.isTesting)

                    if let result = viewModel.testResult {
                        HStack {
                            Image(systemName: connectionSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(connectionSuccess ? .green : .red)
                            Text(result).font(.caption).foregroundColor(connectionSuccess ? .green : .red)
                        }
                    }
                }

                // Step 2: Fetch Models (only after successful connection test)
                if connectionSuccess {
                    Section {
                        Button(action: fetchModels) {
                            HStack {
                                if viewModel.isFetchingModels {
                                    ProgressView().scaleEffect(0.8)
                                }
                                Text(modelsFetched ? "Refresh Models" : "Fetch Models")
                            }
                        }
                        .disabled(viewModel.isFetchingModels)
                    }

                    if !viewModel.availableModels.isEmpty {
                        Section("Select Model") {
                            ForEach(viewModel.availableModels) { model in
                                Button(action: { selectedModelId = model.id }) {
                                    HStack {
                                        Text(model.name).foregroundColor(.primary)
                                        Spacer()
                                        if selectedModelId == model.id {
                                            Image(systemName: "checkmark.circle.fill").foregroundColor(.blue)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if let error = viewModel.errorMessage, !viewModel.availableModels.isEmpty {
                        Section { Text(error).foregroundColor(.red).font(.caption) }
                    }
                }
            }
            .navigationTitle("Add Provider")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await viewModel.addProvider(
                                platform: platform,
                                apiKey: apiKey,
                                apiUrl: apiUrl.isEmpty ? nil : apiUrl,
                                modelType: selectedModelId
                            )
                            dismiss()
                        }
                    }
                    .disabled(apiKey.isEmpty)
                }
            }
        }
    }

    private func testConnection() {
        Task {
            connectionSuccess = await viewModel.testProviderConnection(
                platform: platform,
                apiKey: apiKey,
                apiUrl: apiUrl.isEmpty ? nil : apiUrl
            )
            connectionTested = true
            if connectionSuccess {
                viewModel.availableModels = []
                selectedModelId = nil
                modelsFetched = false
            }
        }
    }

    private func fetchModels() {
        Task {
            await viewModel.fetchProviderModels(
                platform: platform,
                apiKey: apiKey,
                apiUrl: apiUrl.isEmpty ? nil : apiUrl
            )
            modelsFetched = true
        }
    }
}

// MARK: - Test Model
struct ModelValidationView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var platform = "OPENAI"
    @State private var modelType = "GPT_4O_MINI"
    @State private var apiKey = ""
    @State private var result: ModelValidationResult?

    var body: some View {
        Form {
            Section("Configuration") {
                Picker("Platform", selection: $platform) {
                    ForEach(ModelPlatform.allCases, id: \.self) { Text($0.displayName).tag($0.rawValue) }
                }
                Picker("Model", selection: $modelType) {
                    ForEach(ModelType.allCases, id: \.self) { Text($0.displayName).tag($0.rawValue) }
                }
                SecureField("API Key", text: $apiKey)
            }
            Section {
                Button("Test Model") {
                    Task { result = await viewModel.validateModel(platform: platform, modelType: modelType, apiKey: apiKey) }
                }
                .disabled(apiKey.isEmpty)
            }
            if let r = result {
                Section("Result") {
                    LabeledContent("Valid", value: r.isValid ? "Yes" : "No")
                    if let msg = r.message { Text(msg).font(.caption).foregroundColor(.secondary) }
                    if let e = r.error { Text(e).foregroundColor(.red) }
                    if let stages = r.successfulStages {
                        Text("Stages: \(stages.joined(separator: ", "))").font(.caption).foregroundColor(.secondary)
                    }
                }
            }
        }.navigationTitle("Test Model")
    }
}

// MARK: - API Settings
struct APISettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var endpointURL: String
    init(viewModel: SettingsViewModel) { self.viewModel = viewModel; _endpointURL = State(initialValue: UserDefaults.standard.string(forKey: "brain_endpoint") ?? "https://class.n0m3rci.cc/enter") }

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