import SwiftUI
import CoreHaptics
import SwiftData

// MARK: - 🔐 FORGOT PASSWORD VIEW (Firebase Email Reset)
struct ForgotPasswordView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    @StateObject private var context = SignUpInteractionContext()
    
    // Logic State - Simplified for Firebase email reset flow
    @State private var currentStep = 0 // 0: Enter Email, 1: Success (email sent)
    @State private var email = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    @FocusState private var focusedField: Field?
    enum Field { case email }
    
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
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(12)
                            .background(Circle().fill(.ultraThinMaterial))
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
                
                Spacer()
                
                // Main Interactive Area
                ZStack {
                    switch currentStep {
                    case 0: emailStep
                    case 1: successStep
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
                if currentStep == 0 {
                    if let error = errorMessage {
                        Text(error.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.red)
                            .padding(.bottom, 8)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    PrimaryActionButton(
                        title: "Send Reset Link",
                        isLoading: isLoading,
                        action: sendPasswordResetEmail
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - 📧 STEP 1: ENTER EMAIL
    var emailStep: some View {
        VStack(alignment: .leading, spacing: 32) {
            Text("Forgot Password?")
                .font(.system(size: 48, weight: .black, design: .default))
                .tracking(-1)
                .foregroundStyle(.white)
                .mask(LinearGradient(colors: [.white, .white.opacity(0.5)], startPoint: .top, endPoint: .bottom))
            
            Text("Enter your email address and we'll send you a link to reset your password.")
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
            .onSubmit { sendPasswordResetEmail() }
        }
        .padding(.horizontal, 32)
    }
    
    // MARK: - ✅ STEP 2: SUCCESS (Email Sent)
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
                
                Image(systemName: "envelope.badge.shield.half.filled")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.green)
            }
            
            VStack(spacing: 12) {
                Text("Check Your Email")
                    .font(.system(size: 32, weight: .black, design: .default))
                    .tracking(-1)
                    .foregroundStyle(.white)
                
                Text("We've sent a password reset link to\n\(email)\n\nCheck your inbox and follow the link to reset your password.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            
            Button(action: { dismiss() }) {
                Text("Back to Login")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(.cyan)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 32)
                    .background(
                        Capsule()
                            .stroke(Color.cyan.opacity(0.5), lineWidth: 1)
                    )
            }
            .padding(.top, 16)
        }
        .padding(.horizontal, 32)
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
    
    // MARK: - 🧠 LOGIC
    
    private func sendPasswordResetEmail() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        focusedField = nil
        
        guard !email.isEmpty else {
            showError("Email required")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await authService.sendPasswordResetEmail(to: email)
                
                await MainActor.run {
                    isLoading = false
                    withAnimation { currentStep = 1 }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    showError(error.localizedDescription)
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

