import SwiftUI
import PhotosUI
import SwiftData

struct SignUpView: View {
    // MARK: - State Properties
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var selectedRole: UserProfileRole = .studentMS3 // Default role
    
    // Image Picking State
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var profileImage: UIImage? // This will hold the final cropped image
    @State private var tempImageForCropping: UIImage?
    @State private var isShowingCropper = false
    
    // View State
    @State private var errorMessage: String?
    @State private var isSigningUp = false
    @State private var hasError = false
    @State private var isPasswordVisible = false
    private let errorHaptic = UINotificationFeedbackGenerator()
    
    @FocusState private var focusedField: Field?
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    enum Field: CaseIterable {
        case fullName, email, password, confirmPassword
    }
    
    // MARK: - Main Body
    var body: some View {
        ZStack {
            // Layer 1: Adaptive Background (re-used from LoginView)
            adaptiveBackground
            
            // Layer 2: Main Content
            ScrollView {
                VStack(spacing: 18) {  // Reduced from 24
                    headerSection
                    
                    // Layer 3: Premium Glass Card
                    VStack(spacing: 18) {  // Reduced from 24
                        profilePickerSection
                        
                        VStack(spacing: 14) {  // Reduced from 16
                            fullNameField
                            emailField
                            passwordField
                            confirmPasswordField
                            rolePicker
                        }
                        // Shake animation on error
                        .modifier(ShakeEffect(shakes: hasError ? 2 : 0))
                        .animation(hasError ? .spring(response: 0.15, dampingFraction: 0.8) : .none, value: hasError)
                        
                        errorSection
                        
                        createAccountButton
                    }
                    .padding(20)  // Reduced from 24
                    .background(cardBackgroundMaterial)
                    .overlay(cardBorder)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: shadowColor, radius: 20, x: 0, y: 10)
                    .padding(.horizontal, 20)
                    
                    signInLink
                }
                .padding(.vertical, 20)  // Reduced from 25
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationBarBackButtonHidden(true)
            .navigationBarHidden(true)
        }
        .background(adaptiveSystemBackground)
        .preferredColorScheme(nil) // Respect system theme
        .onChange(of: selectedPhotoItem) { handlePhotoSelection() }
        .fullScreenCover(isPresented: $isShowingCropper) {
            // This logic is preserved from your original file
            ImageCropper(image: $tempImageForCropping) { croppedImage in
                profileImage = croppedImage
                tempImageForCropping = nil
            }
        }
    }

    // MARK: - Computed Properties for Theme Adaptation
    
    private var adaptiveBackground: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: backgroundGradientColors),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
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
        // Make background taps dismiss the keyboard without capturing child touches
        .contentShape(Rectangle())
        .onTapGesture {
            focusedField = nil
        }
    }
    
    private var backgroundGradientColors: [Color] {
        colorScheme == .dark ? [Color.black.opacity(0.9), Color(.systemGray6).opacity(0.3)] : [Color(.systemBackground), Color(.systemGray6).opacity(0.5)]
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
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08)
    }
    
    private var borderWidth: CGFloat {
        colorScheme == .dark ? 1.5 : 1.0
    }
    
    private var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.1)
    }
    
    private var adaptiveSystemBackground: Color {
        Color(.systemBackground)
    }

    // MARK: - ViewBuilder Components
    
    private var headerSection: some View {
        VStack(spacing: 8) {  // Reduced from 10
            // Stronger, more aspirational headline
            Text("Join the Next Generation of Clinicians")
                .font(.system(.title, design: .rounded).weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            
            // Benefit-driven subheading with horizontal padding to avoid edge-clipping
            Text("Get personalized simulations, tailored feedback, and smarter case recommendations based on your role.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, 20)
        }
        .padding(.top, 20)  // Reduced from 25
        .padding(.bottom, 10)  // Reduced from 12
    }
    
    private var profilePickerSection: some View {
        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
            ZStack {
                // Background circle (slightly smaller)
                Circle()
                    .fill(colorScheme == .dark ? Color(.systemGray5).opacity(0.8) : Color(.systemGray6))
                    .frame(width: 110, height: 110) // was 120 -> 100
                    .overlay(
                        Circle()
                            .stroke(borderColor, lineWidth: borderWidth)
                    )
                
                // Profile Image or Placeholder
                ZStack {
                    if let profileImage {
                        Image(uiImage: profileImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 48)) 
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 110, height: 110) // match circle size
                .clipShape(Circle())
                
                // Edit Icon Overlay
                ZStack {
                    Circle()
                        .fill(Color.accentColor)
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .bold)) // slightly smaller
                        .foregroundColor(.white)
                }
                .frame(width: 32, height: 32) // was 34 -> 32
                .overlay(
                    Circle()
                        .stroke(adaptiveSystemBackground, lineWidth: 2)
                )
                .offset(x: 34, y: 34)
            }
        }
        .buttonStyle(.plain)
    }
    
    private var fullNameField: some View {
        SignUpTextField(
            text: $fullName,
            prompt: "Full Name",
            systemImageName: "person.fill",
            isFocused: $focusedField,
            focusCase: .fullName,
            colorScheme: colorScheme
        )
        .textContentType(.name)
        .autocapitalization(.words)
        .submitLabel(.next)
        .onSubmit { focusedField = .email }
    }
    
    private var emailField: some View {
        SignUpTextField(
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
        SignUpTextField(
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
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 20, height: 20)
            }
        }
        .textContentType(.newPassword)
        .submitLabel(.next)
        .onSubmit { focusedField = .confirmPassword }
    }
    
    private var confirmPasswordField: some View {
        SignUpTextField(
            text: $confirmPassword,
            isSecure: !isPasswordVisible,
            prompt: "Confirm Password",
            systemImageName: "lock.fill",
            isFocused: $focusedField,
            focusCase: .confirmPassword,
            colorScheme: colorScheme
        )
        .textContentType(.newPassword)
        .submitLabel(.done)
        .onSubmit(performSignUp)
    }
    
    private var rolePicker: some View {
        PremiumRolePicker(
            selectedRole: $selectedRole,
            colorScheme: colorScheme
        )
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
        colorScheme == .dark ? Color.red.opacity(0.15) : Color.red.opacity(0.08)
    }
    
    private var errorBorder: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(Color.red.opacity(0.3), lineWidth: 1)
    }
    
    private var createAccountButton: some View {
        Button(action: performSignUp) {
            HStack(spacing: 12) {
                if isSigningUp {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                } else {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                    
                    Text("Create My Account")
                        .font(.headline.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .foregroundStyle(.white)
            .background(buttonBackgroundGradient)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: buttonShadowColor, radius: 8, y: 4)
            .scaleEffect(isSigningUp ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSigningUp)
        }
        .disabled(isSigningUp || email.isEmpty || password.isEmpty || fullName.isEmpty)
        .opacity((isSigningUp || email.isEmpty || password.isEmpty || fullName.isEmpty) ? 0.7 : 1.0)
    }
    
    private var buttonBackgroundGradient: LinearGradient {
        LinearGradient(
            colors: [Color.accentColor, Color.cyan],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var buttonShadowColor: Color {
        colorScheme == .dark ? Color.accentColor.opacity(0.2) : Color.accentColor.opacity(0.3)
    }
    
    private var signInLink: some View {
        HStack(spacing: 6) {
            Text("Already have an account?")
                .foregroundStyle(.secondary)
            Button("Sign In") {
                dismiss() // Go back to the login screen
            }
            .font(.callout.weight(.semibold))
            .foregroundStyle(Color.accentColor)
        }
        .font(.callout)
    }

    // MARK: - Logic (Copied from your original file)
    
    private func handlePhotoSelection() {
        Task {
            if let data = try? await selectedPhotoItem?.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                tempImageForCropping = image
                isShowingCropper = true
            }
        }
    }
    
    private func performSignUp() {
        // Prevent duplicate submissions
        guard !isSigningUp else { return }
        
        // Client-side validation first — fast feedback.
        guard validateInputs() else { return }
        
        // Haptic feedback acknowledging the action
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        isSigningUp = true
        errorMessage = nil
        hasError = false
        focusedField = nil
        
        Task {
            do {
                try await authService.signUp(fullName: fullName, email: email, password: password)
                
                if let newUser = authService.currentUser {
                    if let image = profileImage,
                       let data = image.jpegData(compressionQuality: 0.8) {
                        let filename = "\(newUser.id).jpg"
                        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
                        try? data.write(to: url)
                        newUser.profileImageFilename = filename
                    }
                    
                    newUser.roleTitle = selectedRole.title
                    
                    try? authService.modelContext.save()
                }
                
            } catch let authError as AuthError {
                await MainActor.run {
                    self.errorMessage = authError.localizedDescription
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        self.hasError = true
                    }
                    // error haptic
                    self.errorHaptic.notificationOccurred(.error)
                    self.isSigningUp = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "An unknown error occurred."
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        self.hasError = true
                    }
                    self.errorHaptic.notificationOccurred(.error)
                    self.isSigningUp = false
                }
            }
        }
    }
    
    /// Validate sign-up inputs locally. Shows immediate UI feedback (shake + haptic) and focuses the offending field.
    private func validateInputs() -> Bool {
        let trimmedName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedConfirm = confirmPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Full name required
        if trimmedName.isEmpty {
            withAnimation {
                self.errorMessage = "Please enter your full name."
                self.hasError = true
            }
            errorHaptic.notificationOccurred(.warning)
            focusedField = .fullName
            return false
        }
        
        // Email required
        if trimmedEmail.isEmpty {
            withAnimation {
                self.errorMessage = "Please enter your email."
                self.hasError = true
            }
            errorHaptic.notificationOccurred(.warning)
            focusedField = .email
            return false
        }
        
        // Basic email format
        let emailPredicate = NSPredicate(format: "SELF MATCHES[c] %@", "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}")
        if !emailPredicate.evaluate(with: trimmedEmail) {
            withAnimation {
                self.errorMessage = "Please enter a valid email address."
                self.hasError = true
            }
            errorHaptic.notificationOccurred(.error)
            focusedField = .email
            return false
        }
        
        // Password required
        if trimmedPassword.isEmpty {
            withAnimation {
                self.errorMessage = "Please enter a password."
                self.hasError = true
            }
            errorHaptic.notificationOccurred(.warning)
            focusedField = .password
            return false
        }
        
        // Minimum password length
        if trimmedPassword.count < 6 {
            withAnimation {
                self.errorMessage = "Password must be at least 6 characters."
                self.hasError = true
            }
            errorHaptic.notificationOccurred(.error)
            focusedField = .password
            return false
        }
        
        // Confirm password matches
        if trimmedConfirm != trimmedPassword {
            withAnimation {
                self.errorMessage = "Passwords do not match."
                self.hasError = true
            }
            errorHaptic.notificationOccurred(.error)
            focusedField = .confirmPassword
            return false
        }
        
        // Success: clear any prior error state
        withAnimation { self.hasError = false }
        self.errorMessage = nil
        return true
    }
    
    private func triggerErrorHaptic() {
        // kept for callers that use it — default to error
        errorHaptic.notificationOccurred(.error)
    }
}

// MARK: - Premium Role Picker (New Component)

struct PremiumRolePicker: View {
    @Binding var selectedRole: UserProfileRole
    var colorScheme: ColorScheme
    
    @State private var isFieldFocused = false
    
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
        isFieldFocused ? Color.accentColor : Color.secondary
    }
    
    var body: some View {
        Menu {
            ForEach(UserProfileRole.allPredefined) { role in
                Button(role.title) {
                    selectedRole = role
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "graduationcap.fill")
                    .foregroundStyle(iconColor)
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 20)
                
                Text(selectedRole.title)
                    .font(.callout)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
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
        }
        .onTapGesture {
            isFieldFocused.toggle()
        }
    }
}

// MARK: - SignUp-specific text field (avoids name collision with LoginView.PremiumTextField)

struct SignUpTextField<TrailingContent: View>: View {
    @Binding var text: String
    var isSecure: Bool = false
    var prompt: String
    var systemImageName: String
    
    @FocusState.Binding var isFocused: SignUpView.Field?
    var focusCase: SignUpView.Field
    var colorScheme: ColorScheme
    
    var trailingContent: () -> TrailingContent
    
    init(
        text: Binding<String>,
        isSecure: Bool = false,
        prompt: String,
        systemImageName: String,
        isFocused: FocusState<SignUpView.Field?>.Binding,
        focusCase: SignUpView.Field,
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

// MARK: - Preview

#Preview("Light Mode") {
    let authService = AuthService(modelContext: try! ModelContainer(for: User.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)).mainContext)
    
    NavigationStack {
        SignUpView()
            .environmentObject(authService)
    }
    .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    let authService = AuthService(modelContext: try! ModelContainer(for: User.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)).mainContext)
    
    NavigationStack {
        SignUpView()
            .environmentObject(authService)
    }
    .preferredColorScheme(.dark)
}