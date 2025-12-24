import SwiftUI

struct ProfileAvatarView: View {
    @State private var profileImage: UIImage?
    
    // ✅ Get the current user from the environment
    @Environment(User.self) private var currentUser
    
    var body: some View {
        Group {
            if let image = profileImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                // ✅ Show the first initial of the full name as a fallback
                Text(currentUser.fullName.prefix(1))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .clipShape(Circle()) // Clip the image content to a circle
        .onAppear(perform: loadProfileImage)
        .onReceive(NotificationCenter.default.publisher(for: .profileImageDidChange)) { _ in
            loadProfileImage()
        }
    }
    
    // ✅ --- OPTIMIZED loadProfileImage ---
    private func loadProfileImage() {
        // 1. Check if the user has a filename
        guard let filename = currentUser.profileImageFilename, !filename.isEmpty else {
            self.profileImage = nil
            return
        }
        
        // 2. Construct the URL from the filename
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
            
        // 3. Load the image on background thread to avoid blocking UI
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
}
