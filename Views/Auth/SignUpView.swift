import SwiftUI
import PhotosUI
import SwiftData
import CoreHaptics

// MARK: - 🌌 CONTEXT ENGINE (Shared Architecture)
// Reusing the same context engine logic for consistency,
// but localizing it here if not shared globally yet.
@MainActor
class SignUpInteractionContext: ObservableObject {
    @Published var intensity: Double = 0.0
    private var lastInputTime: Date = Date()
    
    func registerInteraction() {
        let now = Date()
        let interval = now.timeIntervalSince(lastInputTime)
        lastInputTime = now
        
        let rawIntensity = min(1.0, max(0.0, 1.0 - (interval * 1.5)))
        withAnimation(.interactiveSpring(response: 0.5, dampingFraction: 0.6)) {
            self.intensity = rawIntensity
        }
        
        // Optimized: Reduced decay duration for better performance
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            withAnimation(.easeOut(duration: 0.6)) {
                self?.intensity = 0.0
            }
        }
    }
}

// MARK: - 🏆 MASTER VIEW: SIGN UP
struct SignUpView: View {
    // Backend & Environment
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var context = SignUpInteractionContext()
    
    // Data Model
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var selectedRole: UserProfileRole = .studentMS3
    
    // Profile Assets
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var profileImage: UIImage?
    @State private var tempImageForCropping: UIImage?
    @State private var isShowingCropper = false
    
    // Demographics
    @State private var selectedGender: Gender = .preferNotToSay
    @State private var dateOfBirth = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @State private var provideDOB = false
    @State private var selectedNativeLanguage: NativeLanguage = .english
    
    // UX State
    @State private var currentStep = 0 // 0: Identity, 1: Credentials, 2: Profile
    @State private var isSigningUp = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?
    
    enum Field { case fullName, email, password, confirmPassword }
    
    var body: some View {
        ZStack {
            // Layer 0: Living Atmosphere
            AtmosphericBackground(intensity: context.intensity)
                .ignoresSafeArea()
                .onTapGesture { focusedField = nil }
            
            // Layer 1: Content Flow
            VStack(spacing: 0) {
                // Header Navigation
                HStack {
                    Spacer()
                    
                    // Step Indicator
                    HStack(spacing: 4) {
                        ForEach(0..<3) { step in
                            Capsule()
                                .fill(step == currentStep ? Color.cyan : Color.white.opacity(0.2))
                                .frame(width: step == currentStep ? 24 : 8, height: 4)
                                .animation(.spring, value: currentStep)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
                
                Spacer()
                    .frame(maxHeight: 40) // Reduced spacer to push content up
                
                // Main Interactive Area
                ZStack {
                    switch currentStep {
                    case 0: identityStep
                    case 1: credentialsStep
                    case 2: profileStep
                    default: EmptyView()
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity).combined(with: .scale(scale: 0.9))
                ))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentStep)
                
                Spacer()
                    .frame(maxHeight: 60) // Reduced bottom spacer
                
                // Bottom Action Area
                if errorMessage != nil {
                    Text(errorMessage?.uppercased() ?? "")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.red)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                PrimaryActionButton(
                    title: currentStep == 2 ? "Create Account" : "Next",
                    isLoading: isSigningUp,
                    action: handleNextStep
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark) // Enforce cinematic mode
        .onChange(of: selectedPhotoItem) { handlePhotoSelection() }
        .fullScreenCover(isPresented: $isShowingCropper) {
            ImageCropper(image: $tempImageForCropping) { croppedImage in
                profileImage = croppedImage
                tempImageForCropping = nil
            }
        }
    }
    
    // MARK: - 🎞️ STEP 1: IDENTITY
    var identityStep: some View {
        VStack(alignment: .leading, spacing: 32) {
            Text("Create Your Account")
                .font(.system(size: 48, weight: .black, design: .default))
                .tracking(-1)
                .foregroundStyle(.white)
                .mask(LinearGradient(colors: [.white, .white.opacity(0.5)], startPoint: .top, endPoint: .bottom))
            
            VStack(spacing: 24) {
                FloatingInput(
                    title: "Full Name",
                    text: $fullName,
                    icon: "person.fill",
                    context: context
                )
                .focused($focusedField, equals: .fullName)
                .onSubmit { focusedField = .email }
                
                FloatingInput(
                    title: "Email Address",
                    text: $email,
                    icon: "envelope.fill",
                    context: context
                )
                .focused($focusedField, equals: .email)
                .onSubmit { handleNextStep() }
            }
        }
        .padding(.horizontal, 32)
    }
    
    // MARK: - 🎞️ STEP 2: CREDENTIALS
    var credentialsStep: some View {
        VStack(alignment: .leading, spacing: 32) {
            Text("Set Your Password")
                .font(.system(size: 48, weight: .black, design: .default))
                .tracking(-1)
                .foregroundStyle(.white)
                .mask(LinearGradient(colors: [.white, .white.opacity(0.5)], startPoint: .top, endPoint: .bottom))
            
            VStack(spacing: 24) {
                FloatingInput(
                    title: "Password",
                    text: $password,
                    icon: "lock.fill",
                    isSecure: true,
                    context: context
                )
                .focused($focusedField, equals: .password)
                .onSubmit { focusedField = .confirmPassword }
                
                FloatingInput(
                    title: "Confirm Password",
                    text: $confirmPassword,
                    icon: "lock.shield.fill",
                    isSecure: true,
                    context: context
                )
                .focused($focusedField, equals: .confirmPassword)
                .onSubmit { handleNextStep() }
            }
        }
        .padding(.horizontal, 32)
    }
    
    // MARK: - 🎞️ STEP 3: CLINICAL PROFILE
    var profileStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                Text("Your Profile")
                    .font(.system(size: 48, weight: .black, design: .default))
                    .tracking(-1)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Photo Picker (Holographic)
                HStack {
                    Spacer()
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        ZStack {
                            Circle()
                                .strokeBorder(
                                    AngularGradient(colors: [.cyan, .purple, .blue, .cyan], center: .center),
                                    lineWidth: 2
                                )
                                .background(.ultraThinMaterial, in: Circle())
                                .frame(width: 100, height: 100)
                            
                            if let profileImage {
                                Image(uiImage: profileImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 96, height: 96)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "camera.aperture")
                                    .font(.system(size: 30))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                .frame(width: 110, height: 110)
                                .scaleEffect(isSigningUp ? 1.2 : 1.0)
                                .opacity(isSigningUp ? 0 : 1)
                                .animation(.easeOut(duration: 1).repeatForever(autoreverses: false), value: isSigningUp)
                        }
                    }
                    Spacer()
                }
                
                // Role Picker
                ModernMenuPicker(
                    title: "Role",
                    selection: Binding(get: { selectedRole.title }, set: { _ in }),
                    options: UserProfileRole.allPredefined.map { $0.title },
                    onSelect: { title in
                        if let role = UserProfileRole.allPredefined.first(where: { $0.title == title }) {
                            selectedRole = role
                        }
                    }
                )
                
                // Language Picker
                ModernMenuPicker(
                    title: "Language",
                    selection: Binding(get: { selectedNativeLanguage.displayName }, set: { _ in }),
                    options: NativeLanguage.allCases.map { $0.displayName },
                    onSelect: { name in
                        if let lang = NativeLanguage.allCases.first(where: { $0.displayName == name }) {
                            selectedNativeLanguage = lang
                        }
                    }
                )
                
                // Gender Picker
                ModernMenuPicker(
                    title: "Gender",
                    selection: Binding(get: { selectedGender.rawValue }, set: { _ in }),
                    options: Gender.allCases.map { $0.rawValue },
                    onSelect: { val in
                        if let gender = Gender.allCases.first(where: { $0.rawValue == val }) {
                            selectedGender = gender
                        }
                    }
                )
                
                // DOB Toggle
                Toggle(isOn: $provideDOB.animation()) {
                    Text("Include Date of Birth")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .tint(.cyan)
                .padding(.vertical, 8)
                
                if provideDOB {
                    DatePicker("", selection: $dateOfBirth, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .colorScheme(.dark)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                        )
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 100) // Space for button
        }
    }
    
    // MARK: - 🧠 LOGIC
    
    private func handleNextStep() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        switch currentStep {
        case 0:
            if fullName.isEmpty || email.isEmpty {
                showError("Identity details required")
            } else {
                withAnimation { currentStep = 1 }
            }
        case 1:
            if password.isEmpty || confirmPassword.isEmpty {
                showError("Credentials required")
            } else if password != confirmPassword {
                showError("Passwords do not match")
            } else {
                withAnimation { currentStep = 2 }
            }
        case 2:
            performSignUp()
        default: break
        }
    }
    
    private func showError(_ msg: String) {
        withAnimation { errorMessage = msg }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { errorMessage = nil }
        }
    }
    
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
        guard !isSigningUp else { return }
        isSigningUp = true
        
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
                    newUser.gender = selectedGender
                    if provideDOB { newUser.dateOfBirth = dateOfBirth }
                    newUser.nativeLanguage = selectedNativeLanguage
                    
                    try? authService.modelContext.save()
                }
                
                // Success handled by Auth state change
            } catch {
                await MainActor.run {
                    showError(error.localizedDescription)
                    isSigningUp = false
                }
            }
        }
    }
}

// MARK: - 🎨 COMPONENT: Atmospheric Background (Optimized)
struct AtmosphericBackground: View {
    var intensity: Double // Not used, kept for compatibility
    
    var body: some View {
        // Optimized: Static gradient background with mesh gradient effect
        ZStack {
            // Base color
            Color(red: 0.01, green: 0.015, blue: 0.03)
            
            // Static gradient orbs using GeometryReader for positioning
            GeometryReader { geo in
                ZStack {
                    // Orb 1: Elegant cyan gradient
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 0.15, green: 0.75, blue: 0.85).opacity(0.22),
                                    Color(red: 0.08, green: 0.55, blue: 0.75).opacity(0.14),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 200
                            )
                        )
                        .frame(width: 400, height: 400)
                        .position(x: geo.size.width * 0.5, y: geo.size.height * 0.4)
                    
                    // Orb 2: Rich purple gradient
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 0.55, green: 0.25, blue: 0.85).opacity(0.20),
                                    Color(red: 0.35, green: 0.08, blue: 0.65).opacity(0.12),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 220
                            )
                        )
                        .frame(width: 440, height: 440)
                        .position(x: geo.size.width * 0.7, y: geo.size.height * 0.7)
                    
                    // Orb 3: Sophisticated blue gradient
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 0.25, green: 0.45, blue: 0.85).opacity(0.18),
                                    Color(red: 0.12, green: 0.25, blue: 0.65).opacity(0.10),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 180
                            )
                        )
                        .frame(width: 360, height: 360)
                        .position(x: geo.size.width * 0.3, y: geo.size.height * 0.6)
                    
                    // Orb 4: Warm gold gradient accent
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 0.75, green: 0.65, blue: 0.35).opacity(0.12),
                                    Color(red: 0.55, green: 0.45, blue: 0.15).opacity(0.08),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 160
                            )
                        )
                        .frame(width: 320, height: 320)
                        .position(x: geo.size.width * 0.8, y: geo.size.height * 0.3)
                    
                    // Orb 5: Premium magenta accent
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 0.65, green: 0.20, blue: 0.75).opacity(0.15),
                                    Color(red: 0.45, green: 0.10, blue: 0.55).opacity(0.09),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 190
                            )
                        )
                        .frame(width: 380, height: 380)
                        .position(x: geo.size.width * 0.2, y: geo.size.height * 0.2)
                }
            }
        }
        .blur(radius: 85)
        .ignoresSafeArea()
    }
}

// MARK: - 🎨 COMPONENT: Floating Input
struct FloatingInput: View {
    let title: String
    @Binding var text: String
    let icon: String
    var isSecure: Bool = false
    @ObservedObject var context: SignUpInteractionContext
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(isFocused ? 1 : 0.5))
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(isFocused ? 1 : 0.5))
            }
            
            ZStack(alignment: .bottom) {
                if isSecure {
                    SecureField("", text: $text)
                        .focused($isFocused)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white)
                } else {
                    TextField("", text: $text)
                        .focused($isFocused)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white)
                }
                
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 1)
                
                Rectangle()
                    .fill(Color.cyan)
                    .frame(height: 2)
                    .scaleEffect(x: isFocused ? 1 : 0, anchor: .leading)
                    .animation(.spring(response: 0.3), value: isFocused)
            }
            .padding(.bottom, 8)
        }
        .onChange(of: text) { _, _ in context.registerInteraction() }
    }
}

// MARK: - 🎨 COMPONENT: Modern Menu Picker
struct ModernMenuPicker: View {
    let title: String
    @Binding var selection: String
    let options: [String]
    let onSelect: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
            
            Menu {
                ForEach(options, id: \.self) { option in
                    Button(option) {
                        onSelect(option)
                    }
                }
            } label: {
                HStack {
                    Text(selection)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            }
        }
    }
}

// MARK: - 🎨 COMPONENT: Primary Action Button
struct PrimaryActionButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: .white.opacity(0.2), radius: 20)
                
                if isLoading {
                    ProgressView()
                        .tint(.black)
                } else {
                    HStack {
                        Text(title)
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .tracking(1)
                        
                        Image(systemName: "arrow.right")
                            .font(.caption.weight(.black))
                    }
                    .foregroundStyle(.black)
                }
            }
            .frame(height: 56)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isLoading)
    }
}

// MARK: - 🎨 SCALE BUTTON STYLE
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    SignUpView()
        .environmentObject(AuthService(modelContext: try! ModelContainer(for: User.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)).mainContext))
}
