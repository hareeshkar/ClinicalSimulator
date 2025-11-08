import SwiftUI
import SwiftData
import PhotosUI

struct ProfileView: View {
    // MARK: - User Preferences (Persisted)
    @AppStorage("userName") private var userName: String = "User"
    @AppStorage("userRoleTitle") private var userRoleTitle: String = UserProfileRole.studentMS3.title
    @AppStorage("hapticsEnabled") private var hapticsEnabled: Bool = true
    @AppStorage("preferredColorScheme") private var preferredColorScheme: String = "system"
    
    // MARK: - Local State
    @State private var isShowingResetConfirmation = false
    @State private var isShowingReloadConfirmation = false
    
    // MARK: - Image Picking & Role Editing State (MOVED HERE)
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var tempImageForCropping: UIImage? // ✅ NEW: Temporary holder for uncropped image
    @State private var selectedImage: UIImage? // ✅ CHANGED: Now only holds the FINAL cropped image
    @State private var profileImage: UIImage?
    @State private var isShowingCropper = false
    @State private var isEditingCustomRole = false
    @State private var customRoleText: String = ""
    
    // MARK: - Environment
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        NavigationStack {
            List {
                ProfileHeaderView(
                    userName: $userName,
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
                
                Section {
                    Button("Log Out") { /* Implement Log Out */ }
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .alert("Reset All Progress?", isPresented: $isShowingResetConfirmation) {
                Button("Reset Progress", role: .destructive, action: resetAllProgress)
            } message: {
                Text("This will delete all simulation history. This action cannot be undone.")
            }
            .alert("Reload Sample Cases?", isPresented: $isShowingReloadConfirmation) {
                Button("Reload Cases", role: .destructive, action: reloadSampleCases)
            } message: {
                Text("This will delete all existing cases and replace them with the original sample set. Any custom cases will be lost.")
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
            .onAppear(perform: loadProfileImage)
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
    
    // MARK: - Logic & Handlers (MOVED HERE)
    
    private func handlePhotoSelection() {
        Task {
            if let data = try? await selectedPhotoItem?.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                // ✅ FIX: Store in TEMPORARY state, NOT selectedImage
                tempImageForCropping = image
                isShowingCropper = true
            }
        }
    }
    
    private func saveProfileImage() {
        guard let image = selectedImage else { return }
        self.profileImage = image
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("profileImage.jpg")
        try? data.write(to: url)
        
        // ✅ ADD THIS LINE to notify other views of the change
        NotificationCenter.default.post(name: .profileImageDidChange, object: nil)
    }
    
    private func loadProfileImage() {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("profileImage.jpg")
        if let data = try? Data(contentsOf: url) {
            self.profileImage = UIImage(data: data)
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

// MARK: - Reusable ProfileHeaderView (Simplified)
struct ProfileHeaderView: View {
    // Bindings to state owned by the parent view
    @Binding var userName: String
    @Binding var userRoleTitle: String
    @Binding var selectedPhotoItem: PhotosPickerItem?
    @Binding var profileImage: UIImage?
    @Binding var isEditingCustomRole: Bool
    @Binding var customRoleText: String

    var body: some View {
        VStack(spacing: 16) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Group {
                    if let image = profileImage {
                        Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Image(systemName: "person.fill").font(.system(size: 50)).foregroundStyle(.secondary)
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
    ProfileView()
        .modelContainer(for: [PatientCase.self, StudentSession.self], inMemory: true)
}
