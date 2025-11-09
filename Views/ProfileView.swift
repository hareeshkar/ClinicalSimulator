import SwiftUI
import SwiftData
import PhotosUI

struct ProfileView: View {
    // MARK: - User Preferences (Persisted)
    @AppStorage("userRoleTitle") private var userRoleTitle: String = UserProfileRole.studentMS3.title
    @AppStorage("hapticsEnabled") private var hapticsEnabled: Bool = true
    @AppStorage("preferredColorScheme") private var preferredColorScheme: String = "system"
    
    // MARK: - Local State
    @State private var isEditing = false // Controls the edit mode for the profile
    @State private var editableUserName: String = ""
    @State private var editableRoleTitle: String = ""
    @State private var editableGender: Gender = .preferNotToSay
    @State private var editableDOB: Date = Date()
    @State private var hasDOB: Bool = false
    
    // Alert States
    @State private var isShowingResetConfirmation = false
    @State private var isShowingReloadConfirmation = false
    @State private var isShowingLogoutConfirmation = false
    
    // Image Picking State
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var tempImageForCropping: UIImage?
    @State private var selectedImage: UIImage?
    @State private var profileImage: UIImage?
    @State private var isShowingCropper = false
    
    // MARK: - Environment
    @Environment(\.modelContext) private var modelContext
    @Environment(User.self) private var currentUser
    @EnvironmentObject var authService: AuthService
    
    // MARK: - Computed Properties
    private var formattedJoinDate: String {
        currentUser.createdAt.formatted(date: .long, time: .omitted)
    }
    
    // ✅ NEW: Birthday check logic
    private var isBirthdayToday: Bool {
        guard let dob = currentUser.dateOfBirth else { return false }
        return Calendar.current.isDateInToday(dob)
    }
    
    var body: some View {
        NavigationStack {
            List {
                ProfileHeaderView(
                    userName: $editableUserName,
                    userRoleTitle: $editableRoleTitle,
                    selectedPhotoItem: $selectedPhotoItem,
                    profileImage: $profileImage,
                    isEditing: isEditing,
                    isBirthday: isBirthdayToday // ✅ Pass birthday status down
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                accountDetailsSection
                preferencesSection
                dataManagementSection
                aboutSection
                logoutSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Profile & Settings")
            .toolbar { toolbarContent }
            .alert("Reset All Progress?", isPresented: $isShowingResetConfirmation, actions: resetConfirmationActions)
            .alert("Reload Sample Cases?", isPresented: $isShowingReloadConfirmation, actions: reloadConfirmationActions)
            .alert("Log Out?", isPresented: $isShowingLogoutConfirmation, actions: logoutConfirmationActions)
            .onChange(of: selectedPhotoItem, handlePhotoSelection)
            .fullScreenCover(isPresented: $isShowingCropper) {
                ImageCropper(image: $tempImageForCropping, onCropComplete: handleCropCompletion)
            }
            .onChange(of: selectedImage, saveProfileImage)
            .onAppear(perform: setupView)
            .onDisappear(perform: saveChanges)
        }
    }
    
    // MARK: - ViewBuilder Sections
    
    @ViewBuilder
    private var accountDetailsSection: some View {
        // ✅ IMPROVED: Section animates its content changes between edit/display modes
        Section("Account Details") {
            SettingRowView(title: "Email", systemImage: "envelope.fill", color: .gray) {
                Text(currentUser.email)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            // The UI for Gender and DOB now intelligently switches based on edit mode
            if isEditing {
                editableAccountDetails
            } else {
                displayAccountDetails
            }
            
            SettingRowView(title: "Member Since", systemImage: "calendar", color: .gray) {
                Text(formattedJoinDate)
                    .foregroundStyle(.secondary)
            }
        }
        .animation(.default, value: isEditing)
    }
    
    // ✅ NEW: Extracted display-only rows for clarity
    @ViewBuilder
    private var displayAccountDetails: some View {
        if let gender = currentUser.gender {
            SettingRowView(title: "Gender", systemImage: "person.2.circle.fill", color: .purple) {
                Text(gender.rawValue)
                    .foregroundStyle(.secondary)
            }
        }
        
        // Always show Date of Birth, with "Not set" if nil
        SettingRowView(title: "Date of Birth", systemImage: "gift.fill", color: .pink) {
            if let dob = currentUser.dateOfBirth {
                Text(dob.formatted(date: .long, time: .omitted))
                    .foregroundStyle(.secondary)
            } else {
                Text("Not set")
                    .foregroundStyle(.secondary.opacity(0.6))
            }
        }
    }
    
    // ✅ NEW: Extracted editable controls for clarity
    @ViewBuilder
    private var editableAccountDetails: some View {
        Picker(selection: $editableGender) {
            ForEach(Gender.allCases, id: \.self) { gender in
                Text(gender.rawValue).tag(gender)
            }
        } label: {
            SettingRowView(title: "Gender", systemImage: "person.2.circle.fill", color: .purple)
        }
        
        Toggle(isOn: $hasDOB.animation()) {
            SettingRowView(title: "Set Date of Birth", systemImage: "gift.fill", color: .pink)
        }
        
        if hasDOB {
            DatePicker(
                "Birthday",
                selection: $editableDOB,
                in: ...Date.now,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .transition(.scale.combined(with: .opacity))
        }
    }
    
    @ViewBuilder
    private var preferencesSection: some View {
        Section("Preferences") {
            Picker("Theme", selection: $preferredColorScheme) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            .pickerStyle(.segmented)
            
            Toggle(isOn: $hapticsEnabled) {
                SettingRowView(title: "Enable Haptics", systemImage: "hand.tap.fill", color: .indigo)
            }
        }
    }
    
    @ViewBuilder
    private var dataManagementSection: some View {
        Section("Data Management") {
            Button(role: .destructive) { isShowingResetConfirmation = true } label: {
                SettingRowView(title: "Reset All Progress", systemImage: "trash.fill", color: .red)
            }
            
            Button { isShowingReloadConfirmation = true } label: {
                SettingRowView(title: "Reload Sample Cases", systemImage: "arrow.clockwise.circle.fill", color: .blue)
            }
        }
    }
    
    @ViewBuilder
    private var aboutSection: some View {
        Section("About") {
            SettingRowView(title: "App Version", systemImage: "info.circle.fill", color: .gray) {
                Text("1.0.0").foregroundStyle(.secondary)
            }
            Link(destination: URL(string: "https://www.apple.com")!) {
                SettingRowView(title: "Privacy Policy", systemImage: "lock.shield.fill", color: .gray)
            }
            Link(destination: URL(string: "https://www.apple.com")!) {
                SettingRowView(title: "Terms of Service", systemImage: "doc.text.fill", color: .gray)
            }
        }
    }
    
    @ViewBuilder
    private var logoutSection: some View {
        Section {
            Button(action: { isShowingLogoutConfirmation = true }) {
                HStack {
                    Spacer()
                    Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.headline)
                        .foregroundStyle(.red)
                    Spacer()
                }
            }
        }
    }

    // MARK: - Toolbar & Alerts
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button(isEditing ? "Done" : "Edit") {
                if isEditing {
                    saveChanges()
                }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    isEditing.toggle()
                }
            }
            .fontWeight(.semibold)
        }
    }
    
    @ViewBuilder
    private func resetConfirmationActions() -> some View {
        Button("Cancel", role: .cancel) { }
        Button("Reset Progress", role: .destructive, action: resetAllProgress)
    }
    
    @ViewBuilder
    private func reloadConfirmationActions() -> some View {
        Button("Cancel", role: .cancel) { }
        Button("Reload Cases", role: .destructive, action: reloadSampleCases)
    }
    
    @ViewBuilder
    private func logoutConfirmationActions() -> some View {
        Button("Cancel", role: .cancel) { }
        Button("Log Out", role: .destructive, action: performLogout)
    }
    
    // MARK: - Logic & Handlers
    
    private func setupView() {
        editableUserName = currentUser.fullName
        editableRoleTitle = userRoleTitle
        editableGender = currentUser.gender ?? .preferNotToSay
        if let dob = currentUser.dateOfBirth {
            editableDOB = dob
            hasDOB = true
        } else {
            hasDOB = false
        }
        loadProfileImage()
    }
    
    private func saveChanges() {
        currentUser.fullName = editableUserName
        userRoleTitle = editableRoleTitle
        currentUser.gender = editableGender
        currentUser.dateOfBirth = hasDOB ? editableDOB : nil
        try? modelContext.save()
    }
    
    private func performLogout() { authService.logout() }
    
    private func handlePhotoSelection() {
        Task {
            if let data = try? await selectedPhotoItem?.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                tempImageForCropping = image
                isShowingCropper = true
            }
        }
    }
    
    private func handleCropCompletion(croppedImage: UIImage) {
        selectedImage = croppedImage
        tempImageForCropping = nil
    }
    
    private func saveProfileImage() {
        guard let image = selectedImage else { return }
        self.profileImage = image
        
        let filename = "\(currentUser.id).jpg"
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
            
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        
        do {
            try data.write(to: url)
            currentUser.profileImageFilename = filename
            try? modelContext.save()
            NotificationCenter.default.post(name: .profileImageDidChange, object: nil)
        } catch {
            print("Error saving image: \(error.localizedDescription)")
        }
    }
    
    private func loadProfileImage() {
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
    
    private func resetAllProgress() { try? modelContext.delete(model: StudentSession.self) }
    private func reloadSampleCases() {
        try? modelContext.delete(model: PatientCase.self)
        DataManager.loadSampleData(modelContext: modelContext)
    }
}

// MARK: - Reusable ProfileHeaderView (IMPROVED)
struct ProfileHeaderView: View {
    @Binding var userName: String
    @Binding var userRoleTitle: String
    @Binding var selectedPhotoItem: PhotosPickerItem?
    @Binding var profileImage: UIImage?
    let isEditing: Bool
    let isBirthday: Bool // ✅ Receive birthday status
    
    @Environment(User.self) private var currentUser

    var body: some View {
        VStack(spacing: 16) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                AnimatedAvatarView(isBirthday: isBirthday, size: 100)
                    .overlay(alignment: .bottomTrailing) {
                        if isEditing {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title)
                                .foregroundColor(.accentColor)
                                .background(Color.white, in: Circle())
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
            }
            .buttonStyle(.plain)
            .allowsHitTesting(isEditing)

            VStack(spacing: 8) {
                Group {
                    if isEditing {
                        TextField("Your Name", text: $userName, axis: .vertical)
                            .lineLimit(3)
                    } else {
                        Text(userName)
                    }
                }
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .center)))
                
                roleSelector
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isEditing)
    }

    @ViewBuilder
    private var roleSelector: some View {
        HStack(spacing: 8) {
            if isEditing {
                Text("Role:")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
            
            if !isEditing { Spacer() }
            
            Group {
                if isEditing {
                    Picker("", selection: $userRoleTitle) {
                        ForEach(UserProfileRole.allPredefined) { role in
                            Text(role.title).tag(role.title)
                        }
                    }
                    .pickerStyle(.menu)
                    .accentColor(.secondary)
                } else {
                    Text(userRoleTitle)
                }
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
            .transition(.opacity)
            
            if !isEditing { Spacer() }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        // Use AnyShapeStyle so the ternary result is a single ShapeStyle type (Color vs Material mismatch fixed)
        .background(isEditing ? AnyShapeStyle(Color.clear) : AnyShapeStyle(.thinMaterial), in: Capsule())
    }
}

// MARK: - Reusable SettingRowView
struct SettingRowView<Content: View>: View {
    let title: String
    let systemImage: String
    let color: Color
    @ViewBuilder var content: Content

    init(title: String, systemImage: String, color: Color, @ViewBuilder content: @escaping () -> Content = { EmptyView() }) {
        self.title = title
        self.systemImage = systemImage
        self.color = color
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(color, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            
            Text(title)
                .foregroundStyle(.primary)
            
            Spacer()
            
            content
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview
#Preview("Standard View") {
    let (container, authService, user) = createMockEnvironment()
    return ProfileView()
        .modelContainer(container)
        .environment(user)
        .environmentObject(authService)
}

#Preview("Birthday View") {
    let (container, authService, user) = createMockEnvironment()
    user.dateOfBirth = Date()
    
    return ProfileView()
        .modelContainer(container)
        .environment(user)
        .environmentObject(authService)
}

@MainActor
fileprivate func createMockEnvironment() -> (ModelContainer, AuthService, User) {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: User.self, configurations: config)
    
    let mockUser = User(fullName: "Dr. Alessandra Villanueva", email: "dr.villanueva@example.com", password: "password")
    container.mainContext.insert(mockUser)
    
    let authService = AuthService(modelContext: container.mainContext)
    
    return (container, authService, mockUser)
}