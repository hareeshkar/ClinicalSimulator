import Foundation
import SwiftData

@Model
class ConversationMessage {
    @Attribute(.unique)
    var id: UUID
    
    var sender: String // We'll use "student" or "patient" to identify who sent it.
    var content: String
    var timestamp: Date
    
    // This defines the "many-to-one" side of the relationship.
    // Many messages can belong to one session.
    var session: StudentSession?

    init(id: UUID = UUID(), sender: String, content: String, timestamp: Date = Date()) {
        self.id = id
        self.sender = sender
        self.content = content
        self.timestamp = timestamp
    }
}
