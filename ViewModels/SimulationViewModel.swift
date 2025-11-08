// ViewModels/SimulationViewModel.swift

import SwiftUI

@MainActor
class SimulationViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var currentState: StateDetail
    @Published var currentVitals: Vitals
    @Published var currentStateName: String // ✅ FIX 1: Removed the duplicate. This is the single source of truth.
    
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
            
            // ✅ FIX 2: Initialize the missing property in the error path.
            self.currentStateName = "error"
            
            // It is now safe to exit the initializer.
            return
        }
        
        // --- Success Path ---
        // All properties are guaranteed to be initialized here.
        self.allStates = detail.dynamicState.states
        
        self.currentState = allStates["initial"] ?? StateDetail(description: "Error: Initial state not found.")
        self.currentVitals = detail.initialPresentation.vitals
        self.currentStateName = "initial"

        // THE PERSISTENCE FIX: Instantly restore the correct state based on the session.
        // We create a quick lookup map of [Trigger Name -> State Name].
        let triggerToStateMap = allStates.reduce(into: [String: String]()) { result, state in
            if let trigger = state.value.trigger {
                result[trigger] = state.key
            }
        }
        
        // Re-apply every ordered test that is a known trigger, in the order they were performed.
        for performedAction in session.performedActions {
            if let triggeredStateName = triggerToStateMap[performedAction.actionName] {
                // We call changeState WITHOUT animation to update the vitals and state instantly.
                changeState(to: triggeredStateName, animated: false)
            }
        }
    }
    
    // MARK: - Methods
    
    /// This function changes the patient's state. It now accepts an `animated` parameter.
    func changeState(to stateName: String, animated: Bool = true) {
        guard let newState = allStates[stateName] else {
            print("Warning: Tried to switch to a non-existent state: \(stateName)")
            return
        }
        
        currentState = newState
        currentStateName = stateName
        
        // This is the core update logic.
        let updateVitals = {
            self.currentVitals.heartRate = newState.vitals?.heartRate ?? self.currentVitals.heartRate
            self.currentVitals.respiratoryRate = newState.vitals?.respiratoryRate ?? self.currentVitals.respiratoryRate
            self.currentVitals.bloodPressure = newState.vitals?.bloodPressure ?? self.currentVitals.bloodPressure
            self.currentVitals.oxygenSaturation = newState.vitals?.oxygenSaturation ?? self.currentVitals.oxygenSaturation
        }
        
        // We only wrap the update in an animation if requested.
        if animated {
            withAnimation(.easeInOut) {
                updateVitals()
            }
        } else {
            updateVitals()
        }
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
