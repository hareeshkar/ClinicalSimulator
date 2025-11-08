import SwiftUI
import SwiftData

struct LoginView: View {
    // MARK: - State Properties
    @State private var email = ""
    @State private var password = ""
    @State private var rememberMe = false
    @State private var isPasswordVisible = false
    @State private var isLoggingIn = false
    
    // Error Handling & Animation
    @State private var errorMessage: String?
    @State private var hasError = false
    private let errorHaptic = UINotificationFeedbackGenerator()
    
    @FocusState private var focusedField: Field?
    @EnvironmentObject var authService: AuthService
    
    // Theme Detection
    @Environment(\.colorScheme) private var colorScheme
    
    enum Field: CaseIterable {
        case email, password
    }

    // MARK: - Main Body
    var body: some View {
        NavigationStack {
            ZStack {
                // Layer 1: Adaptive Background
                adaptiveBackground
                
                // Layer 2: Main Content
                ScrollView {
                    VStack(spacing: 32) {
                        headerSection
                        
                        // Layer 3: Premium Glass Card
                        VStack(spacing: 24) {
                            loginTitleSection
                            
                            VStack(spacing: 20) {
                                emailField
                                passwordField
                            }
                            // Instant feedback on error - no slow animations
                            .modifier(ShakeEffect(shakes: hasError ? 2 : 0))
                            .animation(hasError ? .spring(response: 0.15, dampingFraction: 0.8) : .none, value: hasError)
                            
                            errorSection
                            
                            rememberMeSection
                            
                            loginButton
                        }
                        .padding(28)
                        .background(cardBackgroundMaterial)
                        .overlay(cardBorder)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: shadowColor, radius: 20, x: 0, y: 10)
                        .padding(.horizontal, 20)
                        
                        signUpLink
                    }
                    .padding(.vertical, 75)
                }
                .scrollDismissesKeyboard(.immediately)
            }
            .background(adaptiveSystemBackground)
            .preferredColorScheme(nil) // Let system handle theme
        }
    }

    // MARK: - Computed Properties for Theme Adaptation
    
    private var adaptiveBackground: some View {
        ZStack {
            // Base gradient that adapts to theme
            LinearGradient(
                gradient: Gradient(colors: backgroundGradientColors),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Ambient shapes - more subtle in dark mode
            Circle()
                .fill(accentShapeColor)
                .blur(radius: 100)
                .offset(x: -120, y: -200)
                .opacity(shapeOpacity)
            
            Circle()
                .fill(secondaryShapeColor)
                .blur(radius: 140)
                .offset(x: 150, y: 150)
                .opacity(shapeOpacity * 0.8)
        }
        // Make background tappable to dismiss keyboard without interfering with child controls
        .contentShape(Rectangle())
        .onTapGesture {
            focusedField = nil
        }
    }
    
    private var backgroundGradientColors: [Color] {
        if colorScheme == .dark {
            return [Color.black.opacity(0.9), Color(.systemGray6).opacity(0.3)]
        } else {
            return [Color(.systemBackground), Color(.systemGray6).opacity(0.5)]
        }
    }
    
    private var accentShapeColor: Color {
        colorScheme == .dark ? Color.cyan.opacity(0.3) : Color.cyan.opacity(0.4)
    }
    
    private var secondaryShapeColor: Color {
        colorScheme == .dark ? Color.accentColor.opacity(0.2) : Color.accentColor.opacity(0.3)
    }
    
    private var shapeOpacity: Double {
        colorScheme == .dark ? 0.4 : 0.6
    }
    
    private var cardBackgroundMaterial: Material {
        colorScheme == .dark ? .ultraThickMaterial : .ultraThinMaterial
    }
    
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(borderColor, lineWidth: borderWidth)
    }
    
    private var borderColor: Color {
        if colorScheme == .dark {
            return Color.white.opacity(0.1)
        } else {
            return Color.black.opacity(0.08)
        }
    }
    
    private var borderWidth: CGFloat {
        colorScheme == .dark ? 1.5 : 1.0
    }
    
    private var shadowColor: Color {
        if colorScheme == .dark {
            return Color.black.opacity(0.3)
        } else {
            return Color.black.opacity(0.1)
        }
    }
    
    private var adaptiveSystemBackground: Color {
        Color(.systemBackground)
    }

    // MARK: - ViewBuilder Components
    
    private var headerSection: some View {
        VStack(spacing: 20) {
            // Medical icon with adaptive styling - now using custom logo instead of SF Symbol
            ZStack {
                Circle()
                    .fill(iconBackgroundGradient)
                    .frame(width: 107, height: 107)
                    .shadow(color: shadowColor, radius: 10, y: 5)
                
                // Replaced SF Symbol with custom logo.png
                Image("logo")  // Reference the asset name from Assets.xcassets
                    .resizable()  // Make it resizable for scaling
                    .scaledToFit()  // Maintain aspect ratio and fit within the circle
                    .frame(width: 100, height: 100)  // Increased size to fill more of the 100x100 circle while leaving padding
                    .clipShape(Circle())  // Clip to circle to match the background and remove borders
                    .foregroundStyle(.white)  // Optional: Tint if needed, but remove if logo has its own colors
            }
            
            VStack(spacing: 8) {
                Text("Clinical Simulator")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.primary)
                
                Text("AI-Powered Medical Education")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var iconBackgroundGradient: LinearGradient {
        LinearGradient(
            colors: [Color.accentColor, Color.cyan],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var loginTitleSection: some View {
        VStack(spacing: 6) {
            Text("Resume Your Training")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
            
            Text("Sign in to continue your medical training")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
    
    private var emailField: some View {
        PremiumTextField(
            text: $email,
            prompt: "Email Address",
            systemImageName: "envelope.fill",
            isFocused: $focusedField,
            focusCase: .email,
            colorScheme: colorScheme
        )
        .keyboardType(.emailAddress)
        .textContentType(.emailAddress)
        .autocapitalization(.none)
        .submitLabel(.next)
        .onSubmit { focusedField = .password }
    }
    
    private var passwordField: some View {
        PremiumTextField(
            text: $password,
            isSecure: !isPasswordVisible,
            prompt: "Password",
            systemImageName: "lock.fill",
            isFocused: $focusedField,
            focusCase: .password,
            colorScheme: colorScheme
        ) {
            Button {
                isPasswordVisible.toggle()
                // Haptic feedback for interaction
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 20, height: 20)
            }
        }
        .textContentType(.password)
        .submitLabel(.done)
        .onSubmit(performLogin)
    }
    
    @ViewBuilder
    private var errorSection: some View {
        if let errorMessage {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.system(size: 14))
                
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(errorBackgroundColor)
            .overlay(errorBorder)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
        }
    }
    
    private var errorBackgroundColor: Color {
        if colorScheme == .dark {
            return Color.red.opacity(0.15)
        } else {
            return Color.red.opacity(0.08)
        }
    }
    
    private var errorBorder: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(Color.red.opacity(0.3), lineWidth: 1)
    }
    
    private var rememberMeSection: some View {
        HStack {
            Toggle(isOn: $rememberMe) {
                Text("Remember me")
                    .font(.callout)
                    .foregroundStyle(.primary)
            }
            .toggleStyle(PremiumCheckboxStyle(colorScheme: colorScheme))
            
            Spacer()
            
            Button("Forgot Password?") {
                // TODO: Implement password reset flow
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            .font(.callout.weight(.medium))
            .foregroundStyle(Color.accentColor)
        }
    }
    
    private var loginButton: some View {
        Button(action: performLogin) {
            HStack(spacing: 12) {
                if isLoggingIn {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                } else {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                    
                    Text("Sign In")
                        .font(.headline.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .foregroundStyle(.white)
            .background(buttonBackgroundGradient)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: buttonShadowColor, radius: 8, y: 4)
            .scaleEffect(isLoggingIn ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isLoggingIn)
        }
        .disabled(isLoggingIn || email.isEmpty || password.isEmpty)
        .opacity((isLoggingIn || email.isEmpty || password.isEmpty) ? 0.7 : 1.0)
    }
    
    private var buttonBackgroundGradient: LinearGradient {
        LinearGradient(
            colors: [Color.accentColor, Color.cyan],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var buttonShadowColor: Color {
        if colorScheme == .dark {
            return Color.accentColor.opacity(0.2)
        } else {
            return Color.accentColor.opacity(0.3)
        }
    }
    
    private var signUpLink: some View {
        HStack(spacing: 6) {
            Text("New here?")
                .foregroundStyle(.secondary)
            
            NavigationLink("Create an account") {
                SignUpView()
            }
            .font(.callout.weight(.semibold))
            .foregroundStyle(Color.accentColor)
        }
        .font(.callout)
    }
    
    // MARK: - Logic
    
    private func performLogin() {
        guard !isLoggingIn else { return }
        
        // Client-side validation first — fast feedback, no network roundtrip.
        guard validateInputs() else { return }
        
        // Immediate haptic feedback for accepted action
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        isLoggingIn = true
        withAnimation(.easeOut(duration: 0.2)) {
            hasError = false
            errorMessage = nil
        }
        
        // Dismiss keyboard immediately
        focusedField = nil
        
        Task {
            do {
                try await authService.login(email: email, password: password)
                
            } catch let authError as AuthError {
                await MainActor.run {
                    self.errorMessage = authError.localizedDescription
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        self.hasError = true
                    }
                    triggerErrorHaptic()
                    self.isLoggingIn = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Connection error. Please try again."
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        self.hasError = true
                    }
                    triggerErrorHaptic()
                    self.isLoggingIn = false
                }
            }
        }
    }
    
    /// Lightweight client-side validation with haptic + shake feedback.
    private func validateInputs() -> Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Email empty
        if trimmedEmail.isEmpty {
            withAnimation {
                self.errorMessage = "Please enter your email."
                self.hasError = true
            }
            triggerErrorHaptic()
            focusedField = .email
            return false
        }
        
        // Basic email format check
        let emailPredicate = NSPredicate(format: "SELF MATCHES[c] %@", "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}")
        if !emailPredicate.evaluate(with: trimmedEmail) {
            withAnimation {
                self.errorMessage = "Please enter a valid email address."
                self.hasError = true
            }
            triggerErrorHaptic()
            focusedField = .email
            return false
        }
        
        // Password empty
        if trimmedPassword.isEmpty {
            withAnimation {
                self.errorMessage = "Please enter your password."
                self.hasError = true
            }
            triggerErrorHaptic()
            focusedField = .password
            return false
        }
        
        
        // All good
        return true
    }
    
    private func triggerErrorHaptic() {
        errorHaptic.notificationOccurred(.error)
    }
}

// MARK: - Premium TextField Component

struct PremiumTextField<TrailingContent: View>: View {
    @Binding var text: String
    var isSecure: Bool = false
    var prompt: String
    var systemImageName: String
    
    @FocusState.Binding var isFocused: LoginView.Field?
    var focusCase: LoginView.Field
    var colorScheme: ColorScheme
    
    var trailingContent: () -> TrailingContent
    
    init(
        text: Binding<String>,
        isSecure: Bool = false,
        prompt: String,
        systemImageName: String,
        isFocused: FocusState<LoginView.Field?>.Binding,
        focusCase: LoginView.Field,
        colorScheme: ColorScheme,
        @ViewBuilder trailingContent: @escaping () -> TrailingContent = { EmptyView() }
    ) {
        self._text = text
        self.isSecure = isSecure
        self.prompt = prompt
        self.systemImageName = systemImageName
        self._isFocused = isFocused
        self.focusCase = focusCase
        self.colorScheme = colorScheme
        self.trailingContent = trailingContent
    }
    
    private var isFieldFocused: Bool {
        isFocused == focusCase
    }
    
    private var fieldBackgroundColor: Color {
        if colorScheme == .dark {
            return isFieldFocused ? Color(.systemGray5).opacity(0.8) : Color(.systemGray6).opacity(0.6)
        } else {
            return isFieldFocused ? Color(.systemBackground) : Color(.systemGray6).opacity(0.5)
        }
    }
    
    private var fieldBorderColor: Color {
        if isFieldFocused {
            return Color.accentColor
        } else if colorScheme == .dark {
            return Color.white.opacity(0.1)
        } else {
            return Color.black.opacity(0.08)
        }
    }
    
    private var iconColor: Color {
        if isFieldFocused {
            return Color.accentColor
        } else {
            return Color.secondary
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: systemImageName)
                .foregroundStyle(iconColor)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 20)
            
            Group {
                if isSecure {
                    SecureField(prompt, text: $text)
                } else {
                    TextField(prompt, text: $text)
                }
            }
            .font(.callout)
            .focused($isFocused, equals: focusCase)
            
            trailingContent()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(fieldBackgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(fieldBorderColor, lineWidth: isFieldFocused ? 2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .animation(.easeOut(duration: 0.15), value: isFieldFocused)
        .contentShape(Rectangle()) // ensure full row is tappable
        .onTapGesture {
            isFocused = focusCase
        }
    }
}

// MARK: - Premium Checkbox Style

struct PremiumCheckboxStyle: ToggleStyle {
    let colorScheme: ColorScheme
    
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(configuration.isOn ? Color.accentColor : checkboxBackgroundColor)
                        .frame(width: 22, height: 22)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(checkboxBorderColor, lineWidth: configuration.isOn ? 0 : 1.5)
                        )
                    
                    if configuration.isOn {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.white)
                            .font(.system(size: 12, weight: .bold))
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isOn)
                
                configuration.label
            }
        }
        .buttonStyle(.plain)
    }
    
    private var checkboxBackgroundColor: Color {
        colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6)
    }
    
    private var checkboxBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.2)
    }
}

// MARK: - Enhanced Shake Effect

struct ShakeEffect: AnimatableModifier {
    var shakes: CGFloat
    
    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }
    
    func body(content: Content) -> some View {
        content
            .offset(x: sin(shakes * .pi * 4) * 6) // Faster, more precise shake
    }
}

// MARK: - Preview

#Preview("Light Mode") {
    let authService = AuthService(modelContext: try! ModelContainer(for: User.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)).mainContext)
    
    LoginView()
        .environmentObject(authService)
        .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    let authService = AuthService(modelContext: try! ModelContainer(for: User.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)).mainContext)
    
    LoginView()
        .environmentObject(authService)
        .preferredColorScheme(.dark)
}
