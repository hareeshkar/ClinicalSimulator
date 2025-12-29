import Foundation
import FirebaseAI // This is the ONLY import you need for AI.
final class GeminiService {

    // MARK: - AI Model Initialization (Correct way)
    private let model = FirebaseAI.firebaseAI(backend: .googleAI()).generativeModel(modelName: "gemini-2.5-flash-lite")

    // MARK: - Shared Helper Functions
    
    // MARK: - Sliding Window Logic (Risk C Mitigation)
    
    /// Creates a unified, time-ordered event log with Clinical Priority Sliding Window optimization.
    /// 
    /// **ARCHITECTURE DECISION:**
    /// - **KEEP ALL** performed actions (Labs, Meds, Vitals) → Medical history is absolute
    /// - **KEEP LAST 100** conversation turns → Generous context window for deep clinical reasoning
    /// - **SUMMARIZE/DROP** older conversation → Prevents token overflow while maintaining medical continuity
    /// 
    /// **RATIONALE:**
    /// 1. Static medical facts (allergies, PMH) are injected from JSON prompt, not chat history
    /// 2. 100 messages ≈ 30-45 minutes of conversation (sufficient for one clinical encounter)
    /// 3. Prevents latency degradation and cost bloat in extended sessions
    /// 4. Preserves physiological state integrity (all actions retained)
    /// 
    /// - Parameters:
    ///   - session: The `StudentSession` containing the messages and actions.
    ///   - allStates: A dictionary of all possible states for the case, used to determine the patient's state at each event.
    /// - Returns: A formatted string representing the chronological history of the simulation.
    private func generateChronologicalLog(for session: StudentSession, with allStates: [String: StateDetail]) -> String {
        
        // 1. Separate inputs - Sort messages chronologically
        let allMessages = session.messages.sorted { $0.timestamp < $1.timestamp }
        let allActions = session.performedActions.sorted { $0.timestamp < $1.timestamp }
        
        // 2. Apply Sliding Window to Conversation ONLY
        // ✅ OPTIMIZED: 100 messages = ~50 exchange pairs, sufficient for deep clinical context
        let maxMessagesToKeep = 100
        let conversationToKeep: [ConversationMessage]
        let wasTruncated: Bool
        
        if allMessages.count > maxMessagesToKeep {
            // Keep the last 100 messages (most recent context)
            conversationToKeep = Array(allMessages.suffix(maxMessagesToKeep))
            wasTruncated = true
        } else {
            conversationToKeep = allMessages
            wasTruncated = false
        }
        
        // 3. Map to Tuple Format for Unified Timeline
        let conversationEvents = conversationToKeep.map {
            (timestamp: $0.timestamp, description: "\($0.sender.capitalized): \($0.content)")
        }
        
        // ✅ KEY DECISION: We keep ALL action events.
        // Medical interventions define the patient's physiological reality.
        // Even if conversation is truncated, the AI MUST know:
        // - What medications were given
        // - What tests were ordered
        // - What procedures were performed
        // This ensures clinical accuracy and prevents simulation state corruption.
        let actionEvents = allActions.map {
            (timestamp: $0.timestamp, description: "[System Event] Student administered: \($0.actionName). Justification: \($0.reason ?? "None provided.")")
        }
        
        // 4. Merge and Sort by Timestamp
        let mergedEvents = (conversationEvents + actionEvents).sorted { $0.timestamp < $1.timestamp }
        
        // 5. State Mapping Logic
        let triggerToStateMap = allStates.reduce(into: [String: String]()) { result, state in
            if let trigger = state.value.trigger {
                result[trigger] = state.key
            }
        }
        
        let stateChangeEvents = session.performedActions.compactMap { action -> (Date, String)? in
            guard let triggeredStateName = triggerToStateMap[action.actionName] else { return nil }
            return (action.timestamp, triggeredStateName)
        }.sorted { $0.0 < $1.0 }
        
        // 6. Build Log String with Optional Truncation Notice
        var logString = ""
        
        if wasTruncated {
            logString += """
            [...Earlier conversation history summarized: Patient and medical student have been discussing symptoms and clinical findings. \
            All medical actions and interventions are preserved below. Focus on recent context...]\n\n
            """
        }
        
        let eventLines = mergedEvents.map { event in
            let activeStateName = stateChangeEvents.last { $0.0 <= event.timestamp }?.1 ?? "initial"
            let timeString = event.timestamp.formatted(date: .omitted, time: .standard)
            return "[\(timeString)] [Patient State: \(activeStateName.capitalized)] \(event.description)"
        }
        
        logString += eventLines.joined(separator: "\n")
        
        return logString
    }

    // MARK: - Generate Patient Response for Simulation (Streaming)
    // CHANGE: This function no longer returns a single 'String'.
    // It now returns an 'AsyncThrowingStream' that yields string chunks as they are generated by the AI.
    // This allows the UI to display the response word-by-word, creating a "typing" effect.
    func generatePatientResponseStream(
        patientCase: PatientCase,
        session: StudentSession,
        userRole: String,
        nativeLanguage: NativeLanguage = .english  // ✅ NEW: Accept native language
    ) -> AsyncThrowingStream<String, Error> {
        // Decode the case detail if available so we can extract persona info.
        let caseDetail: EnhancedCaseDetail?
        if let data = patientCase.fullCaseJSON.data(using: .utf8) {
            caseDetail = try? JSONDecoder().decode(EnhancedCaseDetail.self, from: data)
        } else {
            caseDetail = nil
        }
        // Build the persona-driven prompt.
        let prompt = buildPatientPrompt(
            session: session,
            caseDetail: caseDetail,
            userRole: userRole,
            nativeLanguage: nativeLanguage  // ✅ PASS IT
        )
        // Create and return the streaming wrapper.
        return AsyncThrowingStream { continuation in
            Task { @Sendable in
                do {
                    // Use the single shared model for all AI work (streaming patient output).
                    let contentStream = try model.generateContentStream(prompt)
                    for try await chunk in contentStream {
                        if let text = chunk.text {
                            continuation.yield(text)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // ✅ UPDATED: Enhanced with learner profile including native language
    private func buildPatientPrompt(
        session: StudentSession,
        caseDetail: EnhancedCaseDetail?,
        userRole: String,
        nativeLanguage: NativeLanguage = .english
    ) -> String {
        var learnerProfileBlock = ""
        if let user = session.user {
            let genderString = ((user.gender ?? .preferNotToSay) == .preferNotToSay) ? "Not disclosed" : (user.gender ?? .preferNotToSay).rawValue
            var ageString = "Age not disclosed"
            if let dob = user.dateOfBirth {
                let age = Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 0
                ageString = "\(age) years old"
            }
            
            let nativeLanguageDisplay = user.nativeLanguage.displayName
            
            learnerProfileBlock = """
            
            --- CONTEXT: WHO YOU ARE TALKING TO (THE LEARNER'S PROFILE) ---
            Role: \(userRole)
            Gender: \(genderString)
            Age: \(ageString)
            Native Language: \(nativeLanguageDisplay)
            
            **CRITICAL INSTRUCTION - LANGUAGE OF RESPONSE:**
            ⚠️ **YOU MUST RESPOND IN \(nativeLanguage.responseLanguage)** ⚠️
            
            **MEDICAL TERMINOLOGY ACCURACY:**
            - Use authentic medical terms as spoken by native healthcare professionals in \(nativeLanguage.displayName)
            - For Tamil: Use proper Tamil medical vocabulary (e.g., "இதய வலி" for chest pain, "மூச்சுத் திணறல்" for shortness of breath)
            - For Sinhala: Use proper Sinhala medical vocabulary (e.g., "හුස්ම ගැනීමේ අපහසුතාව" for breathing difficulty)
            - Speak as a real patient would describe symptoms, not as a medical textbook
            - Use colloquial expressions and local idioms naturally
            - Do NOT translate word-for-word from English
            
            **CULTURAL COMMUNICATION STYLE:**
            - If the learner's native language is Tamil, you may occasionally weave in culturally relevant expressions, references to Tamil medical traditions, or acknowledge Tamil healthcare contexts naturally.
            - If the learner's native language is Sinhala, you may occasionally weave in culturally relevant expressions, references to Sinhala/Sri Lankan medical contexts, or acknowledge local healthcare practices naturally.
            - If the learner's native language is English, communicate clearly and professionally without forced cultural references.
            
            **AGE & GENDER-APPROPRIATE INTERACTION:**
            - If you are significantly older than the learner, you may use respectful terms naturally and sparingly
            - If the learner is much younger than you, be slightly more explanatory
            - If closer to your age or older, speak more as peers
            - Adjust formality based on cultural context and age difference
            - These adjustments should feel natural, not forced
            
            **STRICT RULE:** Do NOT mention their native language, gender, age, or profile explicitly in your responses.
            """
        }
        // --- Enhancement 1: Extract the "Patient Persona" ---
        var personaBlock = "You are role-playing as a patient."
        if let detail = caseDetail {
            let profile = detail.patientProfile
            // Determine current state name by matching performed actions to state triggers.
            let currentStateName = session.performedActions.compactMap { action in
                return detail.dynamicState.states.first { $0.value.trigger == action.actionName }?.key
            }.last ?? "initial"
            let currentStateDescription = detail.dynamicState.states[currentStateName]?.description ?? "The patient is in their initial state."
            // ✅ FULLY DYNAMIC: No hardcoded roles
            personaBlock = """
            --- PATIENT PERSONA (Your Character Sheet) ---
            Name: \(profile.name)
            Age: \(profile.age)
            Gender: \(profile.gender)
            Current Physical State: \(currentStateDescription)

            --- CONTEXT: WHO YOU ARE TALKING TO ---
            You are speaking with a **\(userRole)**.

            **CRITICAL INSTRUCTION:** 
            Analyze their role title to infer their level of clinical training and experience. Then, adjust your communication style to match:

            - **If the role suggests they are learning** (words like "Student", "First Year", "Beginner"): Be patient and educational. Explain symptoms clearly. Encourage questions.
            
            - **If the role suggests moderate experience** (words like "Resident", "Intern", "Fellow", "Senior Student"): Be direct but detailed. Assume basic clinical knowledge.
            
            - **If the role suggests expertise** (words like "Attending", "Consultant", "Senior Clinician", "Physician"): Be concise and professional. Assume they know what to ask.

            **Your goal:** Infer their experience level from the role title and match your responses accordingly, without ever mentioning their role explicitly.
            """
        }
        // --- Enhancement 3: Reframe the chronological log as 'Memories' ---
        let chronologicalLog = generateChronologicalLog(for: session, with: caseDetail?.dynamicState.states ?? [:])
        // --- Enhancement 2: Add explicit emotional state & acting instructions ---
        // ✅ NEW: Create a special instruction for the first turn.
        var openingLineInstruction = ""
        if session.messages.isEmpty {
            openingLineInstruction = "6.  **This is the VERY FIRST turn of the conversation.** Your response MUST be an initial greeting to the student (the doctor) that reflects your 'Current Physical State'. For example, if you are in distress, you might say '(wincing) Hello doctor, thank you for coming... the pain is just awful.' If you are stable, a simple 'Hello doctor.' is fine."
        }

        let fullPrompt = """
        \(personaBlock)
        \(learnerProfileBlock)

        --- YOUR ACTING INSTRUCTIONS (ULTRA-STRICT RULES) ---
        1.  **Embody the Persona:** You MUST act as the person described in the 'PATIENT PERSONA' section.
        2.  **RESPOND IN \(nativeLanguage.responseLanguage):** Your entire response MUST be in \(nativeLanguage.responseLanguage). Speak authentically as a native speaker, using proper medical terminology as a real patient would.
        3.  **Medical Accuracy:** Use correct medical terms in the native language. Describe symptoms as a patient would naturally express them.
        4.  **Show, Don't Just Tell:** Express your state through natural dialogue. Include non-verbal cues in parentheses, like (wincing), (speaks slowly).
        5.  **Use Your Memories:** The 'PATIENT'S EXPERIENCE' log is your memory of what has happened. Events marked '[SYSTEM]' are actions performed on you by the student.
        6.  **Stay Natural:** DO NOT mention "[SYSTEM]", your "state", "memories", or the learner's native language. Just act.
        \(openingLineInstruction)

        --- PATIENT'S EXPERIENCE & MEMORIES (CHRONOLOGICAL) ---
        \(chronologicalLog.isEmpty ? "The simulation has just begun. There is no history yet." : chronologicalLog)

        ---
        Now, based on the last event in your memories (or your initial state if memories are empty), provide the next line of dialogue **IN \(nativeLanguage.responseLanguage)**.

        Patient:
        """
        return fullPrompt
    }

    // MARK: - Generate AI-Powered Student Evaluation
    // NOTE: This function is NOT streamed because it needs to return a complete JSON object at once.
    func generateEvaluation(
        caseDetail: EnhancedCaseDetail,
        session: StudentSession,
        userRole: String,
        nativeLanguage: NativeLanguage = .english  // ✅ NEW: Accept native language
    ) async throws -> ProfessionalEvaluationResult {
        let prompt = buildEvaluationPrompt(
            caseDetail: caseDetail,
            session: session,
            userRole: userRole,
            nativeLanguage: nativeLanguage  // ✅ PASS IT
        )
        let response = try await model.generateContent(prompt)

        guard var text = response.text else {
            throw NSError(domain: "GeminiService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No text in AI response."])
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "")

        let data = Data(text.utf8)
        do {
            return try JSONDecoder().decode(ProfessionalEvaluationResult.self, from: data)
        } catch {
            print("JSON DECODING FAILED: \(error)")
            print("RAW AI RESPONSE: \(text)")
            throw error
        }
    }

    // ✅ UPDATED: Stricter evaluation with cultural/linguistic awareness
    private func buildEvaluationPrompt(
        caseDetail: EnhancedCaseDetail,
        session: StudentSession,
        userRole: String,
        nativeLanguage: NativeLanguage = .english
    ) -> String {
        let differentialString = session.differentialDiagnosis.isEmpty 
            ? "**NOT PROVIDED** (Student did not submit a differential diagnosis)"
            : session.differentialDiagnosis.map {
                "Diagnosis: \($0.diagnosis), Confidence: \(Int($0.confidence * 100))%, Rationale: '\($0.rationale)'"
            }.joined(separator: "\n")
        
        let chronologicalLog = generateChronologicalLog(for: session, with: caseDetail.dynamicState.states)
        
        let learnerName = session.user?.fullName ?? "Learner"
        let nativeLanguageDisplay = session.user?.nativeLanguage.displayName ?? "English"
        let learnerGender = session.user?.gender?.rawValue ?? "Not disclosed"
        var learnerAge = "Age not disclosed"
        if let dob = session.user?.dateOfBirth {
            let age = Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 0
            learnerAge = "\(age) years old"
        }
        
        return """
        You are Dr. Evelyn Reed, a board-certified clinical educator with 20 years of experience.

        **CRITICAL CONTEXT ABOUT THE LEARNER:**
        - Role: "\(userRole)"
        - Name: \(learnerName)
        - Native Language: \(nativeLanguageDisplay)
        - Gender: \(learnerGender)
        - Age: \(learnerAge)

        **EVALUATION LANGUAGE & CULTURAL SENSITIVITY INSTRUCTION:**
        
        1. **Primary Language:** Provide the entire evaluation in **\(nativeLanguage.responseLanguage)**
        
        2. **Medical Terminology Handling:**
           - When writing in Tamil or Sinhala, provide English medical terms in parentheses for clarity
           - Example (Tamil): "இதய நோய்க்குறி (Myocardial Infarction)"
           - Example (Sinhala): "හෘද ආබාධය (Cardiac Arrest)"
           - This ensures medical accuracy while maintaining native language fluency
        
        3. **Gender-Aware Addressing (DO NOT EXPLICITLY MENTION, JUST ADAPT TONE):**
           - For Tamil male learners: Use respectful tone appropriate for "மாணவன்" (student - male)
           - For Tamil female learners: Use respectful tone appropriate for "மாணவி" (student - female)
           - For Sinhala male learners: Use tone appropriate for "ශිෂ්‍යයා" (student - male)
           - For Sinhala female learners: Use tone appropriate for "ශිෂ්‍යාව" (student - female)
           - Adjust formality and respect level based on age and cultural norms
           - Never explicitly state their gender in feedback
        
        4. **Age-Appropriate Feedback:**
           - For younger learners (20s): More encouragement, detailed guidance
           - For mid-career learners (30s-40s): Direct feedback, peer-level communication
           - For senior learners (50+): Respectful, concise, assumes significant experience
        
        **YOUR TASK:** 
        Analyze the role title "\(userRole)" to infer their stage of training and expected competency level. 
        Consider their cultural and linguistic background to provide feedback that is sensitive, respectful, and tailored to their perspective.
        
        **CRITICAL INSTRUCTION FOR MISSING OR INCOMPLETE INPUT:**
        - If the student provided **NO differential diagnosis**, automatically assign **0% for "Differential Quality"** and note this as a critical failure in feedback.
        - If the student provided **NO justifications** for their diagnoses, heavily penalize in "Differential Quality" (maximum 30%).
        - If the student ordered **NO tests whatsoever**, assign **0% for "Diagnostic Stewardship"**.
        - If the student's conversation log shows **minimal engagement** (fewer than 3 meaningful exchanges), penalize "Prioritization & Timeliness" (cap at 40%).
        - **Be unforgiving for lack of effort.** Zero input = zero credit for that domain.

        **ULTRA-STRICT CALIBRATION PRINCIPLES (SIGNIFICANTLY HARDER THAN BEFORE):**

        1. **Early/Junior Learners** (Look for clues like "Student", "First Year", "MS1", "MS2", "Year 1"):
           - **BASELINE EXPECTATIONS:** Must demonstrate foundational clinical reasoning
           - **Differential Quality:** Correct diagnosis in top 3 = 55-70%; Missing = <35%
           - **Diagnostic Stewardship:** Ordering 1-2 unnecessary tests = 65-80%; Shotgun approach = 40-60%
           - **Harm Avoidance:** ANY dangerous action = <60%; Delayed recognition of red flags = 60-75%
           - **Prioritization & Timeliness:** Taking excessive time or poor sequencing = 50-70%; Eventually correct = 70-85%
           - Good performance: 60-75%; Concerning gaps: <55%

        2. **Intermediate Learners** (Look for clues like "MS3", "MS4", "Senior Student", "Year 2+"):
           - **COMPETENCY REQUIRED:** Must show clinical competence
           - **Differential Quality:** Correct diagnosis in top 2 = 65-80%; Top 3 = 60-70%; Missing = <45%
           - **Diagnostic Stewardship:** Unnecessary testing = 55-70%; Missing critical test = 50-65%
           - **Harm Avoidance:** Serious error = <70%; Minor safety concern = 70-85%
           - **Prioritization & Timeliness:** Poor sequencing = 55-75%; Significant delays = 60-80%
           - Good performance: 65-80%; Deficiency requiring remediation: <60%

        3. **Advanced Learners** (Look for clues like "Intern", "Resident", "Fellow", "Practicing"):
           - **EXPERT STANDARDS:** Near-expert performance expected
           - **Differential Quality:** Correct diagnosis #1 or #2 = 70-90%; Lower = <50%; Missing = <30%
           - **Diagnostic Stewardship:** Any inefficiency = 40-70%; Missing critical tests = 30-60%
           - **Harm Avoidance:** ANY critical delay = <70%; Contraindicated treatment = <50%
           - **Prioritization & Timeliness:** Poor sequencing = 40-70%; Life-threatening delays = <40%
           - Critical incompetency (<40%) requires immediate intervention

        4. **Expert Clinicians** (Look for clues like "Attending", "Consultant", "Senior Clinician", "Physician"):
           - **GOLD STANDARD:** Perfection expected
           - **Any significant error:** Scores 50-80% across all domains
           - **Evaluate:** System-level thinking, teaching ability, leadership

        **HARM AVOIDANCE - STRICTER PENALTIES:**
        - Do NOT give high marks just for avoiding obvious disasters
        - Penalize heavily for:
          * Delayed recognition of danger signs (reduce by 15-25%)
          * Ordering tests before critical interventions (reduce by 10-20%)
          * Missing contraindications (reduce by 20-30%)
          * Suboptimal monitoring (reduce by 10-15%)
        - Perfect harm avoidance (95-100%) requires: early recognition, appropriate precautions, correct sequencing

        **PRIORITIZATION & TIMELINESS - NO MORE EASY MARKS:**
        - Do NOT give high marks for "eventually getting it right"
        - Penalize heavily for:
          * Taking excessive time to recognize urgency (reduce by 20-30%)
          * Poor intervention sequencing (reduce by 15-25%)
          * Unnecessary delays for non-critical steps (reduce by 10-20%)
          * Failure to recognize time-sensitive conditions (reduce by 25-35%)
        - High scores (85-100%) require: rapid recognition, perfect sequencing, efficient execution

        **DIAGNOSTIC STEWARDSHIP - MUCH STRICTER:**
        - Penalize MORE for:
          * "Shotgun" approach (ordering everything) = maximum 50%
          * Ordering redundant tests = reduce by 15-20%
          * Missing obvious first-line tests = reduce by 20-30%
          * Ordering without clear rationale = reduce by 10-15%

        **DIFFERENTIAL QUALITY - STRICTER STANDARDS:**
        - Ranking matters significantly:
          * Correct diagnosis at #1: baseline score
          * Correct diagnosis at #2: reduce by 10-15%
          * Correct diagnosis at #3: reduce by 15-25%
          * Correct diagnosis at #4+: reduce by 25-35%
        - Weak rationales: reduce by 15-25% even if diagnosis is correct

        **FAIRNESS MANDATE:** Be honest and strict. Low performance = low scores. This is a professional simulator, not a participation trophy system.
        
        **ADDRESS THE LEARNER DIRECTLY:** When writing the debrief, address \(learnerName) by name and speak to their specific performance gaps and pathway to improvement. Use culturally appropriate tone based on their age and gender context.
        
        **CRITICAL INSTRUCTION: Your response must contain ONLY valid JSON, starting immediately with '{'. No preamble, no commentary, no markdown formatting.**
        
        **FOR TAMIL/SINHALA RESPONSES:** Include English medical terms in parentheses after native language terms for clarity. Example: "இதய பிடிப்பு (Myocardial Infarction)"

        --- GROUND TRUTH CASE FILE (FOR YOUR EYES ONLY) ---
        \(caseDetail.toJSONString())

        --- LEARNER'S PERFORMANCE LOG ---
        Learner Name: \(learnerName)
        Learner Role: \(userRole)
        
        Structured Differential Diagnosis:
        \(differentialString)
        
        Chronological Log with Justifications:
        ```
        \(chronologicalLog.isEmpty ? "**NO ACTIVITY RECORDED** (Student did not engage with the case)" : chronologicalLog)
        ```

        --- REQUIRED JSON RESPONSE STRUCTURE ---
        {
          "caseNarrative": "<2-3 sentence factual summary in \(nativeLanguage.responseLanguage) with English medical terms in parentheses>",
          "competencyScores": {
            "Differential Quality": <Int>,
            "Diagnostic Stewardship": <Int>,
            "Harm Avoidance": <Int>,
            "Prioritization & Timeliness": <Int>
          },
          "differentialAnalysis": "<Analysis in \(nativeLanguage.responseLanguage) with English terms in parentheses. Be specific about what they got right and wrong.>",
          "calibrationAnalysis": "<1-2 sentence confidence analysis in \(nativeLanguage.responseLanguage).>",
          "keyStrengths": ["<Specific positive observation in \(nativeLanguage.responseLanguage) with English terms>"],
          "criticalFeedback": ["<Specific error in \(nativeLanguage.responseLanguage) with English terms, framed professionally but clearly>"],
          "debrief": {
             "finalDiagnosis": "<Correct diagnosis in native language (English term)>",
             "mainLearningPoint": "<Clinical pearl in \(nativeLanguage.responseLanguage) with English terms, tailored to their level>",
             "alternativeStrategy": "<Better approach in \(nativeLanguage.responseLanguage) with English terms, for their training stage>"
          }
        }
        """
    }

    // MARK: - Case Generation Function
    // NOTE: This function is also NOT streamed as it must return a complete and valid JSON object.
    func generateNewCase(from template: CaseTemplate) async throws -> String {

        // 1. Construct the detailed prompt.
        let prompt = buildCaseGenerationPrompt(from: template)

        // 2. Make the API call to Gemini.
        let response = try await model.generateContent(prompt)

        // 3. Extract and clean up the response text.
        guard var text = response.text else {
            throw NSError(domain: "GeminiService", code: 2, userInfo: [NSLocalizedDescriptionKey: "No text in AI response for case generation."])
        }

        // Clean up markdown formatting that the AI sometimes adds.
        text = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "")

        // 4. Return the clean JSON string.
        return text
    }

    private func buildCaseGenerationPrompt(from template: CaseTemplate) -> String {
        // This long, detailed prompt remains unchanged.
        return """
        You are an expert medical education content creator and simulation author. Your task is to generate a single, complete, detailed, and clinically plausible patient case file as RAW JSON that exactly conforms to the REQUIRED SCHEMA below. The output will be parsed and used in a simulation engine, so strictness and internal consistency are mandatory.
        IMPORTANT RULES (READ CAREFULLY):
        1) STRICT SCHEMA: Adhere EXACTLY to the JSON schema shown below. Do not add, remove, rename, or nest keys differently. Keys, types, and structure must match exactly.
        2) RAW JSON ONLY: Respond ONLY with valid JSON text. Do NOT include any surrounding explanation, markdown, comments, or code fences. The very first character must be '{' and the output must be parseable JSON.
        3) DATA TYPES & FORMATS: Respect types precisely. Examples: ages must be strings like "24 years old"; vitals that are integers must be JSON numbers (no quotes); bloodPressure must be a string in the form "SYS/DIA mmHg"; oxygenSaturation must be an integer percent (e.g., 95).
        4) MEDICAL ACCURACY & CONSISTENCY: All clinical details (history, vitals, exam, results, and progression) must be medically plausible and internally consistent and must logically lead to the provided final diagnosis.
        5) UNIQUE CASE ID: The "caseId" must be a unique string using the specialty and a random 3–5 digit integer separated by a hyphen, e.g. "CARD-RAND-483".
        6) ORDERABLE ITEMS CATEGORIES: For every object in the `orderableItems` array you MUST include a `category` key. Use succinct, clinical categories (choose the best fit): e.g., "Lab", "Imaging", "Treatment", "Procedure", "Consult", "Physical Exam Maneuver". Be consistent across items.
        7) TRIGGER ↔ TEST NAME CONSISTENCY (CRITICAL): For every non-"initial" state in `dynamicState.states` (e.g., "stabilizing", "worsening", "improving", "resolved"), the state's `trigger` string must EXACTLY match the `testName` value of at least one object in `dataSources.orderableItems`. This link is required for the simulation engine to map actions to state changes.
        8) MULTI-STATE PROGRESSION: Provide at minimum these states under `dynamicState.states`: "initial" and one or more intermediate state(s) (e.g., "stabilizing" or "worsening") and a final state named either "improving" or "resolved". Each state (except initial) must include a `trigger`, a `description`, and any vitals that changed (use the same keys as in `initialPresentation.vitals`).
        9) VITALS CONSISTENCY: Vitals shown in state objects must be clinically plausible and show logical trends from one state to another.
        10) SUMMARY: Include a 1–2 sentence `summary` that accurately encapsulates the presentation and ties to the final diagnosis.
        11) NO PLACEHOLDERS: Do not return placeholder text like "<Generate...>". All fields must be fully populated with concrete values.
        12) LENGTH: Keep the JSON compact but complete; do not include verbose narrative outside the fields.
        ---
        CASE CONTEXT (use these values to generate the case):
        - Title: \(template.title)
        - Specialty: \(template.specialty)
        - Difficulty: \(template.difficulty)
        - Chief Complaint: \(template.chiefComplaint)
        - Final Diagnosis: \(template.finalDiagnosis)
        - Icon Name: \(template.iconName)
        ---
        REQUIRED JSON SCHEMA (OUTPUT MUST MATCH THIS EXACTLY):
        {
          "metadata": {
            "caseId": "<SPECIALTY-RAND-XXX>",
            "title": "<String>",
            "specialty": "<String>",
            "difficulty": "<String>",
            "iconName": "<String>"
          },
          "patientProfile": {
            "name": "<String>",
            "age": "<String - years old>",
            "gender": "<Male|Female>"
          },
          "initialPresentation": {
            "chiefComplaint": "<String>",
            "summary": "<1-2 sentence summary>",
            "history": {
              "presentIllness": "<Detailed HPI - timeline, symptoms, modifiers>",
              "pastMedicalHistory": {
                "medicalHistory": "<List of chronic conditions>",
                "surgicalHistory": "<List of past surgeries and dates>",
                "medications": "<List of current medications and dosages>",
                "allergies": "<List of known allergies and reactions>",
                "socialHistory": "<Relevant social history, e.g., smoking, alcohol>"
              }
            },
            "vitals": {
              "heartRate": <Int>,
              "respiratoryRate": <Int>,
              "bloodPressure": "<String - e.g., '120/80 mmHg'>",
              "oxygenSaturation": <Int>
            }
          },
          "dynamicState": {
            "states": {
              "initial": {
                "description": "<Describe patient's initial state>",
                "physicalExamFindings": { "<System>": "<Finding>" }
              },
              "stabilizing": {
                "trigger": "<Supportive treatment exact name - must match a testName in orderableItems>",
                "description": "<State after supportive step>",
                "vitals": { "heartRate": <Int>, "respiratoryRate": <Int>, "bloodPressure": "<String>", "oxygenSaturation": <Int> }
              },
              "improving": {
                "trigger": "<Definitive treatment exact name - must match a testName in orderableItems>",
                "description": "<State after definitive treatment>",
                "vitals": { "heartRate": <Int>, "respiratoryRate": <Int>, "bloodPressure": "<String>", "oxygenSaturation": <Int> }
              }
            }
          },
          "dataSources": {
            "orderableItems": [
              {
                "testName": "<Test/Treatment Name - must match triggers>",
                "result": "<Result or treatment outcome>",
                "category": "<Lab|Imaging|Treatment|Procedure|Consult|Physical Exam Maneuver>"
              },
              {
                "testName": "<Another Test/Treatment Name>",
                "result": "<Result>",
                "category": "<Category>"
              }
            ]
          }
        }
        ---
        NOTES/EXAMPLES FOR AUTHORING (do NOT output these lines in the JSON):
        • Example caseId: "NEURO-RAND-842" (specialty uppercase + "-RAND-" + random digits)
        • Age example: "67 years old"
        • Valid categories: prefer one of the listed canonical categories. Use the shortest accurate label.
        • At least one orderableItems entry must be a Treatment/Procedure whose `testName` exactly matches the `trigger` of the "improving" state (e.g., "Administer IV Ceftriaxone 2 g IV"), and at least one orderableItems entry should match any intermediate state's trigger.
        • Make sure vitals are numbers (no quotes) where the schema expects numbers.
        Generate one fully populated case now, following every rule above.
        """
    }

    // MARK: - AI Preceptor (Consult Attending) - Enhanced Socratic Teaching System

    /// Generates a progressive, Socratic hint from a virtual attending physician.
    /// The hint difficulty adapts based on how many hints the student has already requested.
    /// - Parameters:
    ///   - session: The current student session history.
    ///   - caseDetail: The full case details (ground truth).
    ///   - hintLevel: The progressive hint level (1 = subtle, 2 = specific, 3 = direct). The service will auto-adjust.
    ///   - nativeLanguage: The learner's native language for response.
    /// - Returns: A string containing the hint.
    func generatePreceptorHint(
        session: StudentSession,
        caseDetail: EnhancedCaseDetail,
        hintLevel: Int = 1,
        nativeLanguage: NativeLanguage = .english,
        isSameSection: Bool = false
    ) async throws -> String {

        // Use the already-defined chronological log generator inside this class
        let chronologicalLog = generateChronologicalLog(for: session, with: caseDetail.dynamicState.states)

        // Count how many "attending" messages already exist to determine hint progression
        let previousHintsCount = session.messages.filter { $0.sender == "attending" }.count
        let effectiveHintLevel = min(previousHintsCount + 1, 3) // Progressive difficulty: 1, 2, or 3

        // Get learner profile for personalization
        let learnerName = session.user?.fullName ?? "Learner"
        let userRole = session.user?.roleTitle ?? "Learner"
        var learnerAge = "Age not disclosed"
        if let dob = session.user?.dateOfBirth {
            let age = Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 0
            learnerAge = "\(age) years old"
        }

        let hintLevelDescription: String
        let instructionStyle: String

        switch effectiveHintLevel {
        case 1:
            hintLevelDescription = "LEVEL 1 (SUBTLE) - Socratic questioning only"
            instructionStyle = """
            Ask 1-2 thought-provoking questions that make the student reconsider their approach. Point to a pattern they might have missed WITHOUT naming it.
            Example: "Looking at the vital signs again, what's unusual about the oxygen saturation relative to the respiratory rate?"
            """

        case 2:
            hintLevelDescription = "LEVEL 2 (SPECIFIC) - Directed clinical reasoning"
            instructionStyle = """
            Point to a specific system or clinical domain to investigate and mention relevant red flags or concerning patterns. You may suggest a category of tests but NOT the exact diagnosis.
            Example: "The combination of fever, hypotension, and tachycardia suggests a systemic inflammatory response. What conditions cause this triad?"
            """

        case 3:
            hintLevelDescription = "LEVEL 3 (DIRECT) - Strong clinical direction"
            instructionStyle = """
            Provide strong clinical direction about what to do next. Narrow to 2-3 possible diagnoses and recommend specific next steps while asking the student to justify their choice.
            Example: "Given the presentation, consider sepsis or cardiogenic shock. Which fits best with this patient's history?"
            """

        default:
            hintLevelDescription = "LEVEL 1 (SUBTLE)"
            instructionStyle = "Ask the student to re-check the vitals and consider alternate organ systems."
        }

        let prompt = """
        You are a senior attending physician who uses the Socratic method to teach. A medical student has consulted you for guidance on a challenging case.

        --- LEARNER CONTEXT ---
        Name: \(learnerName)
        Age: \(learnerAge)
        Role: \(userRole)
        Native Language: \(nativeLanguage.displayName)

        **LANGUAGE:** Respond entirely in \(nativeLanguage.responseLanguage).

        --- GROUND TRUTH (FOR YOUR EYES ONLY) ---
        Case Title: \(caseDetail.metadata.title)
        Final Diagnosis: \(caseDetail.metadata.finalDiagnosis ?? "Unknown")
        Correct Next Steps: \(caseDetail.dynamicState.states["improving"]?.trigger ?? "Unknown treatment")
        Chief Complaint: \(caseDetail.initialPresentation.chiefComplaint)

        --- STUDENT'S PROGRESS ---
        \(chronologicalLog.isEmpty ? "No activity recorded yet." : chronologicalLog)

        --- TEACHING INSTRUCTION ---
        \(hintLevelDescription)
        \(instructionStyle)
        \(isSameSection ? "\n**SPECIAL NOTE:** The student is asking for another hint on the SAME clinical section where they appear to be stuck. Provide a different approach or perspective on the same challenge. Offer alternative reasoning pathways or ask different questions to help them break through their current mental block." : "")

        Tone: Professional, concise, and Socratic. 2-3 sentences maximum. Do NOT be too lengthy. Do NOT give the final diagnosis.

        Attending's Hint:
        """

        let response = try await model.generateContent(prompt)
        return response.text ?? "Review the patient's presentation and vitals carefully. What patterns do you notice?"
    }
}
// MARK: - Helper Extensions
extension Encodable {
    func toJSONString() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return "Error converting to JSON"
        }
        return string
    }
}

extension [ConversationMessage] {
    func formattedForPrompt() -> String {
        self.map { "\($0.sender.capitalized): \($0.content)" }.joined(separator: "\n")
    }
}
// ✅ THE DEFINITIVE PROFESSIONAL EVALUATION STRUCTURE
struct ProfessionalEvaluationResult: Codable, Hashable {
    let caseNarrative: String
    let competencyScores: [String: Int]
    let differentialAnalysis: String
    let calibrationAnalysis: String? // ✅ NEW: A dedicated analysis of the student's self-awareness.
    let keyStrengths: [String]
    let criticalFeedback: [String]
    let debrief: DebriefSection // ✅ NEW: A structured object for the final debrief screen.
    struct DebriefSection: Codable, Hashable {
        let finalDiagnosis: String
        let mainLearningPoint: String
        let alternativeStrategy: String
    }
    var overallScore: Int {
        let scores = competencyScores.values
        if scores.isEmpty {
            return 0
        }
        // This is now correct for a dictionary of [String: Int]
        let totalScore = scores.reduce(0, +)
        return totalScore / scores.count
    }

    // ✅ THE FIXED MOCK DATA, MATCHING THE NEW STRUCTURE
    static var mock: ProfessionalEvaluationResult {
        ProfessionalEvaluationResult(
            caseNarrative: "The student was presented with a clear case of anaphylactic shock and correctly initiated the critical first-line treatment. The overall management was effective, though timeliness of supportive care could be improved.",
            competencyScores: [
                "Differential Quality": 90,
                "Diagnostic Stewardship": 85,
                "Harm Avoidance": 100,
                "Prioritization & Timeliness": 92
            ],
            differentialAnalysis: "The student's initial differential correctly included anaphylaxis as the primary diagnosis.",
            calibrationAnalysis: "The student was appropriately confident (95%) in their correct leading diagnosis, demonstrating excellent judgment.",
            keyStrengths: ["Rapid administration of IM Epinephrine was the correct and life-saving first step."],
            criticalFeedback: ["There was a notable delay in ordering IV Fluids and Oxygen, which are essential for stabilizing a hypotensive and hypoxic patient."],
            debrief: DebriefSection(
                finalDiagnosis: "Anaphylaxis",
                mainLearningPoint: "For any patient in shock, remember the 'ABC's. After treating the immediate cause, ensure Airway, Breathing (Oxygen), and Circulation (IV Fluids) are addressed immediately.",
                alternativeStrategy: "A better approach would have been to order IV fluids and oxygen concurrently with the administration of epinephrine to more rapidly address circulatory collapse."
            )
        )
    }
}
