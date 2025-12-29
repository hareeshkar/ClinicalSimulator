import SwiftUI
import UIKit
import CoreHaptics

// MARK: - 🎨 DOMAIN-LED DESIGN TOKENS
private enum ClinicalTheme {
    static let patientBubble = Color(.secondarySystemBackground)
    static let studentBubble = Color.blue // Medical Blue
    static let attendingGlass = Material.regular
    static let attendingBorder = Color.blue.opacity(0.2)
    static let attendingText = Color.primary
    
    static let background = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark 
            ? UIColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 1.0) 
            : UIColor(red: 0.96, green: 0.97, blue: 0.99, alpha: 1.0)
    })
}

struct ConversationTabView: View {
    // MARK: - Properties
    @ObservedObject var viewModel: ChatViewModel
    
    // UI State
    @State private var messageText = ""
    @State private var showHintSheet = false
    @State private var hintContent: String = ""
    @State private var isFetchingHint = false
    @FocusState private var isInputFocused: Bool
    
    // Animation properties
    @State private var showScrollButton = false
    
    // MARK: - Body
    var body: some View {
        ZStack(alignment: .bottom) {
            // Layer 1: Ambient Clinical Background
            ClinicalTheme.background.ignoresSafeArea()
            
            // Layer 2: The Encounter Transcript
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 20) {
                        // Top Spacing
                        Color.clear.frame(height: 20)
                        
                        // Session Start Indicator
                        EncounterStartMarker(date: viewModel.session.messages.first?.timestamp ?? Date())
                        
                        // Messages
                        ForEach(viewModel.messages) { message in
                            ClinicalMessageRow(message: message)
                                .id(message.id)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .bottomLeading)),
                                    removal: .opacity
                                ))
                        }
                        
                        // Live Typing Indicator
                        if viewModel.isLoading {
                            ClinicalTypingIndicator()
                                .id("typingIndicator")
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                        
                        // Bottom Spacing for Input Bar
                        Color.clear.frame(height: 90)
                            .id("bottomSpacer")
                    }
                    .padding(.horizontal, 16)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: viewModel.messages.count) { _ in smoothScrollToBottom(proxy: proxy) }
                .onChange(of: viewModel.isLoading) { if viewModel.isLoading { smoothScrollToBottom(proxy: proxy) } }
            }
            
            // Layer 3: Interaction Zone (Input + Consult)
            VStack(spacing: 0) {
                // The Consult FAB (Floating above input)
                HStack {
                    Spacer()
                    ConsultationButton(
                        isLoading: isFetchingHint,
                        action: requestAttendingConsult
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                
                // The Precision Input Bar
                PrecisionInputBar(
                    text: $messageText,
                    isFocused: $isInputFocused,
                    isLoading: viewModel.isLoading,
                    onSend: {
                        viewModel.sendMessage(messageText)
                        messageText = ""
                    }
                )
            }
        }
        .dismissKeyboardOnTap()
        // Hint Overlay Sheet
        .sheet(isPresented: $showHintSheet) {
            ConsultationSheet(
                content: hintContent,
                isLoading: $isFetchingHint,
                onDismiss: { showHintSheet = false },
                onNewHint: requestAnotherHint
            )
            .presentationDetents([.height(400), .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Material.ultraThin)
        }
    }
    
    // MARK: - Logic
    
    private func smoothScrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if viewModel.isLoading {
                proxy.scrollTo("typingIndicator", anchor: .bottom)
            } else if let lastId = viewModel.messages.last?.id {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        }
    }
    
    private func requestAttendingConsult() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        isFetchingHint = true
        showHintSheet = true
        
        Task {
            do {
                let hint = try await viewModel.getHintForPanel(isSameSection: false)
                await MainActor.run {
                    self.hintContent = hint
                    self.isFetchingHint = false
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    self.hintContent = "Review the vitals and chief complaint. What physiological process links them?"
                    self.isFetchingHint = false
                }
            }
        }
    }
    
    private func requestAnotherHint() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        isFetchingHint = true
        
        Task {
            do {
                let hint = try await viewModel.getHintForPanel(isSameSection: true)
                await MainActor.run {
                    withAnimation {
                        self.hintContent = hint
                        self.isFetchingHint = false
                    }
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            } catch {
                self.isFetchingHint = false
            }
        }
    }
}

// MARK: - 📨 COMPONENT: CLINICAL MESSAGE ROW
/// Handles the visual branching between Student, Patient, and Attending messages.
struct ClinicalMessageRow: View {
    let message: ConversationMessage
    
    private var isStudent: Bool { message.sender == "student" }
    private var isAttending: Bool { message.sender == "attending" }
    private var isPatient: Bool { message.sender == "patient" }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            
            // 1. Patient Avatar (Left side only)
            if isPatient {
                Circle()
                    .fill(ClinicalTheme.studentBubble.opacity(0.1))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "person.fill.viewfinder")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(ClinicalTheme.studentBubble)
                    )
                    .transition(.scale)
            } else if isStudent || isAttending {
                Spacer(minLength: 40)
            }
            
            // 2. Message Content
            VStack(alignment: isStudent ? .trailing : .leading, spacing: 4) {
                
                // Special visual treatment for Attending
                if isAttending {
                    AttendingPearlCard(content: message.content, timestamp: message.timestamp)
                } else {
                    // Standard clinical dialogue bubbles
                    VStack(alignment: isStudent ? .trailing : .leading, spacing: 4) {
                        Text(LocalizedStringKey(message.content))
                            .font(.system(size: 16, weight: isStudent ? .medium : .regular))
                            .foregroundColor(isStudent ? .white : .primary)
                            .lineSpacing(4)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                isStudent
                                ? ClinicalTheme.studentBubble
                                : ClinicalTheme.patientBubble
                            )
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: 18,
                                    style: .continuous
                                )
                            )
                            .clipShape(
                                SpeechBubbleShape(direction: isStudent ? .right : .left)
                            )
                            .shadow(
                                color: Color.black.opacity(isStudent ? 0.12 : 0.04),
                                radius: 8, x: 0, y: 4
                            )
                        
                        // Timestamp (Subtle)
                        Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary.opacity(0.5))
                            .padding(.horizontal, 8)
                    }
                }
            }
            
            // 3. Student Avatar (Right side only)
            if isStudent {
                // Cached avatar view for performance
                CachedStudentAvatar(size: 40)
            } else if isPatient || isAttending {
                Spacer(minLength: 40)
            }
        }
    }
}

// MARK: - 🎓 COMPONENT: ATTENDING PEARL CARD
/// Replaces the "bubble" with a high-fidelity glass card for educational content.
struct AttendingPearlCard: View {
    let content: String
    let timestamp: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(ClinicalTheme.studentBubble.opacity(0.1))
                        .frame(width: 28, height: 28)
                    
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(ClinicalTheme.studentBubble)
                }
                
                Text("ATTENDING PHYSICIAN")
                    .font(.system(size: 10, weight: .black))
                    .tracking(1.2)
                    .foregroundStyle(ClinicalTheme.studentBubble)
                
                Spacer()
                
                Text(timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)
            
            // Content
            Text(LocalizedStringKey(content))
                .font(.system(size: 15, weight: .medium, design: .serif)) // Serif for academic authority
                .foregroundStyle(.primary)
                .lineSpacing(6)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .fixedSize(horizontal: false, vertical: true)
        }
        .background(
            ZStack {
                ClinicalTheme.patientBubble
                ClinicalTheme.studentBubble.opacity(0.03)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(ClinicalTheme.studentBubble.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 5)
        .frame(maxWidth: 320, alignment: .leading)
    }
}

// MARK: - 🧪 COMPONENT: CLINICAL TYPING INDICATOR
struct ClinicalTypingIndicator: View {
    @State private var phase: Double = 0
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            Circle()
                .fill(ClinicalTheme.studentBubble.opacity(0.1))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "person.fill.viewfinder")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(ClinicalTheme.studentBubble)
                )
            
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(ClinicalTheme.studentBubble.opacity(0.4))
                        .frame(width: 6, height: 6)
                        .scaleEffect(phase == Double(i) ? 1.3 : 0.8)
                        .opacity(phase == Double(i) ? 1.0 : 0.4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(ClinicalTheme.patientBubble)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .clipShape(SpeechBubbleShape(direction: .left))
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
            
            Spacer()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                phase = 2.0
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 🎤 COMPONENT: PRECISION INPUT BAR
struct PrecisionInputBar: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let isLoading: Bool
    let onSend: () -> Void
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            
            // Text Entry
            TextField("Interview patient or document findings...", text: $text, axis: .vertical)
                .font(.system(size: 16))
                .focused(isFocused)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.regularMaterial) // Glass background
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(isFocused.wrappedValue ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 1)
                )
                .frame(minHeight: 44)
                .animation(.spring, value: isFocused.wrappedValue)
            
            // Send Button
            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onSend()
            }) {
                ZStack {
                    Circle()
                        .fill(text.isEmpty ? Color.gray.opacity(0.2) : Color.blue)
                        .frame(width: 44, height: 44)
                    
                    if isLoading {
                        ProgressView()
                            .tint(text.isEmpty ? .secondary : .white)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(text.isEmpty ? .secondary : .white)
                            .rotationEffect(.degrees(text.isEmpty ? -45 : 0))
                    }
                }
            }
            .disabled(text.isEmpty || isLoading)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: text.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(
            Material.bar // Use navigation bar material for background
        )
    }
}

// MARK: - 🩺 COMPONENT: CONSULTATION FAB (Floating Action Button)
struct ConsultationButton: View {
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(.indigo)
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.indigo)
                }
                
                Text("REQUEST GUIDANCE")
                    .font(.system(size: 11, weight: .bold, design: .default))
                    .foregroundStyle(.indigo)
                    .tracking(0.5)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial)
            .background(Color.indigo.opacity(0.05))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.indigo.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Color.indigo.opacity(0.1), radius: 8, x: 0, y: 4)
        }
        .scaleEffect(isLoading ? 0.98 : 1.0)
        .animation(.spring, value: isLoading)
    }
}

// MARK: - 📔 COMPONENT: CONSULTATION SHEET CONTENT
struct ConsultationSheet: View {
    let content: String
    @Binding var isLoading: Bool
    let onDismiss: () -> Void
    let onNewHint: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Analyzing vitals & history...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    Spacer().frame(height: 8) // Padding after drag handler
                    
                    Label("Clinical Insight", systemImage: "stethoscope")
                        .font(.title3.bold())
                        .foregroundStyle(.indigo)
                    
                    Text(content)
                        .font(.system(size: 18, design: .serif))
                        .lineSpacing(6)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Button(action: onNewHint) {
                            Label("Another Insight", systemImage: "arrow.triangle.2.circlepath")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.indigo.opacity(0.1))
                                .foregroundStyle(.indigo)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        Button(action: onDismiss) {
                            Text("Continue")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.secondary.opacity(0.1))
                                .foregroundStyle(.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
            }
        }
    }
}

// MARK: - 🧱 COMPONENT: SESSION MARKER
struct EncounterStartMarker: View {
    let date: Date
    
    var body: some View {
        HStack {
            Rectangle().frame(height: 1).foregroundStyle(.secondary.opacity(0.2))
            Text("PATIENT ASSESSMENT BEGUN • \(date.formatted(date: .omitted, time: .shortened))")
                .font(.system(size: 10, weight: .medium, design: .default))
                .foregroundStyle(.secondary)
            Rectangle().frame(height: 1).foregroundStyle(.secondary.opacity(0.2))
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

// MARK: - 🎨 HELPER: SPEECH BUBBLE SHAPE
/// Adds a subtle corner curve adjustment to the message bubble based on sender direction
struct SpeechBubbleShape: Shape {
    enum Direction { case left, right }
    let direction: Direction
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: [
                .topLeft,
                .topRight,
                direction == .left ? .bottomRight : .bottomLeft,
                // The "tail" corner is slightly sharper (4px radius instead of 20)
                // This replaces the cartoony triangle tail with a modern "sent" shape
            ],
            cornerRadii: CGSize(width: 20, height: 20)
        )
        return Path(path.cgPath)
    }
}

// MARK: - 🎭 CACHED STUDENT AVATAR
/// Performance-optimized avatar that doesn't re-render for every message.
///
/// Why this is Equatable:
/// - `AnimatedAvatarView` uses a `TimelineView` which schedules updates.
/// - When used inside a `ForEach` chat list, creating a Timeline for every
///   message would spawn many update events and cause high CPU and battery use.
/// - By wrapping it in `CachedStudentAvatar: Equatable` and only comparing
///   `size`, SwiftUI avoids re-evaluating the avatar body for unchanged rows
///   (no new Timeline creation), dramatically reducing churn and improving
///   scroll performance and battery life.
struct CachedStudentAvatar: View, Equatable {
    let size: CGFloat

    // Only re-render if the size changes
    static func == (lhs: CachedStudentAvatar, rhs: CachedStudentAvatar) -> Bool {
        lhs.size == rhs.size
    }

    var body: some View {
        AnimatedAvatarView(isBirthday: false, size: size)
    }
}