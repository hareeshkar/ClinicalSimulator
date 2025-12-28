import SwiftUI
import SwiftData

// MARK: - Model (Unchanged)
struct SpecialtyCategory: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let iconName: String
    let caseCount: Int
}

// MARK: - Main View
struct CaseLibraryView: View {
    // MARK: - Properties
    @Query(sort: \PatientCase.specialty) private var allCases: [PatientCase]
    @State private var searchText = ""
    @State private var navigationPath = NavigationPath()
    @FocusState private var isSearchFieldFocused: Bool
    
    // Config
    private let enableHaptics = true
    
    // MARK: - Computed Properties
    private var specialtyCategories: [SpecialtyCategory] {
        let groupedBySpecialty = Dictionary(grouping: allCases, by: { $0.specialty })
        return groupedBySpecialty.map { (name, cases) in
            SpecialtyCategory(
                name: name,
                iconName: SpecialtyDetailsProvider.details(for: name).iconName,
                caseCount: cases.count
            )
        }.sorted { $0.name < $1.name }
    }
    
    private var filteredSpecialties: [SpecialtyCategory] {
        if searchText.isEmpty {
            return specialtyCategories
        } else {
            return specialtyCategories.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // MARK: - Body
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 24) {
                    // Floating Search Header
                    searchHeader
                    
                    // Grid Content
                    if filteredSpecialties.isEmpty {
                        emptyState
                    } else {
                        specialtyGrid
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 100) // Space for tab bar
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .onTapGesture {
                isSearchFieldFocused = false
            }
            .navigationTitle("Library") // Standard Centered Title
            .navigationBarTitleDisplayMode(.inline) // Force inline for consistency
            .navigationDestination(for: SpecialtyCategory.self) { category in
                CaseCategoryListView(specialty: category.name)
            }
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var searchHeader: some View {
        VStack(spacing: 12) {
            // Description Text
            Text("Browse by specialty to find relevant clinical scenarios.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
            
            // Cinematic Search Field
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.secondary)
                
                TextField("Search departments...", text: $searchText)
                    .focused($isSearchFieldFocused)
                    .font(.system(size: 16))
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 10, y: 5)
        }
        .padding(.bottom, 10)
    }
    
    @ViewBuilder
    private var specialtyGrid: some View {
        // ✅ UPDATED: Adaptive Grid Layout (minimum 160)
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], 
            spacing: 16
        ) {
            ForEach(Array(filteredSpecialties.enumerated()), id: \.element.id) { index, category in
                NavigationLink(value: category) {
                    CategoryCardView(
                        specialty: category.name,
                        iconName: category.iconName,
                        caseCount: category.caseCount,
                        color: SpecialtyDetailsProvider.color(for: category.name)
                    )
                }
                .buttonStyle(CardButtonStyle(enableHaptics: enableHaptics))
                // ✅ RESTORED: Cascade/Spring Animation
                .animation(
                    .spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0)
                    .delay(Double(index) * 0.05), // Stagger delay based on index
                    value: filteredSpecialties // Trigger when data changes
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    @ViewBuilder
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Results", systemImage: "magnifyingglass")
        } description: {
            Text("Try adjusting your search terms.")
        }
        .padding(.top, 60)
    }
}

// MARK: - Custom Button Style
struct CardButtonStyle: ButtonStyle {
    var enableHaptics: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .rotation3DEffect(
                .degrees(configuration.isPressed ? 8 : 0),
                axis: (x: configuration.isPressed ? -1.0 : 0, y: configuration.isPressed ? 1.0 : 0, z: 0)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.5, blendDuration: 0), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light, intensity: 0.5), trigger: configuration.isPressed) { _,_ in
                return enableHaptics
            }
    }
}