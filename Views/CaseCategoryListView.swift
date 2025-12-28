// This is the inside view after clicking a catagory section with list of case cards ( the long list of cases in a specialty)
import SwiftUI
import SwiftData
import os.log

private let categoryLogger = Logger(subsystem: "com.hareeshkar.ClinicalSimulator", category: "CaseCategoryListView")

struct CaseCategoryListView: View {
    // MARK: - Properties
    let specialty: String
    
    @Environment(\.modelContext) private var modelContext
    @AppStorage("userRoleTitle") private var userRoleTitle: String = UserProfileRole.studentMS3.title
    @Environment(User.self) private var currentUser
    
    @State private var searchText = ""
    @State private var selectedCaseForBriefing: PatientCase?
    @State private var presentingSimulation: ChatViewModel?
    
    // Data Queries
    @Query private var cases: [PatientCase]
    @Query(filter: #Predicate<StudentSession> { !$0.isCompleted })
    private var inProgressSessions: [StudentSession]
    
    init(specialty: String) {
        self.specialty = specialty
        _cases = Query(filter: #Predicate { $0.specialty == specialty }, sort: \PatientCase.title)
    }
    
    // MARK: - Filtering Logic
    private var filteredInProgressSessions: [StudentSession] {
        let caseIdsForSpecialty = Set(cases.map { $0.caseId })
        // Filter sessions by specialty AND current user
        return inProgressSessions.filter {
            caseIdsForSpecialty.contains($0.caseId) &&
            $0.user?.id == currentUser.id
        }
    }

    private var filteredUnstartedCases: [PatientCase] {
        let activeCaseIds = Set(filteredInProgressSessions.map { $0.caseId })
        let available = cases.filter { !activeCaseIds.contains($0.caseId) }
        
        if searchText.isEmpty {
            return available
        } else {
            return available.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.chiefComplaint.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    departmentHeader
                    
                    if !filteredInProgressSessions.isEmpty {
                        roundsSection
                    }
                    
                    librarySection
                }
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline) // Keep inline for clean aesthetic
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(specialty.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.secondary)
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search diagnosis or symptoms")
        .sheet(item: $selectedCaseForBriefing) { patientCase in
            CaseBriefingView(patientCase: patientCase, onBegin: {
                startSimulation(for: patientCase)
            })
        }
        .fullScreenCover(item: $presentingSimulation) { viewModel in
            NavigationStack {
                SimulationView(chatViewModel: viewModel)
            }
        }
    }
    
    // MARK: - Components
    
    @ViewBuilder
    private var departmentHeader: some View {
        ZStack(alignment: .center) {
            // LAYER 1: Cinematic Background Image
            SpecialtyCinematicBackground(specialty: specialty, color: SpecialtyDetailsProvider.color(for: specialty))
                .clipped()

            // LAYER 2: Dark Cinematic Scrim for text legibility
            LinearGradient(
                colors: [
                    Color.black.opacity(0.0),
                    Color.black.opacity(0.3),
                    Color.black.opacity(0.6)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // LAYER 3: Watermark Icon (subtle background element)
            GeometryReader { geo in
                Image(systemName: SpecialtyDetailsProvider.details(for: specialty).iconName)
                    .font(.system(size: 140, weight: .black))
                    .foregroundStyle(Color.white)
                    .blur(radius: 1)
                    .opacity(0.05)
                    .rotationEffect(.degrees(5))
                    .offset(x: geo.size.width * 0.3, y: -geo.size.height * 0.2)
                    .blendMode(.overlay)
            }

            // LAYER 4: Editorial Content (Text)
            VStack(spacing: 12) {
                Text(specialty)
                    .font(.system(size: 36, weight: .black, design: .serif))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)

                Text(SpecialtyDetailsProvider.details(for: specialty).description)
                    .font(.system(size: 14, weight: .medium, design: .default))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                    .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.vertical, 32)
            .padding(.horizontal, 16)
        }
        .frame(height: 280)
        // Soften hard rectangle edges: rounded corners + vignette overlay
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            // Vignette to fade edges and blend with UI
            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: Color.clear, location: 0.0),
                    .init(color: Color.black.opacity(0.08), location: 0.7),
                    .init(color: Color.black.opacity(0.30), location: 1.0)
                ]),
                center: .center,
                startRadius: 0,
                endRadius: 420
            )
            .blendMode(.overlay)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        )
        .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 6)
        .padding(.horizontal, 12)
    }
    
    @ViewBuilder
    private var roundsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Active Rounds", systemImage: "clock.arrow.circlepath")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                ForEach(filteredInProgressSessions) { session in
                    if let patientCase = cases.first(where: { $0.caseId == session.caseId }) {
                        Button {
                            resumeSimulation(case: patientCase, session: session)
                        } label: {
                            CaseListItemView(patientCase: patientCase, session: session, action: .continue)
                        }
                        .buttonStyle(ListButtonStyle())
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(searchText.isEmpty ? "Patient List" : "Search Results", systemImage: "text.book.closed")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            if filteredUnstartedCases.isEmpty {
                ContentUnavailableView {
                    Label("No Cases Found", systemImage: "magnifyingglass")
                } description: {
                    Text(searchText.isEmpty ? "No new cases available in this specialty." : "Try adjusting your search terms.")
                }
                .padding(.top, 20)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(filteredUnstartedCases) { patientCase in
                        Button {
                            selectedCaseForBriefing = patientCase
                        } label: {
                            CaseListItemView(patientCase: patientCase, action: .start)
                        }
                        .buttonStyle(ListButtonStyle())
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Actions
    
    private func startSimulation(for patientCase: PatientCase) {
        categoryLogger.log("✅ Starting new simulation: \(patientCase.caseId)")
        let session = DataManager.findOrCreateActiveSession(
            for: patientCase.caseId,
            user: currentUser,
            modelContext: modelContext
        )
        launchSimulation(case: patientCase, session: session)
    }
    
    private func resumeSimulation(case patientCase: PatientCase, session: StudentSession) {
        categoryLogger.log("✅ Resuming simulation: \(patientCase.caseId)")
        launchSimulation(case: patientCase, session: session)
    }
    
    private func launchSimulation(case patientCase: PatientCase, session: StudentSession) {
        // Dismiss sheet if present
        selectedCaseForBriefing = nil
        
        // Initialize VM with exact backend requirements
        let viewModel = ChatViewModel(
            patientCase: patientCase,
            session: session,
            modelContext: modelContext,
            userRole: userRoleTitle
        )
        
        // Trigger presentation
        // Tiny delay ensures sheet dismissal doesn't conflict with full screen cover
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            presentingSimulation = viewModel
        }
    }
}

// MARK: - Helper Styles

struct ListButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .sensoryFeedback(.selection, trigger: configuration.isPressed)
    }
}
