// Views/CaseCategoryListView.swift

import SwiftUI
import SwiftData

struct CaseCategoryListView: View {
    // This view receives the specialty it needs to display.
    let specialty: String
    
    @Environment(\.modelContext) private var modelContext
    @AppStorage("userRoleTitle") private var userRoleTitle: String = UserProfileRole.studentMS3.title
    
    // ✅ FIX 1: Get the current user from the environment.
    @Environment(User.self) private var currentUser
    
    // State for the search bar and for presenting modals.
    @State private var searchText = ""
    @State private var selectedCaseForBriefing: PatientCase?
    @State private var presentingSimulation: ChatViewModel?
    
    // SwiftData queries to fetch the necessary data from the database.
    @Query private var cases: [PatientCase]
    @Query(filter: #Predicate<StudentSession> { !$0.isCompleted })
    private var inProgressSessions: [StudentSession]
    
    // Custom initializer (unchanged).
    init(specialty: String) {
        self.specialty = specialty
        _cases = Query(filter: #Predicate { $0.specialty == specialty }, sort: \PatientCase.title)
    }
    
    // --- Computed Properties for Filtering (Unchanged) ---
    
    private var filteredInProgressSessions: [StudentSession] {
        let caseIdsForSpecialty = Set(cases.map { $0.caseId })
        return inProgressSessions.filter { caseIdsForSpecialty.contains($0.caseId) }
    }

    private var filteredUnstartedCases: [PatientCase] {
        let inProgressCaseIds = Set(inProgressSessions.map { $0.caseId })
        let unstarted = cases.filter { !inProgressCaseIds.contains($0.caseId) }
        
        if searchText.isEmpty {
            return unstarted
        } else {
            return unstarted.filter {
                $0.title.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // Use chiefComplaint (what the user sees) for search filtering
    private var filteredCases: [PatientCase] {
        guard !searchText.isEmpty else { return cases }
        return cases.filter { $0.chiefComplaint.localizedCaseInsensitiveContains(searchText) }
    }
    
    // --- ✅ REWORKED Main Body ---
    var body: some View {
        // 1. The main container is a VStack to stack the header and scroll view.
        VStack(spacing: 0) {
            // 2. The header is now a fixed banner at the top.
            headerSection
                .padding(.bottom)
                .background(.regularMaterial) // Gives a modern, translucent effect
            
            // 3. The cases are inside a custom ScrollView.
            ScrollView {
                VStack(alignment: .leading, spacing: 28) { // Added spacing
                    if !filteredInProgressSessions.isEmpty {
                        continueSection
                    }
                    
                    startNewSection
                }
                .padding()
            }
        }
        .background(Color(.systemGroupedBackground)) // Consistent background
        .navigationTitle(specialty)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search in \(specialty)")
        .sheet(item: $selectedCaseForBriefing) { patientCase in
            CaseBriefingView(patientCase: patientCase, onBegin: {
                // ✅ FIX 2: Pass the currentUser to the DataManager call.
                let session = DataManager.findOrCreateActiveSession(
                    for: patientCase.caseId,
                    user: currentUser, // <-- THE FIX
                    modelContext: modelContext
                )
                // ✅ Pass userRole here
                let viewModel = ChatViewModel(
                    patientCase: patientCase,
                    session: session,
                    modelContext: modelContext,
                    userRole: userRoleTitle
                )
                selectedCaseForBriefing = nil
                presentingSimulation = viewModel
            })
        }
        .fullScreenCover(item: $presentingSimulation) { viewModel in
            NavigationStack {
                SimulationView(chatViewModel: viewModel)
            }
        }
        // Hide the default back button text for a cleaner look
        .toolbarTitleDisplayMode(.inline)
    }
    
    // --- ✅ ENHANCED ViewBuilder Helper Properties ---
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                Image(systemName: SpecialtyDetailsProvider.details(for: specialty).iconName)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(SpecialtyDetailsProvider.color(for: specialty))
                
                VStack(alignment: .leading) {
                    Text(specialty)
                        .font(.largeTitle.bold())
                    
                    Text(SpecialtyDetailsProvider.details(for: specialty).description)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
    
    @ViewBuilder
    private var continueSection: some View {
        VStack(alignment: .leading, spacing: 28) {
            Label("Continue Where You Left Off", systemImage: "play.circle.fill")
                .font(.title2.bold()) // Bolder title
                .foregroundStyle(.primary)
            
            // The cards are now in their own VStack
            VStack(spacing: 38) {
                ForEach(filteredInProgressSessions) { session in
                    if let patientCase = cases.first(where: { $0.caseId == session.caseId }) {
                        Button(action: {
                            // ✅ Pass userRole here
                            presentingSimulation = ChatViewModel(
                                patientCase: patientCase,
                                session: session,
                                modelContext: modelContext,
                                userRole: userRoleTitle
                            )
                        }) {
                            CaseListItemView(patientCase: patientCase, session: session, action: .continue)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var startNewSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Start a New Case", systemImage: "doc.text.fill")
                .font(.title2.bold())
                .foregroundStyle(.primary)
            
            if filteredUnstartedCases.isEmpty {
                ContentUnavailableView(
                    "No New Cases",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text(searchText.isEmpty ? "You've completed all available cases in \(specialty)." : "No cases found for \"\(searchText)\".")
                )
                .padding(.top, 40)
            } else {
                VStack(spacing: 16) {
                    ForEach(filteredUnstartedCases) { patientCase in
                        Button(action: { selectedCaseForBriefing = patientCase }) {
                            CaseListItemView(patientCase: patientCase, action: .start)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}



// --- Preview (Unchanged) ---
#Preview {
    NavigationStack {
        CaseCategoryListView(specialty: "Cardiology")
            .modelContainer(for: [PatientCase.self, StudentSession.self], inMemory: true)
    }
}
