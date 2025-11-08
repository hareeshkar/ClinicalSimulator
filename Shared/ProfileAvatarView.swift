import SwiftUI

struct ProfileAvatarView: View {
    @State private var profileImage: UIImage?
    
    var body: some View {
        Group {
            if let image = profileImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .clipShape(Circle()) // Clip the image content to a circle
        .onAppear(perform: loadProfileImage)
        .onReceive(NotificationCenter.default.publisher(for: .profileImageDidChange)) { _ in
            loadProfileImage()
        }
    }
    
    private func loadProfileImage() {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("profileImage.jpg")
            
        if let data = try? Data(contentsOf: url) {
            self.profileImage = UIImage(data: data)
        }
    }
}
