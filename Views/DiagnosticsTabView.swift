import SwiftUI

// MARK: - Diagnostic Category (Unchanged)
struct DiagnosticCategory: Hashable {
    let name: String

    var iconName: String {
        switch name {
        case "Lab": return "testtube.2"
        case "Imaging": return "camera.metering.matrix"
        case "Treatment": return "cross.case.fill"
        case "Procedure": return "scissors"
        case "Consult": return "person.2.wave.2.fill"
        case "Physical Exam Maneuver": return "figure.arms.open"
        default: return "staroflife.fill"
        }
    }
}

struct DiagnosticsTabView: View {
    @ObservedObject var viewModel: DiagnosticsViewModel
    
    // State for the justification sheet
    @State private var itemToOrder: TestResult?
    @State private var justificationReason: String = ""

    @State private var isResultsSectionExpanded = true
    @State private var expandedResultID: String? = nil
    @State private var expandedCategory: String? = nil
    @State private var searchText = ""

    private var sortedCategories: [DiagnosticCategory] {
        viewModel.groupedAvailableItems.keys.sorted().map { DiagnosticCategory(name: $0) }
    }

    private var filteredCategories: [DiagnosticCategory] {
        if searchText.isEmpty {
            return sortedCategories
        }
        return sortedCategories.filter { category in
            viewModel.groupedAvailableItems[category.name]?.contains {
                $0.testName.localizedStandardContains(searchText)
            } ?? false
        }
    }

    var body: some View {
        // ✅ THE GATING LOGIC: Check if ordering is allowed.
        if !viewModel.canOrderTests {
            VStack(spacing: 16) {
                Image(systemName: "lightbulb.slash.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.secondary)
                Text("Diagnostics Locked")
                    .font(.title2.bold())
                Text("Please go to the 'Notes' tab and submit your initial differential diagnosis to proceed.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
        } else {
            // --- The original UI is now in the 'else' block ---
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    resultsSection
                    availableOrdersSection
                }
                .padding()
            }
            .searchable(text: $searchText, prompt: "Search for a test or treatment")
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            // ✅ NEW: The sheet for capturing justification.
            .sheet(item: $itemToOrder) { item in
                justificationSheet(for: item)
            }
        }
    }
    
    // ✅ NEW: A view builder for the justification sheet.
    @ViewBuilder
    private func justificationSheet(for item: TestResult) -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text(item.testName)
                    .font(.largeTitle.bold())
                
                Text("Reason for ordering (optional):")
                    .font(.headline)
                
                TextEditor(text: $justificationReason)
                    .frame(height: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                    )
                
                Spacer()
                
                Button(action: {
                    viewModel.orderTest(named: item.testName, reason: justificationReason)
                    itemToOrder = nil // Dismiss sheet
                    justificationReason = "" // Reset for next time
                }) {
                    Text("Confirm Order")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.bottom)
            }
            .padding()
            .navigationTitle("Confirm Order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { itemToOrder = nil }
                }
            }
        }
    }

    // MARK: - Results Accordion
    @ViewBuilder
    private var resultsSection: some View {
        if !viewModel.orderedTests.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    withAnimation(.spring()) {
                        isResultsSectionExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Label("Ordered & Results", systemImage: "checklist.checked")
                            .font(.title2.bold())
                        Spacer()
                        Image(systemName: "chevron.right")
                            .rotationEffect(.degrees(isResultsSectionExpanded ? 90 : 0))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .tint(.accentColor)

                if isResultsSectionExpanded {
                    ForEach(viewModel.orderedTests, id: \.self) { test in
                        ResultCardView(
                            testResult: test,
                            isExpanded: expandedResultID == test.testName
                        )
                        .onTapGesture {
                            withAnimation(.spring()) {
                                expandedResultID = (expandedResultID == test.testName) ? nil : test.testName
                            }
                        }
                        .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
                    }
                }
            }
        }
    }

    // MARK: - Available Orders Accordion
    @ViewBuilder
    private var availableOrdersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Diagnostic Options", systemImage: "list.bullet.clipboard")
                .font(.title2.bold())
                .foregroundStyle(.primary)

            ForEach(filteredCategories, id: \.self) { category in
                VStack(spacing: 8) {
                    DiagnosticCategoryRow(
                        category: category,
                        isExpanded: expandedCategory == category.name
                    )
                    .onTapGesture {
                        withAnimation(.spring()) {
                            expandedCategory = (expandedCategory == category.name) ? nil : category.name
                        }
                    }

                    if expandedCategory == category.name {
                        let items = viewModel.groupedAvailableItems[category.name] ?? []
                        let filteredItems = items.filter {
                            searchText.isEmpty || $0.testName.localizedStandardContains(searchText)
                        }

                        ForEach(filteredItems, id: \.self) { item in
                            DiagnosticItemRow(
                                testResult: item,
                                isOrdered: viewModel.orderedTests.contains(where: { $0.testName == item.testName }),
                                onSelect: { // Use onSelect here
                                    itemToOrder = item // Set the state to present the sheet
                                }
                            )
                            .transition(.asymmetric(insertion: .opacity, removal: .scale.combined(with: .opacity)))
                        }
                    }
                }
            }
        }
    }
}

// MARK: - ResultCardView
struct ResultCardView: View {
    let testResult: TestResult
    let isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: DiagnosticCategory(name: testResult.category).iconName)
                Text(testResult.testName)
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.down")
                    .rotationEffect(.degrees(isExpanded ? 0 : -90))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)

            if isExpanded {
                Divider()
                Text(testResult.result ?? "Result pending or not applicable.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 3)
        .contentShape(Rectangle())
    }
}

// MARK: - DiagnosticCategoryRow (Unchanged)
struct DiagnosticCategoryRow: View {
    let category: DiagnosticCategory
    var isExpanded: Bool

    var body: some View {
        HStack {
            Image(systemName: category.iconName)
            Text(category.name)
                .font(.headline.weight(.semibold))
            Spacer()
            Image(systemName: "chevron.right")
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
        .contentShape(Rectangle())
    }
}

// ✅ MODIFIED: The order button now presents the justification sheet.
struct DiagnosticItemRow: View {
    let testResult: TestResult
    let isOrdered: Bool
    let onSelect: () -> Void // Changed from onOrder to onSelect

    var body: some View {
        Button(action: onSelect) { // Call onSelect
            HStack {
                Text(testResult.testName)
                Spacer()
                Image(systemName: isOrdered ? "checkmark.circle.fill" : "plus.circle.fill")
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .foregroundStyle(isOrdered ? .secondary : Color.accentColor)
        .disabled(isOrdered)
        .buttonStyle(.plain)
    }
}
