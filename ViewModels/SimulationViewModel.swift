// ViewModels/SimulationViewModel.swift

import SwiftUI

@MainActor
class SimulationViewModel: ObservableObject {
    
    // MARK: - Published Properties (The Interface)
    // This is what the UI (PatientMonitorView) observes. It drifts and fluctuates.
    @Published var currentState: StateDetail
    @Published var currentVitals: Vitals
    @Published var currentStateName: String
    
    // MARK: - Internal Physiology State (The Engine)
    // This is the "Goal" state defined by the case JSON.
    private var targetVitals: Vitals
    private var physiologyTimer: Timer?
    
    // MARK: - Properties
    let patientCase: PatientCase
    private let allStates: [String: StateDetail]
    
    var patientProfile: PatientProfile? {
        let data = Data(patientCase.fullCaseJSON.utf8)
        return try? JSONDecoder().decode(EnhancedCaseDetail.self, from: data).patientProfile
    }
    
    // MARK: - Initializer
    init(patientCase: PatientCase, session: StudentSession) {
        self.patientCase = patientCase
        
        let data = Data(patientCase.fullCaseJSON.utf8)
        
        // Attempt to decode the case data.
        guard let detail = try? JSONDecoder().decode(EnhancedCaseDetail.self, from: data) else {
            // --- Failure Path ---
            // If parsing fails, we must initialize ALL properties with placeholder/error data.
            self.allStates = [:]
            self.currentState = StateDetail(description: "Error: Could not load case data.")
            self.currentVitals = .empty
            self.targetVitals = .empty
            self.currentStateName = "error"
            
            // It is now safe to exit the initializer.
            return
        }
        
        // --- Success Path ---
        // All properties are guaranteed to be initialized here.
        self.allStates = detail.dynamicState.states
        
        // 1. Initialize State
        let initialState = allStates["initial"] ?? StateDetail(description: "Error: Initial state not found.")
        self.currentState = initialState
        self.currentStateName = "initial"
        
        // 2. Initialize Vitals (Start at the target immediately for the first load)
        let initialVitals = detail.initialPresentation.vitals
        self.currentVitals = initialVitals
        self.targetVitals = initialVitals

        // 3. Restore History (Re-play actions)
        let triggerToStateMap = allStates.reduce(into: [String: String]()) { result, state in
            if let trigger = state.value.trigger { result[trigger] = state.key }
        }
        
        for performedAction in session.performedActions {
            if let triggeredStateName = triggerToStateMap[performedAction.actionName] {
                // For restoration, we snap instantly so the user doesn't see a 
                // "replay" of vitals drifting when they open the app.
                changeState(to: triggeredStateName, animated: false)
            }
        }
        
        // 4. Start the Living Patient Engine
        startPhysiologyEngine()
    }
    
    deinit {
        physiologyTimer?.invalidate()
    }
    
    // MARK: - State Management
    
    func changeState(to stateName: String, animated: Bool = true) {
        guard let newState = allStates[stateName] else { return }
        
        currentState = newState
        currentStateName = stateName
        
        // Update the TARGET vitals. The Timer loop will handle the drifting.
        if let newVitals = newState.vitals {
            self.targetVitals.heartRate = newVitals.heartRate ?? self.targetVitals.heartRate
            self.targetVitals.respiratoryRate = newVitals.respiratoryRate ?? self.targetVitals.respiratoryRate
            self.targetVitals.oxygenSaturation = newVitals.oxygenSaturation ?? self.targetVitals.oxygenSaturation
            self.targetVitals.bloodPressure = newVitals.bloodPressure ?? self.targetVitals.bloodPressure
        }
        
        // If not animated (e.g., initial load), snap immediately.
        if !animated {
            self.currentVitals = self.targetVitals
        }
    }
    
    // MARK: - Physiology Engine (The Living Patient)
    
    private func startPhysiologyEngine() {
        // ✅ FIX: Create timer and add to RunLoop explicitly with .common mode
        // This ensures the timer fires even during UI interactions (scrolling, dragging, etc.)
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            // Since we're already @MainActor, no need for Task wrapper
            self.updatePhysiology()
        }
        
        // ✅ CRITICAL: Add to main RunLoop with .common mode
        // .common ensures the timer keeps firing during scrolling/UI interactions
        RunLoop.main.add(timer, forMode: .common)
        self.physiologyTimer = timer
    }
    
    private func updatePhysiology() {
        // 1. Heart Rate: Drifts by 1-2 bpm, Jitters by +/- 1 bpm
        if let targetHR = targetVitals.heartRate, var currentHR = currentVitals.heartRate {
            let diff = targetHR - currentHR
            
            if abs(diff) > 2 {
                // If far away, move towards target linearly (Drift)
                currentHR += (diff > 0 ? 2 : -2)
            } else {
                // If close (stable), apply Noise (Jitter)
                currentHR = targetHR + Int.random(in: -2...2)
            }
            currentVitals.heartRate = currentHR
        }
        
        // 2. SpO2: Drifts slowly (1 unit), Jitters rarely
        if let targetSat = targetVitals.oxygenSaturation, var currentSat = currentVitals.oxygenSaturation {
            let diff = targetSat - currentSat
            if abs(diff) > 0 {
                // Move 1 unit at a time (slower than HR)
                currentSat += (diff > 0 ? 1 : -1)
            } else {
                // Occasional flickers (mostly stable)
                if Double.random(in: 0...1) > 0.8 {
                    currentSat = targetSat + Int.random(in: -1...0) // SpO2 usually flickers down, not up > 100
                }
            }
            currentVitals.oxygenSaturation = min(currentSat, 100) // Cap at 100%
        }
        
        // 3. Respiratory Rate: Drifts by 1, Jitters +/- 1
        if let targetRR = targetVitals.respiratoryRate, var currentRR = currentVitals.respiratoryRate {
            let diff = targetRR - currentRR
            if abs(diff) > 1 {
                currentRR += (diff > 0 ? 1 : -1)
            } else {
                currentRR = targetRR + Int.random(in: -1...1)
            }
            currentVitals.respiratoryRate = currentRR
        }
        
        // 4. Blood Pressure: Complex String Parsing
        if let targetBPString = targetVitals.bloodPressure,
           let currentBPString = currentVitals.bloodPressure,
           let targetComps = extractBP(targetBPString),
           let currentComps = extractBP(currentBPString) {
            
            var newSys = currentComps.sys
            var newDia = currentComps.dia
            
            // Systolic Drift
            let sysDiff = targetComps.sys - newSys
            if abs(sysDiff) > 3 {
                newSys += (sysDiff > 0 ? 3 : -3) // BP moves faster than HR
            } else {
                newSys = targetComps.sys + Int.random(in: -2...2) // Jitter
            }
            
            // Diastolic Drift
            let diaDiff = targetComps.dia - newDia
            if abs(diaDiff) > 2 {
                newDia += (diaDiff > 0 ? 2 : -2)
            } else {
                newDia = targetComps.dia + Int.random(in: -1...1)
            }
            
            currentVitals.bloodPressure = "\(newSys)/\(newDia) mmHg"
        } else if currentVitals.bloodPressure == nil {
            // Initialize if missing
            currentVitals.bloodPressure = targetVitals.bloodPressure
        }
    }
    
    // Helper to parse "120/80 mmHg" or "120/80" -> (120, 80)
    private func extractBP(_ bpStr: String) -> (sys: Int, dia: Int)? {
        // Remove text like " mmHg"
        let clean = bpStr.replacingOccurrences(of: " mmHg", with: "")
        let parts = clean.components(separatedBy: "/")
        if parts.count == 2,
           let sys = Int(parts[0].trimmingCharacters(in: .whitespaces)),
           let dia = Int(parts[1].trimmingCharacters(in: .whitespaces)) {
            return (sys, dia)
        }
        return nil
    }
}

// MARK: - Helper Extensions

// Helper extension for initializing an empty Vitals struct
extension Vitals {
    static var empty: Vitals {
        Vitals(
            heartRate: nil,
            respiratoryRate: nil,
            bloodPressure: nil,
            oxygenSaturation: nil
        )
    }
}

// Add a helper to make StateDetail initializable with no parameters for our error case.
extension StateDetail {
    init(description: String) {
        self.description = description
        self.trigger = nil
        self.vitals = nil
        self.physicalExamFindings = nil
        self.consequences = nil // Also initialize the new 'consequences' property.
    }
}
