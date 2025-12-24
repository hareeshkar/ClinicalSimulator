import SwiftUI
import CoreHaptics
import SwiftData

// MARK: - 🔐 FORGOT PASSWORD VIEW
struct ForgotPasswordView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    @StateObject private var context = SignUpInteractionContext()
    
    // Logic State
    @State private var currentStep = 0 // 0: Identify, 1: Reset, 2: Success
    @State private var email = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    @FocusState private var focusedField: Field?
    enum Field { case email, newPassword, confirmPassword }
    
    var body: some View {
        ZStack {
            // Layer 0: Premium Atmospheric Background
            AtmosphericBackground(intensity: context.intensity)
                .ignoresSafeArea()
                .onTapGesture { focusedField = nil }
            
            // Layer 1: Content Flow
            VStack(spacing: 0) {
                // Header
                HStack {
                    Spacer()
                    
                    // Step Indicator (only show for steps 0 and 1)
                    if currentStep < 2 {
                        HStack(spacing: 4) {
                            ForEach(0..<2) { step in
                                Capsule()
                                    .fill(step == currentStep ? Color.cyan : Color.white.opacity(0.2))
                                    .frame(width: step == currentStep ? 24 : 8, height: 4)
                                    .animation(.spring, value: currentStep)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
                
                Spacer()
                
                // Main Interactive Area
                ZStack {
                    switch currentStep {
                    case 0: identityStep
                    case 1: resetStep
                    case 2: successStep
                    default: EmptyView()
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity).combined(with: .scale(scale: 0.9))
                ))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentStep)
                
                Spacer()
                
                // Error & Action Area
                if currentStep < 2 {
                    if let error = errorMessage {
                        Text(error.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.red)
                            .padding(.bottom, 8)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    PrimaryActionButton(
                        title: currentStep == 0 ? "Verify Email" : "Reset Password",
                        isLoading: isLoading,
                        action: handleAction
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - 🕵️ STEP 1: IDENTIFICATION
    var identityStep: some View {
        VStack(alignment: .leading, spacing: 32) {
            Text("Forgot Password?")
                .font(.system(size: 48, weight: .black, design: .default))
                .tracking(-1)
                .foregroundStyle(.white)
                .mask(LinearGradient(colors: [.white, .white.opacity(0.5)], startPoint: .top, endPoint: .bottom))
            
            Text("Enter your email address to reset your password.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 8)
            
            FloatingInput(
                title: "Email Address",
                text: $email,
                icon: "envelope.fill",
                context: context
            )
            .focused($focusedField, equals: .email)
            .onSubmit { handleAction() }
        }
        .padding(.horizontal, 32)
    }
    
    // MARK: - 🔐 STEP 2: RESET
    var resetStep: some View {
        VStack(alignment: .leading, spacing: 32) {
            Text("Set New Password")
                .font(.system(size: 48, weight: .black, design: .default))
                .tracking(-1)
                .foregroundStyle(.white)
                .mask(LinearGradient(colors: [.white, .white.opacity(0.5)], startPoint: .top, endPoint: .bottom))
            
            Text("Create a new password for \(email).")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.bottom, 8)
            
            VStack(spacing: 24) {
                FloatingInput(
                    title: "New Password",
                    text: $newPassword,
                    icon: "lock.fill",
                    isSecure: true,
                    context: context
                )
                .focused($focusedField, equals: .newPassword)
                .onSubmit { focusedField = .confirmPassword }
                
                FloatingInput(
                    title: "Confirm Password",
                    text: $confirmPassword,
                    icon: "lock.shield.fill",
                    isSecure: true,
                    context: context
                )
                .focused($focusedField, equals: .confirmPassword)
                .onSubmit { handleAction() }
            }
        }
        .padding(.horizontal, 32)
    }
    
    // MARK: - ✅ STEP 3: SUCCESS
    var successStep: some View {
        VStack(spacing: 32) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 120, height: 120)
                    .blur(radius: 30)
                
                Circle()
                    .stroke(Color.green.opacity(0.3), lineWidth: 2)
                    .frame(width: 100, height: 100)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.green)
            }
            
            VStack(spacing: 12) {
                Text("Password Reset")
                    .font(.system(size: 32, weight: .black, design: .default))
                    .tracking(-1)
                    .foregroundStyle(.white)
                
                Text("Your password has been successfully updated.\nReturning to login...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 32)
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                dismiss()
            }
        }
    }
    
    // MARK: - 🧠 LOGIC
    
    private func handleAction() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        focusedField = nil
        
        if currentStep == 0 {
            performIdentityCheck()
        } else if currentStep == 1 {
            performPasswordReset()
        }
    }
    
    private func performIdentityCheck() {
        guard !email.isEmpty else {
            showError("Email required")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let exists = try await authService.verifyEmailExists(email)
                
                await MainActor.run {
                    isLoading = false
                    if exists {
                        withAnimation { currentStep = 1 }
                    } else {
                        showError("No account found with this email")
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    showError(error.localizedDescription)
                }
            }
        }
    }
    
    private func performPasswordReset() {
        guard !newPassword.isEmpty, !confirmPassword.isEmpty else {
            showError("Both password fields required")
            return
        }
        
        guard newPassword == confirmPassword else {
            showError("Passwords do not match")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await authService.resetPassword(email: email, newPassword: newPassword)
                
                await MainActor.run {
                    isLoading = false
                    withAnimation { currentStep = 2 }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    showError("Failed to reset password")
                }
            }
        }
    }
    
    private func showError(_ msg: String) {
        withAnimation { errorMessage = msg }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { errorMessage = nil }
        }
    }
}

#Preview {
    ForgotPasswordView()
        .environmentObject(AuthService(modelContext: try! ModelContainer(for: User.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)).mainContext))
}

