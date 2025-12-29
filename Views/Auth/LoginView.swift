import SwiftUI
import CoreHaptics
import Combine

// MARK: - 🧠 CONTEXT ENGINE (Client-Side Intelligence)
/// Observes user interaction patterns to modulate UI physics and aesthetics.
@MainActor
class InteractionContext: ObservableObject {
    @Published var intensity: Double = 0.0 // 0.0 (Calm) -> 1.0 (Focused/Intense)
    @Published var hesitationDetected: Bool = false
    
    private var lastInputTime: Date = Date()
    private var inputIntervals: [TimeInterval] = []
    private var typingTimer: Timer?
    
    func registerInteraction() {
        let now = Date()
        let interval = now.timeIntervalSince(lastInputTime)
        lastInputTime = now
        
        // Analyze rhythm
        inputIntervals.append(interval)
        if inputIntervals.count > 5 { inputIntervals.removeFirst() }
        
        // Calculate velocity (inverse of average interval)
        let avgInterval = inputIntervals.reduce(0, +) / Double(inputIntervals.count)
        let rawIntensity = min(1.0, max(0.0, 1.0 - (avgInterval * 2.0)))
        
        // ✅ FIX: Reduce animation frequency - only update every 300ms
        let timeSinceLastUpdate = now.timeIntervalSince(lastInputTime)
        guard timeSinceLastUpdate > 0.3 else { return }
        
        // Smoothly interpolate intensity - reduced animation complexity
        self.intensity = rawIntensity
        self.hesitationDetected = false
        
        // Reset hesitation timer
        typingTimer?.invalidate()
        typingTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.intensity = 0.0
                self?.hesitationDetected = true
            }
        }
    }
}

// MARK: - 🏆 MASTER VIEW
struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var context = InteractionContext()
    
    // Inputs
    @State private var email = ""
    @State private var password = ""
    @State private var rememberMe = false
    @State private var isLoggingIn = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    // Animation States
    @State private var appearSequence = false
    @State private var isShowingForgotPassword = false
    @FocusState private var focusedField: Field?
    
    enum Field { case email, password }
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    // Layer 0: Intelligent Ambient World
                    CinematicBackground(intensity: context.intensity)
                        .ignoresSafeArea()
                    
                    // Layer 1: Content in ScrollView for keyboard handling
                    ScrollView {
                        VStack(spacing: 0) {
                            Spacer()
                                .frame(height: geometry.size.height * 0.15)
                            
                            // Editorial Header
                            VStack(alignment: .leading, spacing: -5) {
                                Text("Clinical")
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .tracking(8)
                                    .opacity(0.6)
                                    .offset(x: appearSequence ? 0 : -20)
                                    .opacity(appearSequence ? 1 : 0)
                                
                                Text("Simulator")
                                    .font(.system(size: 42, weight: .black, design: .default))
                                    .tracking(-1)
                                    .foregroundStyle(.white)
                                    .mask(
                                        LinearGradient(
                                            colors: [.white, .white.opacity(0.7)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .scaleEffect(appearSequence ? 1 : 0.9)
                                    .opacity(appearSequence ? 1 : 0)
                                    .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1), value: appearSequence)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 32)
                            .padding(.bottom, 40)
                            
                            // Intelligent Form Cluster
                            VStack(spacing: 24) {
                                
                                // Email Input
                                LiquidTextField(
                                    title: "Email",
                                    text: $email,
                                    icon: "plus.viewfinder",
                                    isSecure: false,
                                    context: context,
                                    isFocused: focusedField == .email
                                )
                                .focused($focusedField, equals: .email)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .password }
                                
                                // Password Input
                                LiquidTextField(
                                    title: "Password",
                                    text: $password,
                                    icon: "lock.square.stack.fill",
                                    isSecure: true,
                                    context: context,
                                    isFocused: focusedField == .password
                                )
                                .focused($focusedField, equals: .password)
                                .submitLabel(.go)
                                .onSubmit(performLogin)
                                
                                HStack {
            // Remember Me
            Button(action: {
                rememberMe.toggle()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: rememberMe ? "checkmark.square.fill" : "square")
                        .foregroundColor(rememberMe ? .cyan : .white.opacity(0.6))
                        .font(.system(size: 16))

                    Text("Remember Me")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }

            Spacer()

            // Forgot Password
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                isShowingForgotPassword = true
            }) {
                Text("Forgot Password?")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.cyan)
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)

                                
                                // ✅ FIXED: Error State with fixed height to prevent layout shift
                                ZStack {
                                    if let error = errorMessage {
                                        HStack(spacing: 12) {
                                            Rectangle()
                                                .fill(Color.red)
                                                .frame(width: 2)
                                            Text(error.uppercased())
                                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                .foregroundStyle(.red)
                                                .lineLimit(2)
                                                .minimumScaleFactor(0.8)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.leading, 4)
                                        .transition(.opacity)
                                    }
                                }
                                .frame(height: errorMessage != nil ? 30 : 0)
                                .animation(.easeInOut(duration: 0.2), value: errorMessage)
                                
                                // Action Button
                                MagneticButton(
                                    title: "Sign In",
                                    isLoading: isLoggingIn,
                                    intensity: context.intensity,
                                    action: performLogin
                                )
                                .padding(.top, 16)
                                
                                // Footer Link
                                HStack {
                                    Text("Don't have an account?")
                                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.4))
                                    
                                    NavigationLink {
                                        SignUpView()
                                    } label: {
                                        Text("Sign Up")
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .foregroundStyle(.white)
                                            .underline()
                                    }
                                }
                                .padding(.top, 24)
                            }
                            .padding(.horizontal, 24)
                            .offset(y: appearSequence ? 0 : 50)
                            .opacity(appearSequence ? 1 : 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2), value: appearSequence)
                            
                            Spacer()
                                .frame(height: 40)
                        }
                        .frame(minHeight: geometry.size.height)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
                .onAppear {
                    // Sequence the entrance
                    withAnimation { appearSequence = true }
                }
                // Tap background to dismiss keyboard
                .onTapGesture {
                    focusedField = nil
                }
            }
            .sheet(isPresented: $isShowingForgotPassword) {
                ForgotPasswordView()
            }
            .dismissKeyboardOnTap()
            .onDisappear {
                focusedField = nil
            }
        }
    }
    
    // MARK: - LOGIC
    private func performLogin() {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        
        guard !email.isEmpty, !password.isEmpty else {
            withAnimation { errorMessage = "Inputs Required" }
            return
        }
        
        isLoggingIn = true
        errorMessage = nil
        
        Task {
            do {
                try await authService.login(email: email, password: password, rememberMe: rememberMe)
                // Success is handled by ContentView switching tabs
            } catch {
                await MainActor.run {
                    isLoggingIn = false
                    withAnimation {
                        errorMessage = error.localizedDescription
                    }
                    // Error Haptic
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }
}

// MARK: - 🎨 COMPONENT: Cinematic Background (Optimized)
struct CinematicBackground: View {
    var intensity: Double // Not used, kept for compatibility
    
    var body: some View {
        // ✅ RESTORED: Beautiful gradient background with performance optimization
        ZStack {
            // Base color
            Color(red: 0.02, green: 0.03, blue: 0.07)
            
            // Static gradient orbs using GeometryReader for positioning
            GeometryReader { geo in
                ZStack {
                    // Orb 1: Sophisticated cyan gradient
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 0.2, green: 0.8, blue: 0.9).opacity(0.19),
                                    Color(red: 0.1, green: 0.6, blue: 0.8).opacity(0.13),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 150
                            )
                        )
                        .frame(width: 300, height: 300)
                        .position(x: geo.size.width * 0.5, y: geo.size.height * 0.4)
                    
                    // Orb 2: Luxury purple gradient
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 0.6, green: 0.3, blue: 0.9).opacity(0.17),
                                    Color(red: 0.4, green: 0.1, blue: 0.7).opacity(0.10),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 180
                            )
                        )
                        .frame(width: 360, height: 360)
                        .position(x: geo.size.width * 0.8, y: geo.size.height * 0.8)
                    
                    // Orb 3: Refined blue gradient
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 0.3, green: 0.5, blue: 0.9).opacity(0.15),
                                    Color(red: 0.1, green: 0.3, blue: 0.8).opacity(0.08),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 170
                            )
                        )
                        .frame(width: 340, height: 340)
                        .position(x: geo.size.width * 0.3, y: geo.size.height * 0.6)
                    
                    // Orb 4: Warm gold gradient accent
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 0.8, green: 0.7, blue: 0.4).opacity(0.10),
                                    Color(red: 0.6, green: 0.5, blue: 0.2).opacity(0.06),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 140
                            )
                        )
                        .frame(width: 280, height: 280)
                        .position(x: geo.size.width * 0.7, y: geo.size.height * 0.3)
                }
            }
        }
        .blur(radius: 80)
        .ignoresSafeArea()
    }
}

// MARK: - 🎨 COMPONENT: Liquid Text Field
struct LiquidTextField: View {
    let title: String
    @Binding var text: String
    let icon: String
    let isSecure: Bool
    @ObservedObject var context: InteractionContext
    var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Minimalist Label
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(2)
            }
            .foregroundStyle(isFocused ? .white : .white.opacity(0.4))
            .animation(.easeInOut(duration: 0.2), value: isFocused)
            
            ZStack(alignment: .bottom) {
                // Input Area
                Group {
                    if isSecure {
                        SecureField("", text: $text)
                    } else {
                        TextField("", text: $text)
                    }
                }
                .font(.system(size: 18, weight: .medium, design: .default))
                .foregroundStyle(.white)
                .tint(.cyan)
                .padding(.bottom, 8)
                // ✅ UPDATED: iOS 17/18+ syntax (Two parameters: oldValue, newValue)
                // We utilize the text change to trigger the context logic regardless of value
                .onChange(of: text) { _, _ in
                    context.registerInteraction() // 🧠 Feed the AI Brain
                }
                
                // Animated Underline
                ZStack(alignment: .leading) {
                    // Base line
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 1)
                    
                    // Active line (Width responds to focus, Glow responds to Intensity)
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.cyan, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: isFocused ? 2 : 1)
                        .frame(maxWidth: isFocused ? .infinity : 0)
                        .shadow(color: .cyan, radius: isFocused ? 4 : 0)
                }
            }
        }
        .scaleEffect(isFocused ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
    }
}

// MARK: - 🎨 COMPONENT: Magnetic Button
struct MagneticButton: View {
    let title: String
    let isLoading: Bool
    let intensity: Double
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Dynamic Background
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: isLoading ? [.gray] : [.white, .white.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white, lineWidth: 1)
                    )
                    .shadow(color: .white.opacity(0.2), radius: 20, x: 0, y: 0)
                
                HStack(spacing: 12) {
                    if isLoading {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Text(title)
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .tracking(2)
                            .foregroundStyle(.black)
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.black)
                            .offset(x: isPressed ? 5 : 0) // Micro-interaction
                    }
                }
            }
            .frame(height: 56)
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(MagneticButtonStyle(isPressed: $isPressed))
    }
}

struct MagneticButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            // ✅ UPDATED: iOS 17/18+ syntax
            .onChange(of: configuration.isPressed) { _, newValue in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isPressed = newValue
                }
            }
    }
}

