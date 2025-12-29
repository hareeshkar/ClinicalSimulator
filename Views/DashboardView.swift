// Views/DashboardView.swift

import SwiftUI
import SwiftData
import os.log

private let dashLogger = Logger(subsystem: "com.hareeshkar.ClinicalSimulator", category: "DashboardView")

struct DashboardView: View {
    // MARK: - Properties
    
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var navigationManager: NavigationManager
    
    // ✅ ADD ENVIRONMENT FOR CURRENT USER
    @Environment(User.self) private var currentUser
    
    // Add this property to DashboardView
    @AppStorage("userRoleTitle") private var userRoleTitle: String = UserProfileRole.studentMS3.title
    
    // Data Queries
    @Query private var allCases: [PatientCase]
    @Query(filter: #Predicate<StudentSession> { !$0.isCompleted })
    private var inProgressSessions: [StudentSession]
    @Query(filter: #Predicate<StudentSession> { $0.isCompleted }, sort: \.sessionId, order: .reverse)
    private var completedSessions: [StudentSession]
    
    // ✅ ADD THE INITIALIZER
    init() {
        // This is a temporary workaround because @Environment is not available
        // during property initialization. We will filter the results in computed properties.
        // A more advanced approach would involve passing the user ID in.
    }
    
    // Local UI State
    @State private var selectedCaseForBriefing: PatientCase?
    @State private var presentingSimulation: ChatViewModel? = nil
    @State private var contentHasAppeared = false
    // Default to role-based recommendations
    @State private var selectedSpecialtyFilter: String = "Recommended"
    @State private var continueSectionCardHeight: CGFloat? = nil
    @State private var selectedCaseForHistory: PatientCase?
    // ✅ NEW: State for rotating recommended cases
    @State private var currentRecommendedCases: [PatientCase] = []
    
    // UI State for loading
    @State private var isSyncing = false
    
    // Track if we have done the initial load
    @AppStorage("isDatabaseInitialized") private var isDatabaseInitialized = false
    
    // Computed Properties
    private var availableCases: [PatientCase] {
        // Always return the set of non-in-progress cases. Filtering by specialty is handled
        // by `recommendedCasesForMyLevel` so we can cleanly support "Recommended"/"All"/specialty.
        let inProgressCaseIds = Set(inProgressSessions.map { $0.caseId })
        return allCases.filter { !inProgressCaseIds.contains($0.caseId) }
    }
    
    private var specialties: [String] {
        // Provide menu options: Recommended (default), All, then individual specialties.
        let uniqueSpecialties = Set(allCases.map { $0.specialty })
        return ["Recommended", "All"] + Array(uniqueSpecialties).sorted()
    }
    
    private var averageScore: Int {
        let scores = userCompletedSessions.compactMap { $0.score }
        guard !scores.isEmpty else { return 0 }
        return Int((scores.reduce(0, +) / Double(scores.count)).rounded())
    }
    
    private var recentlyCompletedSessions: [StudentSession] {
        Array(userCompletedSessions.prefix(3))
    }
    
    // ✅ UPDATE COMPUTED PROPERTIES TO FILTER BY USER
    private var userInProgressSessions: [StudentSession] {
        inProgressSessions.filter { $0.user?.id == currentUser.id }
    }
    
    private var userCompletedSessions: [StudentSession] {
        completedSessions.filter { $0.user?.id == currentUser.id }
    }
    
    // Computed property for dynamic greeting based on current time
    private var dynamicGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12:
            return "Good morning,"
        case 12..<17:
            return "Good afternoon,"
        case 17..<21:
            return "Good evening,"
        default:
            return "Good night,"
        }
    }
    
    // ✅ ADD: Computed property to check if today is the user's birthday
    private var isBirthday: Bool {
        guard let dob = currentUser.dateOfBirth else { return false }
        let calendar = Calendar.current
        let today = calendar.dateComponents([.month, .day], from: Date())
        let birthday = calendar.dateComponents([.month, .day], from: dob)
        return today.month == birthday.month && today.day == birthday.day
    }

    // ✅ UPDATED: Smart filtering based on user role and filter selection
    private var recommendedCasesForMyLevel: [PatientCase] {
        // "Recommended" -> role-based recommendations (default)
        if selectedSpecialtyFilter == "Recommended" {
            let extractedRole = extractRoleCode(from: userRoleTitle)
            return availableCases.filter { patientCase in
                if patientCase.recommendedForLevels.isEmpty { return true }
                return patientCase.recommendedForLevels.contains { level in
                    extractedRole.contains(level) || level.contains(extractedRole)
                }
            }
        }
        
        // "All" -> return every available case (no role filtering)
        if selectedSpecialtyFilter == "All" {
            return availableCases
        }
        
        // Specific specialty selected -> override role and return available cases in that specialty
        return availableCases.filter { $0.specialty == selectedSpecialtyFilter }
    }
    
    // Helper to extract role code
    private func extractRoleCode(from roleTitle: String) -> String {
        // Extract text in parentheses, or use full title
        if let startIndex = roleTitle.firstIndex(of: "("),
           let endIndex = roleTitle.firstIndex(of: ")") {
            return String(roleTitle[roleTitle.index(after: startIndex)..<endIndex])
        }
        return roleTitle
    }
    
    // MARK: - Main Body
    var body: some View {
        NavigationStack {
            ZStack {
                if (isSyncing && !isDatabaseInitialized) || (allCases.isEmpty && !isDatabaseInitialized) {
                    // 1. Initial Launch/Sync Screen
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.blue)
                        Text("Syncing Medical Cases...")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("Loading \(allCases.isEmpty ? "case library" : "\(allCases.count) cases")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                } else {
                    // 2. The Normal Dashboard
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 48) {
                            headerView
                                .animation(.spring(response: 0.4, dampingFraction: 0.75).delay(0.05), value: contentHasAppeared)
                            
                            statsSection
                                .animation(.spring(response: 0.4, dampingFraction: 0.75).delay(0.1), value: contentHasAppeared)
                            
                            continueSection
                                .animation(.spring(response: 0.4, dampingFraction: 0.75).delay(0.15), value: contentHasAppeared)
                            
                            quickActionsSection
                                .animation(.spring(response: 0.4, dampingFraction: 0.75).delay(0.2), value: contentHasAppeared)
                            
                            recommendedSection
                                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.5), value: contentHasAppeared)
                            
                            recentPerformanceSection
                                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.6), value: contentHasAppeared)
                        }
                        .padding(.top, 40) // Increased top padding to push content further down
                        .padding(.bottom, 8)
                        .opacity(contentHasAppeared ? 1 : 0)
                    }
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(.systemGroupedBackground),
                                Color(.systemGroupedBackground).opacity(0.8)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .navigationBarHidden(true)
                    .refreshable {
                        try? await Task.sleep(nanoseconds: 500_000_000)
                    }
                }
            }
            .task {
                // 3. Trigger the sync safely on appear
                await performBackgroundSync()
            }
        }
        .onAppear(perform: handleOnAppear)
        .fullScreenCover(item: $presentingSimulation) { viewModel in
            NavigationStack { SimulationView(chatViewModel: viewModel) }
        }
        .sheet(item: $selectedCaseForBriefing) { patientCase in
            dashLogger.log("📋 Opening briefing sheet for case: \(patientCase.caseId, privacy: .public)")
            return CaseBriefingView(patientCase: patientCase) {
                dashLogger.log("✅ User began simulation from dashboard")
                let session = DataManager.findOrCreateActiveSession(
                    for: patientCase.caseId,
                    user: currentUser,
                    modelContext: modelContext
                )
                let viewModel = ChatViewModel(
                    patientCase: patientCase, 
                    session: session, 
                    modelContext: modelContext,
                    userRole: userRoleTitle
                )
                selectedCaseForBriefing = nil
                presentingSimulation = viewModel
            }
        }
        .sheet(item: $selectedCaseForHistory) { patientCase in
            NavigationStack {
                CaseHistoryView(patientCase: patientCase)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                selectedCaseForHistory = nil
                            }
                        }
                    }
                
            }
        }
    }
    
    // MARK: - ViewBuilder Sub-components
    
    @ViewBuilder
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isBirthday ? "Happy Birthday!" : dynamicGreeting)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    
                    Text(currentUser.fullName)
                        .font(.largeTitle.bold())
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                Button(action: {
                    navigationManager.selectedTab = .profile
                }) {
                    AnimatedAvatarView(isBirthday: isBirthday, size: 84)
                }
                .buttonStyle(.plain)
            }
            
            Text(isBirthday ? "Here's to another year of growth, discovery, and excellence in your clinical journey. You've got this!" : "Ready to advance your clinical expertise?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance Overview")
                .font(.title2.bold())
                .padding(.horizontal)
            
            HStack(spacing: 16) {
                Button(action: {
                    navigationManager.selectedTab = .reports
                }) {
                    DashboardStatCard(
                        title: "Cases Completed",
                        value: userCompletedSessions.count, // ✅ UPDATED
                        format: .wholeNumber,
                        iconName: "checkmark.circle.fill",
                        color: SpecialtyDetailsProvider.color(for: "Internal Medicine"),
                        trend: .stable
                    )
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    navigationManager.selectedTab = .reports
                }) {
                    DashboardStatCard(
                        title: "Average Score",
                        value: averageScore,
                        format: .percentage,
                        iconName: "star.circle.fill",
                        color: SpecialtyDetailsProvider.color(for: "Emergency Medicine"),
                        trend: userCompletedSessions.count > 1 ? .improving : .stable // ✅ UPDATED
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var continueSection: some View {
        if !userInProgressSessions.isEmpty { // ✅ UPDATED
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Active Simulations", systemImage: "play.circle.fill")
                        .font(.title2.bold()) // Bolder title
                        .foregroundStyle(.primary)

                    Spacer()

                    Text("\(userInProgressSessions.count)") // ✅ UPDATED
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(SpecialtyDetailsProvider.color(for: "Emergency Medicine"), in: Capsule())
                }
                .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(userInProgressSessions) { session in // ✅ UPDATED
                            if let patientCase = allCases.first(where: { $0.caseId == session.caseId }) {
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
                                        .frame(width: 350)
                                }
                                .buttonStyle(EnhancedCardButtonStyle())
                                .background(
                                    GeometryReader { proxy in
                                        Color.clear.preference(key: ContinueCardHeightKey.self, value: proxy.size.height)
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                    .scrollTargetLayout()
                    .onPreferenceChange(ContinueCardHeightKey.self) { height in
                        if height > 0 {
                            continueSectionCardHeight = max(continueSectionCardHeight ?? 0, height)
                        }
                    }
                    .frame(height: continueSectionCardHeight ?? 100)
                    .padding(.bottom, 20)
                    .padding(.top,10)
                    .scrollTargetBehavior(.viewAligned)
                }
               
            }
        }
    }
    
    @ViewBuilder
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.title2.bold())
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                QuickActionRow(
                    title: "Browse All Cases",
                    subtitle: "Explore \(allCases.count) clinical scenarios",
                    iconName: "square.grid.2x2.fill",
                    color: SpecialtyDetailsProvider.color(for: "Internal Medicine")
                ) {
                    navigationManager.selectedTab = .cases
                }
                
                QuickActionRow(
                    title: "Performance Reports",
                    subtitle: "Review detailed analytics",
                    iconName: "chart.bar.xaxis",
                    color: SpecialtyDetailsProvider.color(for: "Cardiology")
                ) {
                    navigationManager.selectedTab = .reports
                }
                
                if !availableCases.isEmpty {
                    QuickActionRow(
                        title: "Random Case Challenge",
                        subtitle: "Start a surprise simulation",
                        iconName: "dice.fill",
                        color: SpecialtyDetailsProvider.color(for: "Emergency Medicine")
                    ) {
                        if let randomCase = availableCases.randomElement() {
                            selectedCaseForBriefing = randomCase
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                // ✅ UPDATED: Dynamic title based on filter
                Text(
                    selectedSpecialtyFilter == "Recommended"
                        ? "Recommended for \(extractRoleCode(from: userRoleTitle))"
                        : (selectedSpecialtyFilter == "All" ? "All Cases" : "Cases in \(selectedSpecialtyFilter)")
                )
                    .font(.title2.bold())
                
                Spacer()
                
                Menu {
                    ForEach(specialties, id: \.self) { specialty in
                        Button(specialty) { selectedSpecialtyFilter = specialty }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedSpecialtyFilter)
                            .font(.caption.weight(.medium))
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                }
            }
            .padding(.horizontal)

            if currentRecommendedCases.isEmpty {
                ContentUnavailableView(
                    "No Cases Available",
                    systemImage: "graduationcap.fill",
                    description: Text(
                        selectedSpecialtyFilter == "Recommended"
                            ? "All appropriate cases for your level have been started. Try changing the filter or check your profile settings."
                            : (selectedSpecialtyFilter == "All"
                                ? "There are no available cases at the moment."
                                : "No cases available in \(selectedSpecialtyFilter). Try 'All' or a different specialty.")
                    )
                )
                .padding(.horizontal)
                .frame(minHeight: 120)
            } else {
                VStack(spacing: 16) {
                    ForEach(currentRecommendedCases) { patientCase in
                        Button(action: { selectedCaseForBriefing = patientCase }) {
                            CaseListItemView(patientCase: patientCase, action: .start)
                        }
                        .buttonStyle(EnhancedCardButtonStyle())
                    }
                }
                .padding(.horizontal)
            }
        }
        .onChange(of: selectedSpecialtyFilter) { _, _ in
            // Update the visible list when filter changes
            currentRecommendedCases = Array(recommendedCasesForMyLevel.shuffled().prefix(3))
        }
    }
    
    @ViewBuilder
    private var recentPerformanceSection: some View {
        if !recentlyCompletedSessions.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Text("Recent Performance")
                    .font(.title2.bold())
                    .padding(.horizontal)
                
                VStack(spacing: 12) {
                    ForEach(recentlyCompletedSessions) { session in
                        if let patientCase = allCases.first(where: { $0.caseId == session.caseId }) {
                            Button(action: {
                                selectedCaseForHistory = patientCase
                            }) {
                                // ✅ REWORKED: Using the unified CaseListItemView
                                CaseListItemView(patientCase: patientCase, session: session, action: .review)
                            }
                            .buttonStyle(EnhancedCardButtonStyle())
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private func handleOnAppear() {
        // Only trigger content animation if sync is already done
        if isDatabaseInitialized {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                contentHasAppeared = true
            }
            
            // ✅ NEW: Rotate recommended cases on each appearance (respecting "Recommended"/"All"/specialty)
            currentRecommendedCases = Array(recommendedCasesForMyLevel.shuffled().prefix(3))
        }
    }
    
    private func performBackgroundSync() async {
        // Don't sync if we already have data and are just viewing tab
        if !allCases.isEmpty && isDatabaseInitialized {
            dashLogger.log("⏭️ Skipping sync - database already initialized with \(allCases.count, privacy: .public) cases")
            // Still trigger content animation on subsequent views
            if !contentHasAppeared {
                await MainActor.run {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        contentHasAppeared = true
                    }
                    currentRecommendedCases = Array(recommendedCasesForMyLevel.shuffled().prefix(3))
                }
            }
            return
        }
        
        dashLogger.log("🚀 Starting cloud sync from DashboardView")
        isSyncing = true
        
        // Create the actor - access container through modelContext
        let syncer = CaseSynchronizationService(modelContainer: modelContext.container)
        
        do {
            // ☁️ NEW: This syncs from Firestore instead of local JSON
            dashLogger.log("☁️ Calling syncWithCloud() on background actor...")
            try await syncer.syncWithCloud()
            
            await MainActor.run {
                dashLogger.log("✅ Cloud sync completed successfully")
                isDatabaseInitialized = true
                isSyncing = false
                
                // Trigger content animation after successful sync
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    contentHasAppeared = true
                }
                currentRecommendedCases = Array(recommendedCasesForMyLevel.shuffled().prefix(3))
            }
        } catch {
            dashLogger.error("❌ Cloud Sync Failed: \(error.localizedDescription, privacy: .public)")
            dashLogger.log("⚠️ Falling back to local sync...")
            
            // Fallback to local sync if cloud fails
            do {
                try await syncer.syncLocalData()
                await MainActor.run {
                    dashLogger.log("✅ Local sync completed successfully (fallback)")
                    isDatabaseInitialized = true
                    isSyncing = false
                    
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        contentHasAppeared = true
                    }
                    currentRecommendedCases = Array(recommendedCasesForMyLevel.shuffled().prefix(3))
                }
            } catch {
                dashLogger.error("❌ Local Sync Also Failed: \(error.localizedDescription, privacy: .public)")
                await MainActor.run {
                    isSyncing = false
                    isDatabaseInitialized = true // Mark as initialized to prevent infinite retry
                }
            }
        }
    }
}


struct DashboardStatCard: View {
    let title: String
    let value: Int
    let format: StatFormat
    let iconName: String
    let color: Color
    let trend: TrendDirection
    
    enum StatFormat { case wholeNumber, percentage }
    enum TrendDirection { case improving, declining, stable }
    
    @State private var animatedValue: Double = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: iconName)
                    .font(.title2.bold())
                    .foregroundStyle(color)
                
                Spacer()
                
                if trend != .stable {
                    Image(systemName: trend == .improving ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(trend == .improving ? .green : .red)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                
                AnimatedNumber(
                    value: animatedValue,
                    format: format == .percentage ? .percentage : .wholeNumber
                )
                .font(.system(.title, design: .rounded).bold())
                .foregroundStyle(.primary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.background)
                .shadow(color: color.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.3)) {
                animatedValue = Double(value)
            }
        }
    }
}

struct QuickActionRow: View {
    let title: String
    let subtitle: String
    let iconName: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: iconName)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct EnhancedCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: configuration.isPressed)
    }
}

// PreferenceKey used to measure the continue section card height
private struct ContinueCardHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

enum AnimatedNumberFormat {
    case wholeNumber, percentage
}

struct AnimatedNumber: View, Animatable {
    var value: Double
    var format: AnimatedNumberFormat
    
    var animatableData: Double {
        get { value }
        set { value = newValue }
    }
    
    var body: some View {
        switch format {
        case .wholeNumber:
            Text("\(Int(value.rounded()))")
        case .percentage:
            Text("\(Int(value.rounded()))%")
        }
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [PatientCase.self, StudentSession.self], inMemory: true)
        .environmentObject(NavigationManager())
}
