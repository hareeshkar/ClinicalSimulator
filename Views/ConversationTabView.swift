import SwiftUI
import UIKit

struct ConversationTabView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var messageText = ""
    @State private var isHintPanelVisible = false
    @State private var hintMessage: String = ""
    @State private var isHintLoading = false
    @State private var isSameSection = false

    private var floatingHintButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                // Floating Hint Button
                Button(action: isHintPanelVisible ? dismissHintPanel : requestHint) {
                    VStack(spacing: 4) {
                        Image(systemName: isHintPanelVisible ? "xmark" : "brain.head.profile")
                            .font(.system(size: 20, weight: .semibold))
                        Text(isHintPanelVisible ? "Close" : "Hint")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle((viewModel.isLoading || isHintLoading) ? .gray : .indigo)
                    .frame(width: 60, height: 60)
                    .background(
                        (viewModel.isLoading || isHintLoading)
                            ? Color.gray.opacity(0.1)
                            : Color.indigo.opacity(0.15),
                        in: Circle()
                    )
                    .overlay(
                        Circle()
                            .stroke((viewModel.isLoading || isHintLoading) ? Color.gray.opacity(0.3) : Color.indigo.opacity(0.4), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                .disabled(viewModel.isLoading || isHintLoading)
                .padding(.trailing, 16)
                .padding(.bottom, 80) // Position above the input bar
            }
        }
        .ignoresSafeArea(.keyboard) // Ensure button stays visible when keyboard is up
    }

    private var hintPanelOverlay: some View {
        Group {
            if isHintPanelVisible {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        HintPanelView(
                            hintMessage: $hintMessage,
                            isLoading: $isHintLoading,
                            onDismiss: dismissHintPanel,
                            onRequestAnotherHint: requestAnotherHint
                        )
                        .padding(.trailing, 16)
                        .padding(.bottom, 100) // Position above the hint button
                        Spacer()
                    }
                    Spacer()
                }
                .background(Color.black.opacity(0.3).ignoresSafeArea())
                .onTapGesture {
                    dismissHintPanel()
                }
                .transition(.opacity)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.messages) { message in
                            MessageBubbleView(message: message)
                                .id(message.id)
                        }

                        if viewModel.isLoading {
                            TypingIndicatorView()
                                .id("typingIndicator")
                        }
                    }
                    .padding(.vertical)
                    .padding(.horizontal)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: viewModel.messages.count) { _ in scrollToBottom(proxy: proxy) }
                .onChange(of: viewModel.isLoading) {
                    if viewModel.isLoading { scrollToBottom(proxy: proxy) }
                }
            }

            ChatInputBar(messageText: $messageText, viewModel: viewModel)
        }
        .background(Color(.systemBackground).ignoresSafeArea(.container, edges: .bottom))
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .overlay(floatingHintButton)
        .overlay(hintPanelOverlay)
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        let scrollTarget: UUID? = viewModel.messages.last?.id
        if let id = scrollTarget {
             withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                proxy.scrollTo(id, anchor: .bottom)
             }
        } else if viewModel.isLoading {
             withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                proxy.scrollTo("typingIndicator", anchor: .bottom)
             }
        }
    }
    
    private func requestHint() {
        // Haptic feedback for button press
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        isHintLoading = true
        hintMessage = ""
        isSameSection = false // Reset for new hint request
        
        // Get hint without adding to main messages
        Task {
            do {
                let hint = try await viewModel.getHintForPanel(isSameSection: false)
                
                await MainActor.run {
                    hintMessage = hint
                    isHintLoading = false
                    isHintPanelVisible = true
                    
                    // Haptic feedback for successful hint delivery
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
            } catch {
                print("❌ Failed to get attending hint: \(error.localizedDescription)")
                await MainActor.run {
                    hintMessage = "Take a step back and review the vital signs systematically. What patterns stand out?"
                    isHintLoading = false
                    isHintPanelVisible = true
                }
            }
        }
    }
    
    private func dismissHintPanel() {
        withAnimation(.easeOut(duration: 0.2)) {
            isHintPanelVisible = false
        }
        hintMessage = ""
        isSameSection = false // Reset when panel is dismissed
    }
    
    private func requestAnotherHint() {
        // Haptic feedback for button press
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        isHintLoading = true
        hintMessage = ""
        isSameSection = true // Indicate this is another hint on the same section
        
        // Get another hint
        Task {
            do {
                let hint = try await viewModel.getHintForPanel(isSameSection: true)
                
                await MainActor.run {
                    hintMessage = hint
                    isHintLoading = false
                    
                    // Haptic feedback for successful hint delivery
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
            } catch {
                print("❌ Failed to get another attending hint: \(error.localizedDescription)")
                await MainActor.run {
                    hintMessage = "Consider the patient's chief complaint and review the physical exam findings systematically."
                    isHintLoading = false
                }
            }
        }
    }
}

struct AvatarView: View {
    let sender: String
    private var isStudent: Bool { sender == "student" }
    private var isAttending: Bool { sender == "attending" }
    
    @State private var profileImage: UIImage?
    
    // ✅ Get the current user from the environment
    @Environment(User.self) private var currentUser
    
    var body: some View {
        ZStack {
            Circle().fill(Color(.systemBackground))
            
            if isStudent, let image = profileImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                // ✅ Use the same logic as ProfileAvatarView for consistency
                if isStudent {
                    Text(currentUser.fullName.prefix(1))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                } else if isAttending {
                    // ✅ NEW: Distinctive icon for attending physician hints
                    Image(systemName: "stethoscope.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.indigo)
                        .symbolRenderingMode(.hierarchical)
                } else {
                    Image(systemName: "sparkle")
                        .font(.system(size: 16))
                        .foregroundColor(Color.purple)
                        .symbolVariant(.fill)
                }
            }
        }
        .frame(width: 36, height: 36)
        .background(.ultraThinMaterial)
        .clipShape(Circle())
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .onAppear(perform: loadProfileImage)
        .onReceive(NotificationCenter.default.publisher(for: .profileImageDidChange)) { _ in
            loadProfileImage()
        }
    }
    
    // ✅ --- REWORKED loadProfileImage ---
    private func loadProfileImage() {
        if isStudent {
            guard let filename = currentUser.profileImageFilename, !filename.isEmpty else {
                self.profileImage = nil
                return
            }
            
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(filename)
                
            if let data = try? Data(contentsOf: url) {
                self.profileImage = UIImage(data: data)
            } else {
                self.profileImage = nil
            }
        }
    }
}

struct MessageBubbleView: View {
    let message: ConversationMessage
    private var isStudent: Bool { message.sender == "student" }
    private var isAttending: Bool { message.sender == "attending" }

    private var messageBackground: some View {
        Group {
            if isStudent {
                Color.accentColor
            } else if isAttending {
                LinearGradient(
                    colors: [Color.indigo.opacity(0.12), Color.purple.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                Color(.secondarySystemBackground)
            }
        }
    }

    private var attendingOverlay: some View {
        Group {
            if isAttending {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.indigo.opacity(0.6), Color.purple.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // ✅ NEW: Add "Attending Physician" label for hint messages
            if isAttending {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.indigo)
                    Text("Attending Physician")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.indigo)
                }
                .padding(.leading, 46)
            }
            
            HStack(alignment: .bottom, spacing: 10) {
                if isStudent {
                    Spacer(minLength: 40)
                } else {
                    AvatarView(sender: message.sender)
                }

                VStack(alignment: isStudent ? .trailing : .leading, spacing: 4) {
                    Text(message.content.trimmingCharacters(in: .whitespacesAndNewlines))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(messageBackground)
                        .overlay(attendingOverlay)
                        .clipShape(BubbleShape(isFromCurrentUser: isStudent))
                        .foregroundColor(isStudent ? .white : .primary)
                        .shadow(
                            color: isAttending ? Color.indigo.opacity(0.2) : Color.black.opacity(0.1),
                            radius: isAttending ? 8 : 5,
                            x: 0,
                            y: isAttending ? 4 : 2
                        )

                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                }
                .frame(maxWidth: .infinity, alignment: isStudent ? .trailing : .leading)

                if isStudent {
                    AvatarView(sender: message.sender)
                } else {
                    Spacer(minLength: 40)
                }
            }
        }
        .padding(.vertical, 4)
        .transition(.scale(scale: 0.8, anchor: isStudent ? .bottomTrailing : .bottomLeading).combined(with: .opacity))
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: message.id)
    }
}

struct TypingIndicatorView: View {
    @State private var dotScales: [CGFloat] = [0.5, 0.5, 0.5]

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            AvatarView(sender: "patient")

            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .frame(width: 8, height: 8)
                        .scaleEffect(dotScales[index])
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))
            .clipShape(BubbleShape(isFromCurrentUser: false))
            .foregroundColor(.secondary)

            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .onAppear {
            let animation = Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true)
            withAnimation(animation) { dotScales[0] = 1.0 }
            withAnimation(animation.delay(0.2)) { dotScales[1] = 1.0 }
            withAnimation(animation.delay(0.4)) { dotScales[2] = 1.0 }
        }
    }
}

struct ChatInputBar: View {
    @Binding var messageText: String
    @ObservedObject var viewModel: ChatViewModel
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("Ask a question...", text: $messageText, axis: .vertical)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(minHeight: 44)
                .lineLimit(5)
                .background(Color(.systemGray6))
                .clipShape(Capsule())
                .focused($isTextFieldFocused)

            Button(action: sendMessage) {
                Image(systemName: "arrow.up")
                    .font(.headline.weight(.bold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(isSendButtonEnabled ? Color.accentColor : Color.gray, in: Circle())
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSendButtonEnabled)
            }
            .disabled(!isSendButtonEnabled)
        }
        .padding(8)
        .background(.regularMaterial)
    }

    private var isSendButtonEnabled: Bool {
        !viewModel.isLoading && !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func sendMessage() {
        viewModel.sendMessage(messageText)
        messageText = ""
    }
}

struct BubbleShape: Shape {
    var isFromCurrentUser: Bool

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: [.topLeft, .topRight, isFromCurrentUser ? .bottomLeft : .bottomRight],
            cornerRadii: CGSize(width: 18, height: 18)
        )
        return Path(path.cgPath)
    }
}

struct HintPanelView: View {
    @Binding var hintMessage: String
    @Binding var isLoading: Bool
    var onDismiss: () -> Void
    var onRequestAnotherHint: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.indigo)
                Text("Attending Physician")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.indigo)
            }
            
            // Content
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    Spacer()
                }
                .frame(height: 40)
            } else {
                ScrollView {
                    Text(hintMessage)
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                        .lineSpacing(4)
                        .padding(.vertical, 4)
                }
                .frame(maxHeight: 150)
                
                // CTA Button for another hint
                Button(action: onRequestAnotherHint) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .medium))
                        Text("Get Another Hint")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(.indigo)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.indigo.opacity(0.1))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.indigo.opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(.top, 8)
            }
        }
        .padding(16)
        .frame(width: 280, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.indigo.opacity(0.3), lineWidth: 1)
        )
    }
}
