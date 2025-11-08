// Views/CaseLibraryView.swift

import SwiftUI
import SwiftData

// MARK: - Model

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
    @FocusState private var isSearchFieldFocused: Bool // Controls keyboard focus
    
    // ✅ 3. Flag to easily enable/disable haptics
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
                    // The header now contains our custom, non-moving search bar
                    headerView
                    
                    if filteredSpecialties.isEmpty {
                        ContentUnavailableView(
                            "No Specialties Found",
                            systemImage: "magnifyingglass",
                            description: Text(
                                searchText.isEmpty
                                    ? "There are currently no cases available."
                                    : "Check your spelling or try a different search term."
                            )
                        )
                        .padding(.top, 50)
                    } else {
                        gridOfSpecialties
                    }
                }
                .padding(.horizontal)
            }
            // ✅ 1. Keyboard is dismissed naturally when scrolling
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            // ✅ 1. Tap gesture on the background to dismiss keyboard AND cancel search
            .onTapGesture {
                isSearchFieldFocused = false
                
            }
            .navigationTitle("Explore by Specialty")
            .navigationDestination(for: SpecialtyCategory.self) { category in
                CaseCategoryListView(specialty: category.name)
            }
        }
        .dismissKeyboardOnTap()
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 16) { // Increased spacing for search bar
            // Subheading remains in place
            Text("Select a category to practice your clinical reasoning skills.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            // ✅ 2. Custom search bar that doesn't push the UI up
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search Specialties", text: $searchText)
                    .focused($isSearchFieldFocused) // Link to focus state
                
                // Show clear button only when there is text
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain) // Use plain style to avoid coloring the button
                }
            }
            .padding(10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top)
    }
    
    @ViewBuilder
    private var gridOfSpecialties: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 160), spacing: 16)],
            spacing: 16
        ) {
            ForEach(Array(filteredSpecialties.enumerated()), id: \.element.id) { index, category in
                Button(action: {
                    isSearchFieldFocused = false // Dismiss keyboard on navigation
                    navigationPath.append(category)
                }) {
                    CategoryCardView(
                        specialty: category.name,
                        iconName: category.iconName,
                        caseCount: category.caseCount,
                        color: SpecialtyDetailsProvider.color(for: category.name)
                    )
                }
                .buttonStyle(CardButtonStyle(enableHaptics: self.enableHaptics))
                // ✅ 3. Improved animation choreography
                .animation(
                    .spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0)
                    .delay(Double(index) * 0.05), // Slightly faster cascade
                    value: filteredSpecialties
                )
            }
        }
    }
}

// MARK: - Custom Button Style
// ✅ 3. Now configurable to enable/disable haptics
struct CardButtonStyle: ButtonStyle {
    var enableHaptics: Bool = true
    
    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed
        
        configuration.label
            .rotation3DEffect(
                .degrees(isPressed ? 8 : 0),
                axis: (x: isPressed ? -1.0 : 0, y: isPressed ? 1.0 : 0, z: 0)
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.5, blendDuration: 0), value: isPressed)
            .sensoryFeedback(.impact(weight: .light, intensity: 0.8), trigger: isPressed) { _,_  in
                // Only provide feedback if haptics are enabled
                return enableHaptics
            }
    }
}

// Note: The `hideKeyboard()` extension is no longer needed with these modern techniques.
