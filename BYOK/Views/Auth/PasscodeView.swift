import SwiftUI

// MARK: - Constellation Canvas (Animated Particle Background)

struct ConstellationCanvas: View {
    @State private var particles: [(x: CGFloat, y: CGFloat, vx: CGFloat, vy: CGFloat, size: CGFloat, baseSize: CGFloat, phase: CGFloat)] = []
    @State private var initialized = false
    @State private var lastUpdate: Date = Date()

    private let particleCount = 100
    private let connectionDist: CGFloat = 180

    var body: some View {
        TimelineView(.animation(minimumInterval: 1/60)) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                let w = size.width
                let h = size.height

                // Initialize particles once (like web app's useEffect)
                if !initialized || particles.isEmpty {
                    var newParticles: [(x: CGFloat, y: CGFloat, vx: CGFloat, vy: CGFloat, size: CGFloat, baseSize: CGFloat, phase: CGFloat)] = []
                    for _ in 0..<particleCount {
                        let baseSize = CGFloat.random(in: 0.8...2.8)
                        newParticles.append((
                            x: CGFloat.random(in: 0...w),
                            y: CGFloat.random(in: 0...h),
                            vx: CGFloat.random(in: -0.25...0.25),
                            vy: CGFloat.random(in: -0.25...0.25),
                            size: baseSize,
                            baseSize: baseSize,
                            phase: CGFloat.random(in: 0...(CGFloat.pi * 2))
                        ))
                    }
                    particles = newParticles
                    initialized = true
                    lastUpdate = timeline.date
                    return
                }

                // Update particle positions with damping
                let dt = min(timeline.date.timeIntervalSince(lastUpdate), 0.05)
                lastUpdate = timeline.date

                for i in 0..<particles.count {
                    particles[i].vx *= CGFloat(pow(0.99, dt * 60))
                    particles[i].vy *= CGFloat(pow(0.99, dt * 60))

                    particles[i].x += particles[i].vx * CGFloat(dt * 60)
                    particles[i].y += particles[i].vy * CGFloat(dt * 60)

                    if particles[i].x < -20 { particles[i].x = w + 20 }
                    if particles[i].x > w + 20 { particles[i].x = -20 }
                    if particles[i].y < -20 { particles[i].y = h + 20 }
                    if particles[i].y > h + 20 { particles[i].y = -20 }

                    let pulse = sin(now * 0.8 + Double(particles[i].phase)) * 0.3 + 0.7
                    particles[i].size = particles[i].baseSize * CGFloat(pulse)
                }

                // Draw particles
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

                // Constellation connections
                for i in 0..<particles.count {
                    for j in (i+1)..<particles.count {
                        let dx = particles[i].x - particles[j].x
                        let dy = particles[i].y - particles[j].y
                        let dist = sqrt(dx * dx + dy * dy)
                        if dist < connectionDist {
                            let ratio = dist / connectionDist
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
        }
    }
}

// MARK: - Passcode Digit Box

struct PasscodeDigitBox: View {
    let digit: Character?
    let isActive: Bool
    let loggingIn: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    digit != nil ? Color.themeYellowLight : (isActive && !loggingIn ? Color.themeYellow : Color.themeYellow.opacity(0.3)),
                    lineWidth: 2
                )
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.black))
                .shadow(
                    color: digit != nil ? Color.themeYellow.opacity(0.3) : (isActive ? Color.themeYellow.opacity(0.2) : .clear),
                    radius: 8
                )
            if let d = digit {
                Text(String(d))
                    .font(.title2.bold())
                    .foregroundColor(.white)
            } else if isActive && !loggingIn {
                Text("|")
                    .font(.title2.bold())
                    .foregroundColor(.white)
            }
        }
        .frame(width: 44, height: 56)
    }
}

// MARK: - PasscodeGateView (Matches web app PasscodeGate.tsx)

struct PasscodeGateView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var tab: Tab = .login
    @State private var passcode = ""
    @State private var loginError = ""
    @State private var loggingIn = false
    @State private var loginAttempts = 0
    @State private var blockedUntil: Date = .distantPast

    @State private var name = ""
    @State private var registerStep: RegisterStep = .form
    @State private var generatedPasscode = ""
    @State private var confirmed = false
    @State private var registering = false
    @State private var registerError = ""

    @State private var adminEmail = ""
    @State private var adminPassword = ""
    @State private var adminLoggingIn = false
    @State private var adminLoginError = ""

    @FocusState private var isPasscodeFieldFocused: Bool

    private let passcodeLength = 6
    private let maxLoginAttempts = 5
    private let blockDuration: TimeInterval = 30

    enum Tab { case login, register, admin }
    enum RegisterStep { case form, done }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            ConstellationCanvas()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 0) {
                    // Logo - matches web app exactly
                    VStack(spacing: 0) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.black)
                                .frame(width: 80, height: 80)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.themeYellow, lineWidth: 2))
                                .shadow(color: Color.themeYellow.opacity(0.2), radius: 12)
                            Text("🤖")
                                .font(.system(size: 30))
                        }

                        Text("M3RCI-UniMind")
                            .font(.title.bold())
                            .foregroundColor(.black)
                            .padding(.top, 12)

                        if tab == .login {
                            Text("Enter your passcode to begin")
                                .font(.subheadline)
                                .foregroundColor(.black.opacity(0.6))
                                .padding(.top, 4)
                        }
                    }
                    .padding(.bottom, 32)

                    // Card
                    VStack(spacing: 0) {
                        // Tab bar
                        if tab != .admin {
                            HStack(spacing: 0) {
                                tabButton(title: "Your 6 digit Passcode", isActive: tab == .login) {
                                    tab = .login; loginError = ""; focusPasscodeField()
                                }
                                tabButton(title: "Get a Passcode", isActive: tab == .register) {
                                    tab = .register; registerError = ""; registerStep = .form
                                }
                            }
                            .padding(4)
                            .background(Color.themeYellow.opacity(0.1))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.themeYellow.opacity(0.2), lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .padding(.bottom, 24)
                        }

                        switch tab {
                        case .login: loginContent
                        case .register: registerContent
                        case .admin: adminLoginContent
                        }
                    }
                    .padding(24)
                    .background(Color.black)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.themeYellow, lineWidth: 2))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.themeYellow.opacity(0.2), radius: 12)
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: 400)

                Spacer()

                // Admin Login toggle
                Button(action: {
                    if tab == .admin {
                        tab = .login
                        loginError = ""
                        focusPasscodeField()
                    } else {
                        tab = .admin
                        adminLoginError = ""
                    }
                }) {
                    Text(tab == .admin ? "Back to Passcode Login" : "Admin Login")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(tab == .admin ? Color.themeYellowLight.opacity(0.6) : Color.themeYellow)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            focusPasscodeField()
        }
    }

    private func focusPasscodeField() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isPasscodeFieldFocused = true
        }
    }

    // MARK: - Tab Button

    private func tabButton(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundColor(isActive ? .black : Color.themeYellowLight.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(isActive ? Color.themeYellow : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    // MARK: - Login Tab

    @ViewBuilder
    private var loginContent: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                ForEach(0..<passcodeLength, id: \.self) { i in
                    PasscodeDigitBox(
                        digit: i < passcode.count ? passcode[passcode.index(passcode.startIndex, offsetBy: i)] : nil,
                        isActive: i == passcode.count,
                        loggingIn: loggingIn
                    )
                }
            }

            // Hidden text field with FocusState for keyboard capture
            TextField("", text: $passcode)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isPasscodeFieldFocused)
                .frame(width: 0, height: 0)
                .opacity(0)
                .onChange(of: passcode) { newValue in
                    let digits = String(newValue.filter { $0.isNumber }.prefix(passcodeLength))
                    passcode = digits
                    loginError = ""
                    if digits.count == passcodeLength && !loggingIn {
                        handlePasscodeLogin()
                    }
                }

            Text("Click anywhere and type your passcode")
                .font(.caption2)
                .foregroundColor(Color.themeYellowLight.opacity(0.4))
                .onTapGesture { focusPasscodeField() }

            if !loginError.isEmpty {
                Text(loginError)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.red)
            }
            if loggingIn {
                Text("Signing in...")
                    .font(.subheadline)
                    .foregroundColor(Color.themeYellowLight.opacity(0.6))
            }

            Text("Forgot your passcode? Contact your instructor.")
                .font(.caption2)
                .foregroundColor(Color.themeYellowLight.opacity(0.4))
        }
    }

    // MARK: - Register Tab

    @ViewBuilder
    private var registerContent: some View {
        switch registerStep {
        case .form:
            VStack(spacing: 16) {
                Text("Enter your name to get a passcode")
                    .font(.subheadline)
                    .foregroundColor(Color.themeYellowLight.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)

                TextField("e.g. Prince", text: $name)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.themeYellow.opacity(0.2), lineWidth: 1))
                    .foregroundColor(.black)
                    .onSubmit {
                        if !name.trimmingCharacters(in: .whitespaces).isEmpty && !registering {
                            handleRegister()
                        }
                    }

                if !registerError.isEmpty {
                    Text(registerError)
                        .font(.subheadline)
                        .foregroundColor(.red)
                }

                Button(action: handleRegister) {
                    HStack {
                        if registering { ProgressView().progressViewStyle(.circular).tint(.black) }
                        Text(registering ? "Generating..." : "Generate Passcode")
                            .font(.subheadline.weight(.medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(name.trimmingCharacters(in: .whitespaces).isEmpty || registering ? Color.themeYellow.opacity(0.5) : Color.themeYellow)
                    .foregroundColor(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || registering)
            }

        case .done:
            VStack(spacing: 16) {
                Text("Your passcode")
                    .font(.subheadline)
                    .foregroundColor(Color.themeYellowLight.opacity(0.6))

                HStack(spacing: 10) {
                    ForEach(Array(generatedPasscode), id: \.self) { digit in
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black)
                                .frame(width: 44, height: 56)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.themeYellowLight, lineWidth: 2))
                                .shadow(color: Color.themeYellow.opacity(0.3), radius: 8)
                            Text(String(digit))
                                .font(.title2.bold())
                                .foregroundColor(Color.themeYellowLight)
                        }
                    }
                }

                // Warning notice
                VStack(spacing: 12) {
                    HStack(alignment: .top, spacing: 8) {
                        Text("⚠️").font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("IMPORTANT \u{2014} Please Read")
                                .font(.subheadline.bold())
                                .foregroundColor(Color.themeYellowLight)
                            Text("This passcode is the **ONLY** way to access your account. Write it down or save it somewhere safe right now.")
                                .font(.caption)
                                .foregroundColor(Color.themeYellowLight.opacity(0.7))
                            Text("Without this passcode, you will lose access to your chats and data.")
                                .font(.caption)
                                .foregroundColor(.themeYellow)
                        }
                    }
                    HStack(spacing: 8) {
                        Image(systemName: confirmed ? "checkmark.square.fill" : "square")
                            .foregroundColor(.themeYellow)
                            .onTapGesture { confirmed.toggle() }
                        Text("I have saved my passcode")
                            .font(.caption)
                            .foregroundColor(Color.themeYellowLight.opacity(0.7))
                            .onTapGesture { confirmed.toggle() }
                    }
                }
                .padding(16)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.451, green: 0.243, blue: 0.039).opacity(0.4), Color(red: 0.275, green: 0.098, blue: 0.004).opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.themeYellow.opacity(0.3), lineWidth: 1))

                Button(action: { handlePasscodeLogin(code: generatedPasscode) }) {
                    Text("Got it, I\u{2019}ve saved it!")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(confirmed ? Color.themeYellow : Color.themeYellow.opacity(0.5))
                        .foregroundColor(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .disabled(!confirmed)
            }
        }
    }

    // MARK: - Admin Login (Inline)

    @ViewBuilder
    private var adminLoginContent: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Admin Email")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(Color.themeYellowLight.opacity(0.8))

                TextField("admin@example.com", text: $adminEmail)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.themeYellow.opacity(0.2), lineWidth: 1))
                    .foregroundColor(.black)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(Color.themeYellowLight.opacity(0.8))

                SecureField("Enter your password", text: $adminPassword)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.themeYellow.opacity(0.2), lineWidth: 1))
                    .foregroundColor(.black)
            }

            if !adminLoginError.isEmpty {
                Text(adminLoginError)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.red)
            }

            Button(action: handleAdminLogin) {
                HStack {
                    if adminLoggingIn { ProgressView().progressViewStyle(.circular).tint(.black) }
                    Text(adminLoggingIn ? "Signing in..." : "Sign In")
                        .font(.subheadline.weight(.medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(adminEmail.isEmpty || adminPassword.isEmpty || adminLoggingIn ? Color.themeYellow.opacity(0.5) : Color.themeYellow)
                .foregroundColor(.black)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(adminEmail.isEmpty || adminPassword.isEmpty || adminLoggingIn)
        }
    }

    // MARK: - Actions

    private func handlePasscodeLogin(code: String? = nil) {
        let codeToUse = code ?? passcode
        guard codeToUse.count == passcodeLength else { return }

        let now = Date()
        if now < blockedUntil {
            let remaining = Int(blockedUntil.timeIntervalSince(now))
            loginError = "Too many attempts. Try again in \(remaining)s."
            return
        }

        loggingIn = true
        loginError = ""

        Task {
            let error = await authViewModel.passcodeLogin(code: codeToUse)
            loggingIn = false
            if let error = error {
                loginAttempts += 1
                if loginAttempts >= maxLoginAttempts {
                    blockedUntil = Date().addingTimeInterval(blockDuration)
                    loginError = "Too many failed attempts. Try again in \(Int(blockDuration))s."
                } else {
                    loginError = error
                }
                passcode = ""
            }
        }
    }

    private func handleRegister() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        registering = true
        registerError = ""

        Task {
            let result = await authViewModel.passcodeRegister(name: trimmedName)
            registering = false
            if let passcode = result.passcode {
                generatedPasscode = passcode
                registerStep = .done
            } else if let error = result.error {
                registerError = error
            }
        }
    }

    private func handleAdminLogin() {
        guard !adminEmail.isEmpty, !adminPassword.isEmpty else {
            adminLoginError = "Please enter email and password."
            return
        }
        adminLoggingIn = true
        adminLoginError = ""

        Task {
            let error = await authViewModel.adminLogin(email: adminEmail, password: adminPassword)
            adminLoggingIn = false
            if let error = error {
                adminLoginError = error
            }
        }
    }
}