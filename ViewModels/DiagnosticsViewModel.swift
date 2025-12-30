// ViewModels/DiagnosticsViewModel.swift

import Foundation
import SwiftData

@MainActor
class DiagnosticsViewModel: ObservableObject {
    
    @Published private(set) var groupedAvailableItems: [String: [TestResult]] = [:]
    @Published private(set) var orderedTests: [TestResult] = []
    
    let session: StudentSession
    private let modelContext: ModelContext
    private let allStates: [String: StateDetail]
    private let simulationViewModel: SimulationViewModel
    
    // ✅ ADD: Progress sync service for cloud synchronization
    private let progressService: UserProgressService
    
    // ✅ NOTIFICATION: Observer for cloud updates
    private var notificationObserver: NSObjectProtocol?
    
    // ✅ THE FIX: The logic is now updated to check the array.
    var canOrderTests: Bool {
        // The rule is: ordering is allowed if the differential array is not empty
        // AND at least one item in it has a non-empty diagnosis string.
        !session.differentialDiagnosis.isEmpty && session.differentialDiagnosis.contains { !$0.diagnosis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    
    init(simulationViewModel: SimulationViewModel, session: StudentSession, modelContext: ModelContext) {
        self.simulationViewModel = simulationViewModel
        self.session = session
        self.modelContext = modelContext
        
        // ✅ INITIALIZE: Progress service with model container
        self.progressService = UserProgressService(modelContainer: modelContext.container)
        
        let data = Data(simulationViewModel.patientCase.fullCaseJSON.utf8)
        if let detail = try? JSONDecoder().decode(EnhancedCaseDetail.self, from: data) {
            self.groupedAvailableItems = Dictionary(grouping: detail.dataSources.orderableItems, by: { $0.category })
            self.allStates = detail.dynamicState.states
        } else {
            self.allStates = [:]
        }
        updateOrderedTests()
        
        // ✅ NOTIFY: Listen for session updates from cloud
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .sessionUpdatedFromCloud,
            object: session.sessionId,
            queue: .main
        ) { [weak self] _ in
            self?.updateOrderedTests()
        }
    }
    
    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    func orderTest(named testName: String, reason: String?) {
        guard !session.performedActions.contains(where: { $0.actionName == testName }) else { return }
        
        let newAction = PerformedAction(actionName: testName, timestamp: Date(), reason: reason)
        
        let currentStateName = simulationViewModel.currentStateName
        if let currentState = allStates[currentStateName], let consequences = currentState.consequences {
            if let consequence = consequences.first(where: { $0.trigger == testName }) {
                let probability = consequence.probability ?? 1.0
                if Double.random(in: 0.0...1.0) <= probability {
                    simulationViewModel.changeState(to: consequence.targetState)
                    session.performedActions.append(newAction)
                    try? modelContext.save()
                    updateOrderedTests()
                    return
                }
            }
        }
        
        for (stateName, stateDetail) in allStates {
            if stateDetail.trigger == testName {
                simulationViewModel.changeState(to: stateName)
                break
            }
        }
        
        session.performedActions.append(newAction)
        try? modelContext.save()
        updateOrderedTests()
        
        // ✅ SYNC TO CLOUD: Upload session after ordering test
        let sessionToSync = self.session
        Task.detached(priority: .utility) {
            await self.progressService.uploadSession(sessionToSync)
        }
    }
    
    private func updateOrderedTests() {
        let allAvailable = groupedAvailableItems.values.flatMap { $0 }
        let orderedNames = session.orderedTestNames
        
        let fullOrderedTests = allAvailable.filter { orderedNames.contains($0.testName) }
        
        let data = Data(simulationViewModel.patientCase.fullCaseJSON.utf8)
        
        if let detail = try? JSONDecoder().decode(EnhancedCaseDetail.self, from: data) {
            let groundTruthItems = detail.dataSources.orderableItems
            
            self.orderedTests = fullOrderedTests.map { orderedTest in
                var testWithResult = orderedTest
                if let truth = groundTruthItems.first(where: { $0.testName == orderedTest.testName }) {
                    testWithResult.result = truth.result
                }
                return testWithResult
            }
        } else {
            self.orderedTests = fullOrderedTests
        }
    }
}
