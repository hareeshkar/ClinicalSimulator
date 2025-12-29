import SwiftUI
import SwiftData
import PhotosUI
import CoreHaptics

// MARK: - PROFILE VIEW
struct ProfileView: View {
    // MARK: - Environment & State
    @Environment(\.modelContext) private var modelContext
    @Environment(User.self) private var currentUser
    @EnvironmentObject var authService: AuthService
    @Environment(\.colorScheme) private var colorScheme
    
    // Preferences
    @AppStorage("userRoleTitle") private var userRoleTitle: String = UserProfileRole.studentMS3.title
    @AppStorage("hapticsEnabled") private var hapticsEnabled: Bool = true
    @AppStorage("preferredColorScheme") private var preferredColorScheme: String = "system"
    
    // Edit State (The "Mode" of the Dossier)
    @State private var isEditing = false
    @State private var scrollOffset: CGFloat = 0
    
    // Local Editing Buffers
    @State private var editName: String = ""
    @State private var editRole: String = ""
    @State private var editGender: Gender = .preferNotToSay
    @State private var editDOB: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @State private var hasDOB: Bool = false
    @State private var editLanguage: NativeLanguage = .english
    
    // Assets
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var profileImage: UIImage?
    @State private var selectedImage: UIImage?
    @State private var tempImageForCropping: UIImage?
    @State private var isShowingCropper = false
    
    // Alerts
    @State private var activeAlert: ProfileAlert?
    @State private var isUploadingToFirestore = false
    @State private var uploadMessage: String?
    
    enum ProfileAlert: Identifiable {
        case reset, reload, logout, uploadToCloud, clearCloud
        var id: Int { hashValue }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Layer 0: Ambient Fluid Background
                DossierBackground(isEditing: isEditing)
                    .ignoresSafeArea()
                
                // Layer 1: Content
                ScrollView {
                    scrollContent
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetKey.self) { value in scrollOffset = value }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar { toolbarContent }
            .alert(item: $activeAlert) { alertType in
                switch alertType {
                case .reset:
                    return Alert(
                        title: Text("Reset Progress?"),
                        message: Text("This will clear all your simulation data."),
                        primaryButton: .destructive(Text("Reset"), action: resetAllProgress),
                        secondaryButton: .cancel()
                    )
                case .reload:
                    return Alert(
                        title: Text("Reload Cases?"),
                        message: Text("This will refresh the case library."),
                        primaryButton: .default(Text("Reload"), action: reloadSampleCases),
                        secondaryButton: .cancel()
                    )
                case .logout:
                    return Alert(
                        title: Text("Sign Out?"),
                        message: Text("You will need to log in again."),
                        primaryButton: .destructive(Text("Sign Out"), action: performLogout),
                        secondaryButton: .cancel()
                    )
                case .uploadToCloud:
                    return Alert(
                        title: Text("☁️ Upload to Firestore?"),
                        message: Text("This will upload all cases from SampleCases.json to your Firestore database. Run this ONCE for initial setup."),
                        primaryButton: .default(Text("Upload"), action: uploadToFirestore),
                        secondaryButton: .cancel()
                    )
                case .clearCloud:
                    return Alert(
                        title: Text("⚠️ Clear Firestore?"),
                        message: Text("This will DELETE ALL cases from Firestore. This action cannot be undone."),
                        primaryButton: .destructive(Text("Clear"), action: clearFirestoreDatabase),
                        secondaryButton: .cancel()
                    )
                }
            }
            .onChange(of: selectedPhotoItem, handlePhotoSelection)
            .fullScreenCover(isPresented: $isShowingCropper) {
                ImageCropper(image: $tempImageForCropping, onCropComplete: handleCropCompletion)
            }
            .onChange(of: selectedImage, saveProfileImage)
            .onAppear(perform: setupView)
            .dismissKeyboardOnTap()
        }
    }
    
    @ViewBuilder
    private var scrollContent: some View {
        VStack(spacing: 24) {
            // Scroll Reader
            GeometryReader { proxy in
                Color.clear.preference(key: ScrollOffsetKey.self, value: proxy.frame(in: .named("scroll")).minY)
            }
            .frame(height: 0)
            
            // 1. IDENTITY CARD (The Core Credential)
            IdentityCard(
                user: currentUser,
                image: profileImage,
                isEditing: isEditing,
                editName: $editName,
                editRole: $userRoleTitle, // Binding to AppStorage directly for now, or buffer
                selectedPhotoItem: $selectedPhotoItem,
                isBirthday: isBirthdayToday
            )
            // Optimized: Reduced parallax effect computation for better scrolling performance
            .scaleEffect(scrollOffset < 0 ? max(0.95, 1.0 + (scrollOffset / 800)) : 1.0)
            .offset(y: scrollOffset < 0 ? scrollOffset / 3 : 0)
            
            // 2. BIOMETRICS & DATA (The Details)
            GlassSection(title: "Personal Information") {
                if isEditing {
                    EditableBiometrics(
                        gender: $editGender,
                        hasDOB: $hasDOB,
                        dob: $editDOB,
                        language: $editLanguage
                    )
                } else {
                    ReadOnlyBiometrics(
                        user: currentUser,
                        email: currentUser.email
                    )
                }
            }
            
            // 3. SYSTEM CONFIGURATION (Preferences)
            GlassSection(title: "Settings") {
                VStack(spacing: 16) {
                    PreferenceToggle(
                        title: "HAPTIC FEEDBACK",
                        icon: "hand.tap.fill",
                        isOn: $hapticsEnabled
                    )
                    
                    ThemeSelector(selection: $preferredColorScheme)
                }
            }
            
            // 4. DATA OPERATIONS (Danger Zone)
            GlassSection(title: "Data Management", tint: .red) {
                VStack(spacing: 12) {
                    ActionRow(title: "Reset Progress", icon: "trash.fill", color: .red) {
                        activeAlert = .reset
                    }
                    Divider().overlay(Color.white.opacity(0.1))
                    ActionRow(title: "Reload Cases", icon: "arrow.clockwise", color: .blue) {
                        activeAlert = .reload
                    }
                }
            }
            
            // ⚠️ ADMIN TOOLS - Remove after initial setup
            #if DEBUG
            GlassSection(title: "🔧 Admin Tools", tint: .orange) {
                VStack(spacing: 12) {
                    if isUploadingToFirestore {
                        HStack(spacing: 12) {
                            ProgressView()
                                .tint(.orange)
                            Text(uploadMessage ?? "Uploading to Firestore...")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.orange)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    } else {
                        ActionRow(title: "☁️ Upload Cases to Firestore", icon: "icloud.and.arrow.up", color: .orange) {
                            activeAlert = .uploadToCloud
                        }
                        Divider().overlay(Color.white.opacity(0.1))
                        ActionRow(title: "🗑️ Clear Firestore Database", icon: "xmark.icloud", color: .red) {
                            activeAlert = .clearCloud
                        }
                    }
                }
            }
            #endif
            
            // 5. TERMINATION
            Button(action: { activeAlert = .logout }) {
                HStack(spacing: 10) {
                    Image(systemName: "power.circle.fill")
                        .font(.system(size: 18))
                    Text("Sign Out of Session")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                .foregroundStyle(colorScheme == .dark ? .white.opacity(0.9) : .red)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background(
                    Capsule()
                        .fill(colorScheme == .dark ? Color.red.opacity(0.15) : Color.red.opacity(0.08))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.red.opacity(colorScheme == .dark ? 0.3 : 0.2), lineWidth: 1)
                )
            }
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
        .padding(20)
    }
    
    // MARK: - Computed Properties & Logic
    private var isBirthdayToday: Bool {
        guard let dob = currentUser.dateOfBirth else { return false }
        let calendar = Calendar.current
        let todayComponents = calendar.dateComponents([.month, .day], from: Date())
        let dobComponents = calendar.dateComponents([.month, .day], from: dob)
        return todayComponents.month == dobComponents.month && todayComponents.day == dobComponents.day
    }
    
    private func setupView() {
        editName = currentUser.fullName
        // editRole = userRoleTitle // (Synced via AppStorage directly for simplicity in this demo)
        editGender = currentUser.gender ?? .preferNotToSay
        editLanguage = currentUser.nativeLanguage
        if let dob = currentUser.dateOfBirth {
            editDOB = dob
            hasDOB = true
        } else {
            hasDOB = false
        }
        loadProfileImage()
    }
    
    private func toggleEditMode() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        if isEditing {
            // SAVE
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                saveChanges()
                isEditing = false
            }
        } else {
            // EDIT
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                isEditing = true
            }
        }
    }
    
    private func saveChanges() {
        // Update local user model
        currentUser.fullName = editName
        // userRoleTitle is auto-saved via AppStorage
        currentUser.gender = editGender
        currentUser.dateOfBirth = hasDOB ? editDOB : nil
        currentUser.nativeLanguage = editLanguage
        try? modelContext.save()
        
        // Sync to Firestore
        Task {
            do {
                try await authService.updateUserProfile()
                print("✅ Profile changes synced to Firestore")
            } catch {
                print("❌ Failed to sync profile to Firestore: \(error.localizedDescription)")
            }
        }
    }
    
    // ... (Image handling logic same as before, preserved for brevity)
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
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
        
        // Optimized: Save on background thread to avoid blocking UI
        Task.detached(priority: .utility) {
            guard let data = image.jpegData(compressionQuality: 0.8) else { return }
            try? data.write(to: url)
            
            await MainActor.run {
                self.currentUser.profileImageFilename = filename
                try? self.modelContext.save()
                NotificationCenter.default.post(name: .profileImageDidChange, object: nil)
            }
        }
    }
    private func loadProfileImage() {
        guard let filename = currentUser.profileImageFilename, !filename.isEmpty else { self.profileImage = nil; return }
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
        
        // Optimized: Load image on background thread
        Task.detached(priority: .userInitiated) {
            if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                await MainActor.run {
                    self.profileImage = image
                }
            } else {
                await MainActor.run {
                    self.profileImage = nil
                }
            }
        }
    }
    
    private func performLogout() { Task { authService.logout() } }
    
    private func resetAllProgress() {
        let userId = currentUser.id
        let predicate = #Predicate<StudentSession> { $0.user?.id == userId }
        let descriptor = FetchDescriptor(predicate: predicate)
        
        do {
            let sessionsToDelete = try modelContext.fetch(descriptor)
            for session in sessionsToDelete {
                modelContext.delete(session)
            }
            try modelContext.save()
            print("✅ All progress reset for user: \(currentUser.fullName)")
        } catch {
            print("❌ Error resetting progress: \(error.localizedDescription)")
        }
    }
    
    private func reloadSampleCases() {
        do {
            // Smart upsert: updates changed cases, adds new ones, preserves relationships
            try DataManager.reloadSampleCasesUpsert(modelContext: modelContext)
            print("✅ Sample cases reloaded with smart upsert")
        } catch {
            print("❌ Error reloading cases: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 🔧 Admin Functions (Firestore Upload)
    
    private func uploadToFirestore() {
        guard !isUploadingToFirestore else { return }
        
        isUploadingToFirestore = true
        uploadMessage = "Preparing upload..."
        
        Task {
            do {
                let uploader = FirestoreAdminUploader()
                uploadMessage = "Uploading cases to Firestore..."
                
                let (success, failed) = try await uploader.uploadDatabaseToCloud()
                
                await MainActor.run {
                    uploadMessage = "✅ Upload Complete: \(success) cases uploaded"
                    if failed > 0 {
                        uploadMessage! += ", \(failed) failed"
                    }
                    
                    // Reset after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        isUploadingToFirestore = false
                        uploadMessage = nil
                    }
                }
            } catch {
                await MainActor.run {
                    uploadMessage = "❌ Upload Failed: \(error.localizedDescription)"
                    
                    // Reset after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        isUploadingToFirestore = false
                        uploadMessage = nil
                    }
                }
            }
        }
    }
    
    private func clearFirestoreDatabase() {
        guard !isUploadingToFirestore else { return }
        
        isUploadingToFirestore = true
        uploadMessage = "Clearing Firestore database..."
        
        Task {
            do {
                let uploader = FirestoreAdminUploader()
                let deletedCount = try await uploader.clearFirestoreDatabase()
                
                await MainActor.run {
                    uploadMessage = "✅ Cleared \(deletedCount) cases from Firestore"
                    
                    // Reset after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        isUploadingToFirestore = false
                        uploadMessage = nil
                    }
                }
            } catch {
                await MainActor.run {
                    uploadMessage = "❌ Clear Failed: \(error.localizedDescription)"
                    
                    // Reset after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        isUploadingToFirestore = false
                        uploadMessage = nil
                    }
                }
            }
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button(action: toggleEditMode) {
                Text(isEditing ? "Save" : "Edit")
                    .font(.system(size: 16, weight: .semibold))
            }
        }
    }
}

// MARK: - 🪪 COMPONENT: IDENTITY CARD
struct IdentityCard: View {
    let user: User
    let image: UIImage?
    let isEditing: Bool
    @Binding var editName: String
    @Binding var editRole: String
    @Binding var selectedPhotoItem: PhotosPickerItem?
    let isBirthday: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            // Card background (adapts to light/dark)
            Group {
                if colorScheme == .dark {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(.ultraThinMaterial)
                } else {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.white)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(LinearGradient(
                        colors: [
                            Color.primary.opacity(colorScheme == .dark ? 0.3 : 0.1),
                            Color.primary.opacity(colorScheme == .dark ? 0.05 : 0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ), lineWidth: 1.5)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.06), radius: 15, x: 0, y: 10)
            
            VStack(spacing: 24) {
                // Avatar Area with Animated Birthday Effect
                ZStack {
                    AnimatedAvatarView(isBirthday: isBirthday, size: 110)
                }
                .overlay(alignment: .bottomTrailing) {
                    if isEditing {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(10)
                                .background(Color.blue, in: Circle())
                                .shadow(radius: 4)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                
                // Text Info
                VStack(spacing: 10) {
                    if isEditing {
                        TextField("Full Name", text: $editName)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.primary)
                            .padding(.horizontal)
                        
                        PremiumRolePicker(selectedRole: Binding(
                            get: { UserProfileRole(title: editRole) },
                            set: { editRole = $0.title }
                        ))
                        .padding(.top, 8)
                        
                    } else {
                        Text(user.fullName)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)

                        Text(editRole.uppercased())
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .tracking(2)
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(colorScheme == .dark ? Color.blue.opacity(0.15) : Color.blue.opacity(0.06))
                            )
                    }
                }
            }
            .padding(30)
        }
        // Physical expansion when editing
        .frame(height: isEditing ? 340 : 280)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isEditing)
    }
}

// MARK: - GLASS SECTION
struct GlassSection<Content: View>: View {
    let title: String
    var tint: Color = .blue
    @ViewBuilder let content: Content
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(scheme == .dark ? tint.opacity(0.8) : tint.opacity(0.9))
                .tracking(1.2)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content
            }
            .padding(20)
            .background(
                Group {
                    if scheme == .dark {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(.ultraThinMaterial)
                    } else {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.white)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.primary.opacity(scheme == .dark ? 0.1 : 0.05), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(scheme == .dark ? 0.15 : 0.04), radius: 10, x: 0, y: 5)
        }
    }
}

// MARK: - 👁️ READ-ONLY BIOMETRICS
struct ReadOnlyBiometrics: View {
    let user: User
    let email: String
    @Environment(\.colorScheme) private var scheme
    
    var body: some View {
        VStack(spacing: 20) {
            // Email with flexible sizing
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.blue.gradient)
                        .frame(width: 24)
                    Text("Email Address")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Text(email)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Divider().overlay(Color.primary.opacity(0.05))
            
            // Gender & Language in grid
            HStack(spacing: 16) {
                DataBlock(label: "Gender", value: user.gender?.rawValue ?? "Not Set", icon: "person.2.circle.fill")
                Divider().frame(height: 40).overlay(Color.primary.opacity(0.05))
                DataBlock(label: "Language", value: user.nativeLanguage.displayName, icon: "globe.americas.fill")
            }
            
            Divider().overlay(Color.primary.opacity(0.05))
            
            // DOB & Member Since in grid
            HStack(spacing: 16) {
                if let dob = user.dateOfBirth {
                    DataBlock(
                        label: "Date of Birth",
                        value: dob.formatted(date: .abbreviated, time: .omitted),
                        icon: "birthday.cake.fill"
                    )
                    Divider().frame(height: 40).overlay(Color.primary.opacity(0.05))
                }
                DataBlock(
                    label: "Member Since",
                    value: user.createdAt.formatted(date: .abbreviated, time: .omitted),
                    icon: "calendar.badge.clock"
                )
            }
        }
    }
}

// MARK: - ✏️ EDITABLE BIOMETRICS
struct EditableBiometrics: View {
    @Binding var gender: Gender
    @Binding var hasDOB: Bool
    @Binding var dob: Date
    @Binding var language: NativeLanguage
    @Environment(\.colorScheme) private var scheme
    
    var body: some View {
        VStack(spacing: 22) {
            // Gender
            HStack {
                Label("Gender Identity", systemImage: "person.2.circle.fill")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                Menu {
                    ForEach(Gender.allCases) { g in
                        Button(g.rawValue) { gender = g }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(gender.rawValue)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.blue)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(scheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03), in: Capsule())
                }
            }
            
            Divider().overlay(Color.primary.opacity(0.05))
            
            // Language
            HStack {
                Label("Primary Language", systemImage: "globe.americas.fill")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                Menu {
                    ForEach(NativeLanguage.allCases) { l in
                        Button(l.displayName) { language = l }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(language.displayName)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.blue)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(scheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03), in: Capsule())
                }
            }
            
            Divider().overlay(Color.primary.opacity(0.05))
            
            // DOB Toggle & Picker
            VStack(spacing: 12) {
                Toggle(isOn: $hasDOB) {
                    Label("Date of Birth", systemImage: "calendar")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .tint(.blue)
                
                if hasDOB {
                    DatePicker("", selection: $dob, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }
}

// MARK: - 🧩 SMALLER ATOMIC COMPONENTS

struct DataRow: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.blue.gradient)
                .frame(width: 24)
            
            Text(label)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
        }
    }
}

struct DataBlock: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(.blue.gradient)
                Text(label)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .tracking(0.3)
            }
            .foregroundStyle(.secondary)
            
            Text(value)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PreferenceToggle: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool
    
    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(.blue.gradient)
                    .frame(width: 24)
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
            }
        }
        .tint(.blue)
    }
}

struct ThemeSelector: View {
    @Binding var selection: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Appearance Theme", systemImage: "paintbrush.fill")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            
            Picker("", selection: $selection) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            .pickerStyle(.segmented)
        }
        .padding(.top, 4)
    }
}

struct ActionRow: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(color)
                    .frame(width: 24)
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(color)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(color.opacity(0.4))
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - 🌋 DOSSIER ATMOSPHERE
struct DossierBackground: View {
    var isEditing: Bool
    @Environment(\.colorScheme) var scheme
    
    var body: some View {
        // Optimized: Use static gradient instead of animated canvas for better performance
        ZStack {
            // Base color
            (isEditing 
                ? (scheme == .dark ? Color(red: 0.08, green: 0.02, blue: 0.02) : Color(red: 1.0, green: 0.98, blue: 0.98))
                : (scheme == .dark ? Color(red: 0.02, green: 0.02, blue: 0.05) : Color(red: 0.97, green: 0.98, blue: 1.0)))
            
            // Subtle gradient orbs (static)
            GeometryReader { geo in
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    (isEditing ? Color.orange : Color.blue).opacity(scheme == .dark ? 0.15 : 0.06),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 300
                            )
                        )
                        .frame(width: 600, height: 600)
                        .position(x: geo.size.width * 0.3, y: geo.size.height * 0.4)
                    
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    (isEditing ? Color.red : Color.cyan).opacity(scheme == .dark ? 0.1 : 0.05),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 300
                            )
                        )
                        .frame(width: 600, height: 600)
                        .position(x: geo.size.width * 0.7, y: geo.size.height * 0.6)
                }
            }
        }
        .animation(.easeInOut(duration: 0.4), value: isEditing)
    }
}

// MARK: - 🎨 COMPONENT: PREMIUM ROLE PICKER
struct PremiumRolePicker: View {
    @Binding var selectedRole: UserProfileRole
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Menu {
            ForEach(UserProfileRole.allPredefined) { role in
                Button(role.title) {
                    selectedRole = role
                }
            }
        } label: {
            HStack {
                Text(selectedRole.title)
                    .foregroundStyle(.primary)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.blue)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(scheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )
        }
    }
}

#Preview {
    ProfileView()
        .environment(User(fullName: "Dr. Test", email: "test@test.com", password: "pw"))
}
