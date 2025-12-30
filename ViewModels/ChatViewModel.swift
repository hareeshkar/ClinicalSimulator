import Foundation
import SwiftData
import UIKit

@MainActor
class ChatViewModel: ObservableObject, Hashable, Identifiable { // Conform to Identifiable

    @Published var messages: [ConversationMessage] = []
    @Published var isLoading: Bool = false
    
    let session: StudentSession
    let patientCase: PatientCase
    private let geminiService = GeminiService()
    let modelContext: ModelContext // Made this public for SimulationView
    let userRole: String
    
    // ✅ ADD: Progress sync service for cloud synchronization
    private let progressService: UserProgressService
    
    // ✅ NOTIFICATION: Observer for cloud updates
    private var notificationObserver: NSObjectProtocol?

    let id = UUID() // Unique identifier for Identifiable conformance

    init(patientCase: PatientCase, session: StudentSession, modelContext: ModelContext, userRole: String) {
        self.patientCase = patientCase
        self.session = session
        self.modelContext = modelContext
        self.userRole = userRole
        
        // ✅ INITIALIZE: Progress service with model container
        self.progressService = UserProgressService(modelContainer: modelContext.container)
        
        // Load existing messages from the session and sort by timestamp
        self.messages = session.messages.sorted(by: { $0.timestamp < $1.timestamp })
   
        // ✅ NOTIFY: Listen for session updates from cloud
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .sessionUpdatedFromCloud,
            object: session.sessionId,
            queue: .main
        ) { [weak self] _ in
            self?.reloadMessages()
        }
    }
    
    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // ✅ RELOAD: Update messages from session after cloud update
    private func reloadMessages() {
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
        // Save immediately after user input to ensure atomic persistence
        saveSession()
        
        // 2. Set loading state to true. This will immediately show the Typing Indicator in the UI.
        isLoading = true
        
        Task {
            // We declare this here, but we will only create it once we have content.
            var patientMessage: ConversationMessage?
            
            do {
                // ✅ UPDATED: Pass native language to the stream
                let responseStream = geminiService.generatePatientResponseStream(
                    patientCase: patientCase,
                    session: session,
                    userRole: userRole,
                    nativeLanguage: session.user?.nativeLanguage ?? .english
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
                // Save immediately after AI finishes streaming
                saveSession()
                
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
                // Save error state too
                saveSession()
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
                let responseStream = geminiService.generatePatientResponseStream(
                    patientCase: patientCase,
                    session: session,
                    userRole: userRole,
                    nativeLanguage: session.user?.nativeLanguage ?? .english
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
                // Save after proactive response finishes
                saveSession()
            } catch {
                // Handle error as usual
                let errorMessage = ConversationMessage(sender: "patient", content: "Sorry, an error occurred. (\(error.localizedDescription))")
                errorMessage.session = session
                modelContext.insert(errorMessage)
                messages.append(errorMessage)
                // Save error state for proactive responses as well
                saveSession()
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
    
    // MARK: - AI Preceptor (Consult Attending) - Enhanced Implementation
    
    /// Requests a Socratic hint from the AI attending physician.
    /// Includes smart cooldown, progressive hint levels, and native language support.
    func consultAttending() {
        guard !isLoading else { 
            print("⚠️ Attending is already responding...")
            return 
        }
        
        // Smart cooldown: Prevent spam requests (minimum 10 seconds between hints)
        let lastAttendingMessage = messages.last { $0.sender == "attending" }
        if let lastHintTime = lastAttendingMessage?.timestamp,
           Date().timeIntervalSince(lastHintTime) < 10 {
            print("⚠️ Please wait before requesting another hint.")
            return
        }
        
        isLoading = true
        
        // Decode the full case JSON to access ground truth
        guard let data = patientCase.fullCaseJSON.data(using: .utf8),
              let caseDetail = try? JSONDecoder().decode(EnhancedCaseDetail.self, from: data) else {
            print("❌ Failed to decode case details for attending consultation.")
            isLoading = false
            return
        }
        
        Task {
            do {
                // Get progressive hint based on how many hints already requested
                let hint = try await geminiService.generatePreceptorHint(
                    session: session,
                    caseDetail: caseDetail,
                    hintLevel: 1, // The service auto-calculates progressive level
                    nativeLanguage: session.user?.nativeLanguage ?? .english,
                    isSameSection: false
                )
                
                // Create a distinct "attending" message for UI styling
                let attendingMessage = ConversationMessage(sender: "attending", content: hint)
                attendingMessage.session = session
                
                await MainActor.run {
                    modelContext.insert(attendingMessage)
                    messages.append(attendingMessage)
                    saveSession()
                    isLoading = false
                    
                    // Haptic feedback for successful hint delivery
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    
                    print("✅ Attending hint delivered successfully.")
                }
            } catch {
                print("❌ Failed to get attending hint: \(error.localizedDescription)")
                await MainActor.run {
                    // Provide a fallback hint if API fails
                    let fallbackMessage = ConversationMessage(
                        sender: "attending",
                        content: "Take a step back and review the vital signs systematically. What patterns stand out?"
                    )
                    fallbackMessage.session = session
                    modelContext.insert(fallbackMessage)
                    messages.append(fallbackMessage)
                    saveSession()
                    isLoading = false
                }
            }
        }
    }
    
    // Get hint for panel display (without adding to conversation)
    func getHintForPanel(isSameSection: Bool = false) async throws -> String {
        // Decode the full case JSON to access ground truth
        guard let data = patientCase.fullCaseJSON.data(using: .utf8),
              let caseDetail = try? JSONDecoder().decode(EnhancedCaseDetail.self, from: data) else {
            throw NSError(domain: "ChatViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode case details"])
        }
        
        // Get progressive hint based on how many hints already requested
        return try await geminiService.generatePreceptorHint(
            session: session,
            caseDetail: caseDetail,
            hintLevel: 1, // The service auto-calculates progressive level
            nativeLanguage: session.user?.nativeLanguage ?? .english,
            isSameSection: isSameSection
        )
    }
    
    // Public helper for robust persistence with cloud sync
    func saveSession() {
        do {
            // 1. Save to local SwiftData (instant, main thread)
            try modelContext.save()
            print("✅ [ChatViewModel] Local save successful.")
            
            // 2. Sync to cloud (background, fire-and-forget)
            // Capture session reference for background task
            let sessionToSync = self.session
            Task.detached(priority: .utility) {
                await self.progressService.uploadSession(sessionToSync)
            }
        } catch {
            print("❌ [ChatViewModel] Failed to save session: \(error.localizedDescription)")
        }
    }
    
}
