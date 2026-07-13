import SwiftUI

// MARK: - Constellation Canvas (Animated Particle Background)

/// Manages particle physics on a timer (like web app's requestAnimationFrame)
final class ParticleSystem: ObservableObject, @unchecked Sendable {
    struct Particle {
        var x: CGFloat
        var y: CGFloat
        var vx: CGFloat
        var vy: CGFloat
        var size: CGFloat
        let baseSize: CGFloat
        let phase: CGFloat
    }

    @Published var particles: [Particle] = []
    var canvasWidth: CGFloat = 400
    var canvasHeight: CGFloat = 800

    private let particleCount = 100
    let connectionDist: CGFloat = 180
    private var timer: Timer?
    private var lastUpdate: Date = Date()

    func start() {
        lastUpdate = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let now = Date()
        let dt = min(now.timeIntervalSince(lastUpdate), 0.05)
        lastUpdate = now

        if particles.isEmpty {
            var newParticles: [Particle] = []
            for _ in 0..<particleCount {
                let baseSize = CGFloat.random(in: 0.8...2.8)
                newParticles.append(Particle(
                    x: CGFloat.random(in: 0...max(canvasWidth, 400)),
                    y: CGFloat.random(in: 0...max(canvasHeight, 800)),
                    vx: CGFloat.random(in: -0.25...0.25),
                    vy: CGFloat.random(in: -0.25...0.25),
                    size: baseSize,
                    baseSize: baseSize,
                    phase: CGFloat.random(in: 0...(CGFloat.pi * 2))
                ))
            }
            particles = newParticles
            return
        }

        let referenceDate = now.timeIntervalSinceReferenceDate
        let w = canvasWidth
        let h = canvasHeight

        for i in 0..<particles.count {
            var p = particles[i]
            p.vx *= CGFloat(pow(0.99, dt * 60))
            p.vy *= CGFloat(pow(0.99, dt * 60))

            p.x += p.vx * CGFloat(dt * 60)
            p.y += p.vy * CGFloat(dt * 60)

            if p.x < -20 { p.x = w + 20 }
            if p.x > w + 20 { p.x = -20 }
            if p.y < -20 { p.y = h + 20 }
            if p.y > h + 20 { p.y = -20 }

            let pulse = sin(referenceDate * 0.8 + Double(p.phase)) * 0.3 + 0.7
            p.size = p.baseSize * CGFloat(pulse)

            particles[i] = p
        }
    }
}

struct ConstellationCanvas: View {
    @StateObject private var system = ParticleSystem()

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let particles = system.particles

                // Draw particles — NO state mutations here!
                for p in particles {
                    let glowRect = CGRect(x: p.x - p.size * 4, y: p.y - p.size * 4, width: p.size * 8, height: p.size * 8)
                    context.fill(Path(ellipseIn: glowRect), with: .color(.themeYellow.opacity(0.08)))

                    let coreRect = CGRect(x: p.x - p.size, y: p.y - p.size, width: p.size * 2, height: p.size * 2)
                    context.fill(Path(ellipseIn: coreRect), with: .color(.themeYellow.opacity(0.4)))

                    if p.baseSize > 1.8 {
                        let highlightRect = CGRect(x: p.x - p.size * 0.5, y: p.y - p.size * 0.5, width: p.size, height: p.size)
                        context.fill(Path(ellipseIn: highlightRect), with: .color(.themeYellow.opacity(0.5)))
                    }
                }

                for i in 0..<particles.count {
                    for j in (i+1)..<particles.count {
                        let dx = particles[i].x - particles[j].x
                        let dy = particles[i].y - particles[j].y
                        let dist = sqrt(dx * dx + dy * dy)
                        if dist < system.connectionDist {
                            let ratio = dist / system.connectionDist
                            let alpha = (1 - ratio) * 0.2
                            var path = Path()
                            path.move(to: CGPoint(x: particles[i].x, y: particles[i].y))
                            path.addLine(to: CGPoint(x: particles[j].x, y: particles[j].y))
                            context.stroke(path, with: .color(.themeYellow.opacity(alpha * 0.4)), lineWidth: (1 - ratio) * 0.8 + 0.2)
                        }
                    }
                }
            }
            .ignoresSafeArea()
            .onAppear {
                system.canvasWidth = geo.size.width
                system.canvasHeight = geo.size.height
                system.start()
            }
            .onChange(of: geo.size) { newSize in
                system.canvasWidth = newSize.width
                system.canvasHeight = newSize.height
            }
            .onDisappear { system.stop() }
        }
    }
}

// MARK: - Passcode Gate View

struct PasscodeGateView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    enum PasscodeTab: String, CaseIterable {
        case student = "Passcode"
        case register = "Register"
        case admin = "Admin"
    }

    @State private var selectedTab: PasscodeTab = .student
    @State private var passcodeDigits: [String] = Array(repeating: "", count: 6)
    @State private var registerName = ""
    @State private var adminEmail = ""
    @State private var adminPassword = ""
    @State private var registeredPasscode: String?
    @State private var localError: String?
    @FocusState private var focusedField: Field?

    enum Field {
        case passcode, adminEmail, adminPassword, register
    }

    var body: some View {
        ZStack {
            ConstellationCanvas()

            VStack(spacing: 0) {
                Spacer()

                // Logo / Branding
                VStack(spacing: 8) {
                    Text("🤖")
                        .font(.system(size: 48))
                    Text("M3RCI-UniMind")
                        .font(.title.bold())
                        .foregroundColor(.white)
                    Text("AI Multi-Agent Workforce")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.bottom, 40)

                // Tab selector
                HStack(spacing: 0) {
                    ForEach(PasscodeTab.allCases, id: \.self) { tab in
                        Button(action: { selectedTab = tab; localError = nil; registeredPasscode = nil }) {
                            Text(tab.rawValue)
                                .font(.subheadline.weight(selectedTab == tab ? .semibold : .regular))
                                .foregroundColor(selectedTab == tab ? .themeYellow : .white.opacity(0.5))
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .overlay(alignment: .bottom) {
                                    if selectedTab == tab {
                                        Rectangle().fill(Color.themeYellow).frame(height: 2)
                                    }
                                }
                        }
                    }
                }
                .padding(.horizontal, 32)

                // Content
                VStack(spacing: 24) {
                    switch selectedTab {
                    case .student:
                        studentLoginView
                    case .register:
                        registerView
                    case .admin:
                        adminLoginView
                    }

                    // Error message
                    if let err = localError ?? authViewModel.errorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }

                    // Loading indicator
                    if authViewModel.isLoading {
                        ProgressView()
                            .tint(.themeYellow)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 32)

                Spacer()
            }
        }
        .ignoresSafeArea()
        .onChange(of: authViewModel.authState) { _ in }
    }

    // MARK: - Student Login

    private var studentLoginView: some View {
        VStack(spacing: 20) {
            Text("Enter Student Passcode")
                .font(.headline)
                .foregroundColor(.white)

            HStack(spacing: 10) {
                ForEach(0..<6, id: \.self) { index in
                    PasscodeDigitBox(text: $passcodeDigits[index], index: index)
                }
            }

            // Hidden text field to capture keyboard input
            TextField("", text: $passcodeDigits[0])
                .focused($focusedField, equals: .passcode)
                .keyboardType(.numberPad)
                .opacity(0)
                .frame(width: 0, height: 0)
                .onChange(of: passcodeDigits.joined()) { newValue in
                    let digits = newValue.filter(\.isNumber)
                    for i in 0..<6 {
                        passcodeDigits[i] = i < digits.count ? String(digits[digits.index(digits.startIndex, offsetBy: i)]) : ""
                    }
                    if digits.count == 6 {
                        submitPasscode(digits)
                    }
                }

            Button("Sign In") {
                let code = passcodeDigits.joined()
                guard code.count == 6 else { return }
                submitPasscode(code)
            }
            .font(.headline)
            .foregroundColor(.black)
            .padding(.horizontal, 48)
            .padding(.vertical, 14)
            .background(Color.themeYellow)
            .cornerRadius(12)
            .disabled(authViewModel.isLoading)

            Text("Enter your 6-digit student passcode to sign in")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
        }
        .onAppear { focusedField = .passcode }
    }

    // MARK: - Register

    private var registerView: some View {
        VStack(spacing: 20) {
            if let passcode = registeredPasscode {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("Registration Successful!")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Your passcode is:")
                        .foregroundColor(.white.opacity(0.7))
                    Text(passcode)
                        .font(.system(size: 32, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.themeYellow)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).stroke(Color.themeYellow, lineWidth: 1))
                    Text("Save this passcode to sign in later")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                    Button("Sign In") {
                        selectedTab = .student
                        registeredPasscode = nil
                    }
                    .font(.headline)
                    .foregroundColor(.black)
                    .padding(.horizontal, 48)
                    .padding(.vertical, 14)
                    .background(Color.themeYellow)
                    .cornerRadius(12)
                }
            } else {
                Text("Register a New Account")
                    .font(.headline)
                    .foregroundColor(.white)

                TextField("Your Name", text: $registerName)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.3)))
                    .foregroundColor(.white)
                    .focused($focusedField, equals: .register)
                    .autocapitalization(.words)

                Button("Register") {
                    guard !registerName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    submitRegistration()
                }
                .font(.headline)
                .foregroundColor(.black)
                .padding(.horizontal, 48)
                .padding(.vertical, 14)
                .background(Color.themeYellow)
                .cornerRadius(12)
                .disabled(authViewModel.isLoading || registerName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear { focusedField = .register }
    }

    // MARK: - Admin Login

    private var adminLoginView: some View {
        VStack(spacing: 20) {
            Text("Admin Login")
                .font(.headline)
                .foregroundColor(.white)

            VStack(spacing: 12) {
                TextField("Email", text: $adminEmail)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.3)))
                    .foregroundColor(.white)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .focused($focusedField, equals: .adminEmail)

                SecureField("Password", text: $adminPassword)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.3)))
                    .foregroundColor(.white)
                    .focused($focusedField, equals: .adminPassword)
            }

            Button("Sign In") {
                guard !adminEmail.isEmpty, !adminPassword.isEmpty else { return }
                submitAdminLogin()
            }
            .font(.headline)
            .foregroundColor(.black)
            .padding(.horizontal, 48)
            .padding(.vertical, 14)
            .background(Color.themeYellow)
            .cornerRadius(12)
            .disabled(authViewModel.isLoading)
        }
        .onAppear { focusedField = .adminEmail }
    }

    // MARK: - Actions

    private func submitPasscode(_ code: String) {
        Task {
            localError = nil
            if let error = await authViewModel.passcodeLogin(code: code) {
                localError = error
                passcodeDigits = Array(repeating: "", count: 6)
                focusedField = .passcode
            }
        }
    }

    private func submitRegistration() {
        Task {
            localError = nil
            let (passcode, error) = await authViewModel.passcodeRegister(name: registerName)
            if let error {
                localError = error
            } else if let passcode {
                registeredPasscode = passcode
            }
        }
    }

    private func submitAdminLogin() {
        Task {
            localError = nil
            await authViewModel.login(email: adminEmail, password: adminPassword)
        }
    }
}

// MARK: - Passcode Digit Box

struct PasscodeDigitBox: View {
    @Binding var text: String
    let index: Int

    var body: some View {
        Text(text.isEmpty ? "" : text)
            .font(.system(size: 24, weight: .bold))
            .foregroundColor(.themeYellow)
            .frame(width: 44, height: 52)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(text.isEmpty ? Color.white.opacity(0.3) : Color.themeYellow, lineWidth: 1.5)
            )
    }
}