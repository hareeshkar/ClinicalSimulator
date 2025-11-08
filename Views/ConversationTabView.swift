import SwiftUI

struct ConversationTabView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var messageText = ""

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
}

struct AvatarView: View {
    let sender: String
    private var isStudent: Bool { sender == "student" }
    
    @State private var profileImage: UIImage?
    
    var body: some View {
        ZStack {
            Circle().fill(Color(.systemBackground))
            
            if isStudent, let image = profileImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: isStudent ? "person.fill" : "sparkle")
                    .font(.system(size: 16))
                    .foregroundColor(isStudent ? .primary : Color.purple)
                    .symbolVariant(isStudent ? .none : .fill)
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
    
    private func loadProfileImage() {
        if isStudent {
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("profileImage.jpg")
                
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

    var body: some View {
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
                    .background(isStudent ? Color.accentColor : Color(.secondarySystemBackground))
                    .clipShape(BubbleShape(isFromCurrentUser: isStudent))
                    .foregroundColor(isStudent ? .white : .primary)
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)

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
