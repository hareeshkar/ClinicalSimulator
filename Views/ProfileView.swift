import SwiftUI
import SwiftData
import PhotosUI

struct ProfileView: View {
    // MARK: - User Preferences (Persisted)
    // ✅ Keep these as they are device-specific settings, not user-specific data
    @AppStorage("userRoleTitle") private var userRoleTitle: String = UserProfileRole.studentMS3.title
    @AppStorage("hapticsEnabled") private var hapticsEnabled: Bool = true
    @AppStorage("preferredColorScheme") private var preferredColorScheme: String = "system"
    
    // MARK: - Local State
    @State private var isShowingResetConfirmation = false
    @State private var isShowingReloadConfirmation = false
    @State private var isShowingLogoutConfirmation = false // ✅ NEW: Logout confirmation
    @State private var editableUserName: String = "" // Temporary state for the TextField
    
    // MARK: - Image Picking & Role Editing State
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var tempImageForCropping: UIImage?
    @State private var selectedImage: UIImage?
    @State private var profileImage: UIImage?
    @State private var isShowingCropper = false
    @State private var isEditingCustomRole = false
    @State private var customRoleText: String = ""
    
    // MARK: - Environment
    @Environment(\.modelContext) private var modelContext
    @Environment(User.self) private var currentUser // The read-only source of truth
    @EnvironmentObject var authService: AuthService // For logout
    
    var body: some View {
        NavigationStack {
            List {
                // ✅ FIX: Pass a binding to our new 'editableUserName' state variable
                ProfileHeaderView(
                    userName: $editableUserName, // <-- THE FIX
                    userRoleTitle: $userRoleTitle,
                    selectedPhotoItem: $selectedPhotoItem,
                    profileImage: $profileImage,
                    isEditingCustomRole: $isEditingCustomRole,
                    customRoleText: $customRoleText
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                preferencesSection
                dataManagementSection
                aboutSection
                logoutSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            // ✅ EXISTING ALERTS
            .alert("Reset All Progress?", isPresented: $isShowingResetConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reset Progress", role: .destructive, action: resetAllProgress)
            } message: {
                Text("This will delete all simulation history. This action cannot be undone.")
            }
            .alert("Reload Sample Cases?", isPresented: $isShowingReloadConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reload Cases", role: .destructive, action: reloadSampleCases)
            } message: {
                Text("This will delete all existing cases and replace them with the original sample set. Any custom cases will be lost.")
            }
            // ✅ NEW: Logout confirmation alert
            .alert("Log Out?", isPresented: $isShowingLogoutConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Log Out", role: .destructive) {
                    performLogout()
                }
            } message: {
                Text("Are you sure you want to log out? Any unsaved changes will be lost.")
            }
            // ✅ STATE MANAGEMENT MODIFIERS MOVED HERE
            .onChange(of: selectedPhotoItem, handlePhotoSelection)
            .fullScreenCover(isPresented: $isShowingCropper) {
                // ✅ COMPLETE FIX: Use completion handler to set the FINAL image
                ImageCropper(image: $tempImageForCropping, onCropComplete: { croppedImage in
                    // This is the ONLY place where selectedImage should be set
                    selectedImage = croppedImage
                    // Clear the temporary state
                    tempImageForCropping = nil
                })
            }
            .onChange(of: selectedImage, saveProfileImage)
            .onAppear(perform: setupView) // ✅ Use a dedicated setup function
            .onDisappear(perform: saveChanges) // ✅ Save changes when the view disappears
        }
    }
    
    // MARK: - ViewBuilder Sections
    
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
            Button(role: .destructive, action: { isShowingResetConfirmation = true }) {
                SettingRowView(title: "Reset All Progress", systemImage: "trash.fill", color: .red)
            }
            
            Button(action: { isShowingReloadConfirmation = true }) {
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
    
    // ✅ NEW: Separate logout section for better UX
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
    
    // MARK: - Logic & Handlers
    
    // ✅ A function to set up the view's initial state
    private func setupView() {
        // When the view appears, copy the current user's name to our editable state
        editableUserName = currentUser.fullName
        loadProfileImage()
    }
    
    // ✅ A function to save any changes back to the model
    private func saveChanges() {
        // Only save if the name has actually changed
        guard !editableUserName.isEmpty else { return }
        if editableUserName == currentUser.fullName { return }

        // Instead of assigning to `currentUser` (environment value is read-only),
        // fetch the mutable User instance from the modelContext and update it.
        let userId = currentUser.id
        let predicate = #Predicate<User> { $0.id == userId }
        let descriptor = FetchDescriptor<User>(predicate: predicate)
        if let user = try? modelContext.fetch(descriptor).first {
            user.fullName = editableUserName
            try? modelContext.save()
        } else {
            // Fallback: as a defensive measure, attempt to mutate the environment user if possible.
            // (Most likely not reached in normal operation.)
            print("Warning: Could not locate user in modelContext to save profile changes.")
        }
    }
    
    // ✅ NEW: Proper logout function
    private func performLogout() {
        authService.logout()
        // The ContentView will automatically switch to LoginView when currentUser becomes nil
    }
    
    private func handlePhotoSelection() {
        Task {
            if let data = try? await selectedPhotoItem?.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                // ✅ FIX: Store in TEMPORARY state, NOT selectedImage
                tempImageForCropping = image
                isShowingCropper = true
            }
        }
    }
    
    // ✅ --- COMPLETE OVERHAUL OF saveProfileImage ---
    private func saveProfileImage() {
        // 1. Ensure we have a cropped image to save.
        guard let image = selectedImage else { return }
        
        // 2. Update the UI immediately for a responsive feel.
        self.profileImage = image
        
        // 3. Create a unique, user-specific filename using the user's UUID.
        // This is more robust than using username as it will never change.
        let filename = "\(currentUser.id).jpg"
        
        // 4. Get the full path to the file in the documents directory.
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
            
        // 5. Convert the image to JPEG data.
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            print("Error: Could not convert image to JPEG data.")
            return
        }
        
        do {
            // 6. Write the data to the unique file path.
            try data.write(to: url)
            print("Successfully saved image to \(url.path)")
            
            // 7. CRITICAL: Save the unique filename to the User model.
            currentUser.profileImageFilename = filename
            try? modelContext.save() // Persist the change
            
            // 8. Notify other parts of the app (like the dashboard avatar) about the change.
            NotificationCenter.default.post(name: .profileImageDidChange, object: nil)
            
        } catch {
            print("Error saving image: \(error.localizedDescription)")
        }
    }
    
    // ✅ --- COMPLETE OVERHAUL OF loadProfileImage ---
    private func loadProfileImage() {
        // 1. Check if the current user has a saved image filename.
        guard let filename = currentUser.profileImageFilename, !filename.isEmpty else {
            // If not, ensure the UI shows the placeholder.
            self.profileImage = nil
            return
        }
        
        // 2. Construct the full URL from the unique filename.
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
            
        // 3. Try to load the data and create the image.
        if let data = try? Data(contentsOf: url) {
            self.profileImage = UIImage(data: data)
        } else {
            // If the file is missing for some reason, clear the image.
            self.profileImage = nil
            print("Warning: Could not load image data from path: \(url.path)")
        }
    }
    
    private func resetAllProgress() {
        try? modelContext.delete(model: StudentSession.self)
    }
    
    private func reloadSampleCases() {
        try? modelContext.delete(model: PatientCase.self)
        DataManager.loadSampleData(modelContext: modelContext)
    }
}

// MARK: - Reusable ProfileHeaderView (No changes needed here now)
// The ProfileHeaderView is already correctly defined to accept a Binding<String> for userName.
// The error was in the parent view (ProfileView) not providing that binding.
struct ProfileHeaderView: View {
    @Binding var userName: String
    @Binding var userRoleTitle: String
    @Binding var selectedPhotoItem: PhotosPickerItem?
    @Binding var profileImage: UIImage?
    @Binding var isEditingCustomRole: Bool
    @Binding var customRoleText: String
    
    // ✅ NEW: Add environment to access current user for fallback
    @Environment(User.self) private var currentUser

    var body: some View {
        VStack(spacing: 16) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Group {
                    if let image = profileImage {
                        Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
                    } else {
                        // ✅ Show the first initial of the full name as a fallback
                        Text(currentUser.fullName.prefix(1))
                            .font(.system(size: 50, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 100, height: 100)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .overlay(Circle().stroke(.secondary.opacity(0.3), lineWidth: 1))
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title)
                        .foregroundColor(.accentColor) 
                        .background(Color.white, in: Circle())
                }
            }
            .buttonStyle(.plain)
            
            // ✅ This TextField now correctly binds to the 'editableUserName'
            // state variable from the parent ProfileView.
            TextField("Your Name", text: $userName)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            roleSelector
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.background)
    }

    @ViewBuilder
    private var roleSelector: some View {
        if isEditingCustomRole {
            HStack {
                TextField("Enter Custom Role", text: $customRoleText)
                    .textFieldStyle(.roundedBorder)
                Button("Save") {
                    if !customRoleText.isEmpty { userRoleTitle = customRoleText }
                    isEditingCustomRole = false
                }.buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
        } else {
            Menu {
                ForEach(UserProfileRole.allPredefined) { role in
                    Button(role.title) { userRoleTitle = role.title }
                }
                Divider()
                Button("Custom...") {
                    customRoleText = userRoleTitle
                    isEditingCustomRole = true
                }
            } label: {
                Text(userRoleTitle)
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.thinMaterial, in: Capsule())
                    .foregroundStyle(.secondary)
            }
        }
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
#Preview {
    // ✅ FIX: The preview needs a mock user and auth service to work correctly.
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: PatientCase.self, StudentSession.self, User.self, configurations: config)
    
    let mockUser = User(fullName: "Dr. SwiftUI", email: "dr.swiftui@example.com", password: "password")
    container.mainContext.insert(mockUser)
    
    let authService = AuthService(modelContext: container.mainContext)
    // NOTE: authService.currentUser is private(set) — do not assign here in preview.

    return ProfileView()
        .modelContainer(container) // Provide the container
        .environment(mockUser) // Provide the user
        .environmentObject(authService) // Provide the auth service
}
