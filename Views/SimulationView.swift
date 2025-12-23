// Views/SimulationView.swift

import SwiftUI
import SwiftData
import Combine

// ✅ ARCHITECTURAL REWORK: The SimulationEnvironment coordinator object.
/// This object acts as a single, encapsulated environment for a simulation session.
/// It is created once and is responsible for initializing and holding all the necessary ViewModels,
/// solving the fragile chained @StateObject initialization problem.
@MainActor
final class SimulationEnvironment: ObservableObject {
    
    // The four core ViewModels, owned by this environment.
    let simulationVM: SimulationViewModel
    let chatVM: ChatViewModel
    let diagnosticsVM: DiagnosticsViewModel
    let notesVM: NotesViewModel
    
    // ✅ FIX: Cancellables to store the observation subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    init(chatViewModel: ChatViewModel) {
        // The incoming ChatViewModel is the source of truth for the session data.
        self.chatVM = chatViewModel
        
        // The other ViewModels are initialized here, once, in a stable sequence.
        let simVM = SimulationViewModel(patientCase: chatViewModel.patientCase, session: chatViewModel.session)
        self.simulationVM = simVM
        
        self.diagnosticsVM = DiagnosticsViewModel(
            simulationViewModel: simVM,
            session: chatViewModel.session,
            modelContext: chatViewModel.modelContext
        )
        
        self.notesVM = NotesViewModel(
            session: chatViewModel.session,
            modelContext: chatViewModel.modelContext
        )
        
        // ✅ CRITICAL FIX: Forward objectWillChange from child ViewModels to this environment.
        // This ensures that when any ViewModel updates (like the physiology timer in simulationVM),
        // the SimulationEnvironment also publishes a change, triggering SimulationView to re-render.
        
        simulationVM.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
            
        chatVM.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
            
        diagnosticsVM.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
            
        notesVM.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }
}

// ✅ UI/UX REWORK: The main SimulationView is now cleaner and more sophisticated.
struct SimulationView: View {
    // A single, robust StateObject that holds the entire simulation environment.
    @StateObject private var environment: SimulationEnvironment
    
    // Standard SwiftUI properties.
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var navigationManager: NavigationManager
    
    // Local state for UI presentation.
    @State private var isShowingReferenceSheet = false
    @State private var isShowingEndConfirmation = false
    @State private var isHudExpanded: Bool = true

    // The initializer is now clean and simple. It just creates our environment object.
    init(chatViewModel: ChatViewModel) {
        _environment = StateObject(wrappedValue: SimulationEnvironment(chatViewModel: chatViewModel))
    }

    // A dynamic title based on the patient's name for immersion.
    private var navigationTitle: String {
        environment.simulationVM.patientProfile?.name ?? "Simulation"
    }

    var body: some View {
        // ✅ THE CORE FIX: A VStack structurally separates the HUD and the TabView.
        // There is no Z-axis overlap, guaranteeing the layout is correct.
        VStack(spacing: 0) {
            clinicalHud
            mainTabView
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            // A custom, cleaner toolbar.
            leadingToolbarItem
            trailingToolbarItem
        }
        .sheet(isPresented: $isShowingReferenceSheet) {
            CaseBriefingView(patientCase: environment.chatVM.patientCase, isReferenceMode: true)
        }
        .alert("Submit for Review?", isPresented: $isShowingEndConfirmation, actions: {
            Button("Submit", role: .destructive, action: endAndSubmitSimulation)
            Button("Cancel", role: .cancel) { }
        }, message: {
            Text("Once submitted, you will not be able to change your answers.")
        })
        .onAppear(perform: handleInitialPatientResponse)
        .onChange(of: environment.simulationVM.currentStateName, handleStateChange)
        .background(Color(.systemGroupedBackground)) // Ensure background covers the whole view
    }
    
    // MARK: - ViewBuilder Sub-components
    
    @ViewBuilder
    private var mainTabView: some View {
        TabView {
            // ✅ FIX: No longer needs the binding. It will naturally fill its container.
            ConversationTabView(viewModel: environment.chatVM)
                .tabItem { Label("Conversation", systemImage: "bubble.left.and.bubble.right.fill") }
            
            // ✅ CONTEXTUAL NAMING: "Diagnostics" is now "Orders".
            DiagnosticsTabView(viewModel: environment.diagnosticsVM)
                .tabItem { Label("Orders", systemImage: "list.clipboard.fill") }
            
            NotesTabView(viewModel: environment.notesVM)
                .tabItem { Label("Notes", systemImage: "pencil.and.scribble") }
        }
    }
    
    @ViewBuilder
    private var clinicalHud: some View {
        VStack(spacing: 0) {
            PatientMonitorView(
                patientProfile: environment.simulationVM.patientProfile,
                vitals: environment.simulationVM.currentVitals,
                isSheetPresented: $isShowingReferenceSheet,
                isHudExpanded: $isHudExpanded
            )
            
            if isHudExpanded {
                ClinicalStatusView(
                    stateName: environment.simulationVM.currentStateName,
                    statusDescription: environment.simulationVM.currentState.description,
                    patientCase: environment.chatVM.patientCase
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        // ✅ UI REFINEMENT: Simpler background. No need for complex shadows or clipping
        // as it is now a standard top bar, not a floating element.
        .background(.regularMaterial)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isHudExpanded)
    }
    
    // MARK: - Toolbar Items
    
    private var leadingToolbarItem: ToolbarItem<(), some View> {
        ToolbarItem(placement: .navigationBarLeading) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.backward")
            }
        }
    }
    
    private var trailingToolbarItem: ToolbarItem<(), some View> {
        ToolbarItem(placement: .confirmationAction) {
            // Existing Submit Button
            Button("Submit", action: { isShowingEndConfirmation = true })
                .fontWeight(.semibold)
        }
    }

    // MARK: - Logic & Handlers
    
    private func endAndSubmitSimulation() {
        environment.chatVM.endSimulation()
        let context = EvaluationNavigationContext(
            patientCase: environment.chatVM.patientCase,
            session: environment.chatVM.session
        )
        dismiss()
        // Use a slight delay to allow the dismiss animation to complete before presenting the sheet.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            navigationManager.requestReport(for: context)
        }
    }
    
    private func handleInitialPatientResponse() {
        if environment.chatVM.messages.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                environment.chatVM.generateProactiveResponse()
            }
        }
    }
    
    private func handleStateChange(_ oldState: String, _ newState: String) {
        guard newState != "initial" && oldState != newState else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            environment.chatVM.generateProactiveResponse()
        }
    }
}

// MARK: - Intelligent Clinical Status View (Reworked)
struct ClinicalStatusView: View {
    let stateName: String
    let statusDescription: String
    let patientCase: PatientCase // Pass the full case to get the chief complaint

    private var chiefComplaint: String {
        // Safely decode the chief complaint.
        if let data = patientCase.fullCaseJSON.data(using: .utf8),
           let detail = try? JSONDecoder().decode(EnhancedCaseDetail.self, from: data) {
            return detail.initialPresentation.chiefComplaint
        }
        return "N/A"
    }
    
    private var isInitialState: Bool { stateName == "initial" }
    
    // Computed properties for a cleaner body
    private var displayText: String { isInitialState ? chiefComplaint : statusDescription }
    private var displayIcon: String { isInitialState ? "exclamationmark.bubble.fill" : "waveform.path.ecg" }
    private var iconColor: Color { isInitialState ? .orange : .cyan }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: displayIcon)
                .font(.headline.weight(.medium))
                .foregroundStyle(iconColor)
                .padding(.top, 2)

            Text(displayText)
                .font(.callout)
                .foregroundStyle(.secondary)
            
            Spacer()
        }
        .padding(12)
        .transition(.opacity) // Use a simple fade for text changes
        .animation(.easeInOut(duration: 0.3), value: displayText)
    }
}
