import Foundation
import SwiftData

@MainActor
class ChatViewModel: ObservableObject, Hashable, Identifiable { // Conform to Identifiable

    @Published var messages: [ConversationMessage] = []
    @Published var isLoading: Bool = false
    
    let session: StudentSession
    let patientCase: PatientCase
    private let geminiService = GeminiService()
    let modelContext: ModelContext // Made this public for SimulationView
    let userRole: String

    let id = UUID() // Unique identifier for Identifiable conformance

    init(patientCase: PatientCase, session: StudentSession, modelContext: ModelContext, userRole: String) {
        self.patientCase = patientCase
        self.session = session
        self.modelContext = modelContext
        self.userRole = userRole
        // Load existing messages from the session and sort by timestamp
        self.messages = session.messages.sorted(by: { $0.timestamp < $1.timestamp })
   
    }

    // --- HASHABLE CONFORMANCE ---
    static func == (lhs: ChatViewModel, rhs: ChatViewModel) -> Bool {
        // Compare the session IDs to check equality
        return lhs.session.sessionId == rhs.session.sessionId
    }
    
    func hash(into hasher: inout Hasher) {
        // Combine the sessionId into the hasher to ensure uniqueness
        hasher.combine(session.sessionId)
    }

    // --- SEND MESSAGE (STREAMING IMPLEMENTATION) ---
    /// Sends a student's message and gets a simulated patient response streamed from Gemini.
    /// Sends a student's message and gets a simulated patient response streamed from Gemini.
    func sendMessage(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // 1. Create and save the student's message as before.
        let studentMessage = ConversationMessage(sender: "student", content: text)
        studentMessage.session = session
        modelContext.insert(studentMessage)
        messages.append(studentMessage)
        
        // 2. Set loading state to true. This will immediately show the Typing Indicator in the UI.
        isLoading = true
        
        Task {
            // We declare this here, but we will only create it once we have content.
            var patientMessage: ConversationMessage?
            
            do {
                // 3. Get the stream from the Gemini service.
                let responseStream = geminiService.generatePatientResponseStream(
                    patientCase: patientCase,
                    session: session,
                    userRole: userRole
                )
                
                // 4. Loop through the stream to get text chunks.
                for try await chunk in responseStream {
                    // 5. THE CRITICAL FIX: Check if this is the first chunk.
                    if patientMessage == nil {
                        // This is the first piece of text. Now we create the message object.
                        let newMessage = ConversationMessage(sender: "patient", content: "")
                        newMessage.session = session
                        modelContext.insert(newMessage)
                        messages.append(newMessage)
                        patientMessage = newMessage
                    }
                    
                    // 6. Append the new text chunk to the content of our message object.
                    // The UI will update automatically because it's a reference type.
                    patientMessage?.content += chunk
                }
                
            } catch {
                // 7. If an error occurs, update the last message bubble with an error.
                if let lastMessage = messages.last, lastMessage.sender == "patient" {
                    lastMessage.content = "Sorry, an error occurred. (\(error.localizedDescription))"
                } else {
                    // Or create a new error message if one doesn't exist.
                    let errorMessage = ConversationMessage(sender: "patient", content: "Sorry, an error occurred. (\(error.localizedDescription))")
                    errorMessage.session = session
                    modelContext.insert(errorMessage)
                    messages.append(errorMessage)
                }
            }
            
            // 8. Once the stream is finished, we are no longer loading.
            isLoading = false
        }
    }
    
    // --- PROACTIVE RESPONSE ---
    /// Generates a spontaneous AI patient response based on a recent event.
    func generateProactiveResponse() {
        // Safety Check: Don't generate a proactive message if the AI is already "typing".
        guard !isLoading else { return }

        print("Generating proactive patient response...")
        isLoading = true

        Task {
            var patientMessage: ConversationMessage?

            defer { isLoading = false }

            do {
                // Use the exact same service call as a normal message.
                // The prompt will include the latest [System Event] that triggered this call.
                let responseStream = geminiService.generatePatientResponseStream(
                    patientCase: patientCase,
                    session: session,
                    userRole: userRole
                )

                for try await chunk in responseStream {
                    if patientMessage == nil {
                        let newMessage = ConversationMessage(sender: "patient", content: "")
                        newMessage.session = session
                        modelContext.insert(newMessage)
                        messages.append(newMessage)
                        patientMessage = newMessage
                    }
                    patientMessage?.content += chunk
                }
            } catch {
                // Handle error as usual
                let errorMessage = ConversationMessage(sender: "patient", content: "Sorry, an error occurred. (\(error.localizedDescription))")
                errorMessage.session = session
                modelContext.insert(errorMessage)
                messages.append(errorMessage)
            }
        }
    }
    
    // --- END SIMULATION ---
    /// Marks the simulation session as completed and saves it.
    func endSimulation() {
        session.isCompleted = true
        try? modelContext.save()
        print("Session for case \(session.caseId) has been completed.")
    }
    
}
