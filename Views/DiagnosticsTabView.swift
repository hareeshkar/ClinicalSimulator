import SwiftUI

// MARK: - 🎨 CLINICAL DESIGN SYSTEM
private enum OrdersTheme {
    static let primaryText = Color.primary
    static let secondaryText = Color.secondary
    static let tintColor = Color.blue // Medical Blue
    static let successColor = Color.green.opacity(0.8)
    
    // Premium Medical Palette
    static let background = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark 
            ? UIColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 1.0) 
            : UIColor(red: 0.96, green: 0.97, blue: 0.99, alpha: 1.0)
    })
    
    static let cardBackground = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark 
            ? UIColor(red: 0.12, green: 0.12, blue: 0.15, alpha: 1.0) 
            : .white
    })
    
    static let divider = Color.primary.opacity(0.06)
}

struct DiagnosticCategory: Hashable {
    let name: String

    var iconName: String {
        switch name {
        case "Lab": return "testtube.2"
        case "Imaging": return "waveform.path.ecg"
        case "Treatment": return "pills"
        case "Procedure": return "syringe"
        case "Consult": return "person.2"
        case "Physical Exam Maneuver": return "stethoscope"
        default: return "doc.text"
        }
    }
}

struct DiagnosticsTabView: View {
    @ObservedObject var viewModel: DiagnosticsViewModel
    
    // State
    @State private var itemToOrder: TestResult?
    @State private var justificationReason: String = ""
    @State private var searchText = ""
    @State private var expandedCategories: Set<String> = [] // Track expanded sections
    @State private var expandedResultID: String? = nil

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
        Group {
            if !viewModel.canOrderTests {
                LockedStateView()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        // 1. ACTIVE ORDERS (Results)
                        if !viewModel.orderedTests.isEmpty {
                            ActiveOrdersSection(
                                orderedTests: viewModel.orderedTests,
                                expandedResultID: $expandedResultID
                            )
                        }
                        
                        // 2. ORDER SETS (Available Tests)
                        AvailableOrdersSection(
                            categories: filteredCategories,
                            viewModel: viewModel,
                            searchText: searchText,
                            expandedCategories: $expandedCategories,
                            onOrder: { item in
                                itemToOrder = item
                            }
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 100)
                }
                .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search order sets...")
                .background(OrdersTheme.background.ignoresSafeArea())
                .sheet(item: $itemToOrder) { item in
                    ClinicalRationaleSheet(
                        testName: item.testName,
                        reason: $justificationReason,
                        onConfirm: {
                            viewModel.orderTest(named: item.testName, reason: justificationReason)
                            itemToOrder = nil
                            justificationReason = ""
                        },
                        onCancel: {
                            itemToOrder = nil
                            justificationReason = ""
                        }
                    )
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                }
            }
        }
        .navigationTitle("Orders & Results")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - 🔒 LOCKED STATE
struct LockedStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.doc.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color.secondary.opacity(0.5))
            
            Text("Diagnostics Unavailable")
                .font(.title2.weight(.bold)) // San-serif for headings
            
            Text("Clinical protocol requires an initial differential diagnosis before proceeding with diagnostic workup.")
                .font(.subheadline) // Body text
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.secondary)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OrdersTheme.background)
    }
}

// MARK: - 📋 ACTIVE ORDERS SECTION
struct ActiveOrdersSection: View {
    let orderedTests: [TestResult]
    @Binding var expandedResultID: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Active Orders & Reports", systemImage: "doc.text.fill")
                .font(.headline)
                .foregroundStyle(OrdersTheme.secondaryText)
                .padding(.leading, 4)
            
            VStack(spacing: 12) {
                ForEach(orderedTests, id: \.self) { test in
                    OrderResultCard(
                        test: test,
                        isExpanded: expandedResultID == test.testName,
                        onTap: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                expandedResultID = (expandedResultID == test.testName) ? nil : test.testName
                            }
                        }
                    )
                }
            }
        }
    }
}

struct OrderResultCard: View {
    let test: TestResult
    let isExpanded: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(spacing: 16) {
                    // Status Icon
                    ZStack {
                        Circle()
                            .fill((test.result != nil ? OrdersTheme.successColor : Color.orange).opacity(0.1))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: test.result != nil ? "doc.text.magnifyingglass" : "clock.arrow.2.circlepath")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(test.result != nil ? OrdersTheme.successColor : Color.orange)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(test.testName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(OrdersTheme.primaryText)
                        
                        HStack(spacing: 4) {
                            Circle()
                                .fill(test.result != nil ? OrdersTheme.successColor : Color.orange)
                                .frame(width: 6, height: 6)
                            
                            Text(test.result != nil ? "Report Finalized" : "Processing Order")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.secondary.opacity(0.4))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(16)
                
                // Result Content (The Report)
                if isExpanded {
                    VStack(alignment: .leading, spacing: 12) {
                        Rectangle()
                            .fill(OrdersTheme.divider)
                            .frame(height: 1)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("CLINICAL FINDINGS")
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundStyle(Color.secondary)
                                    .tracking(1.5)
                                
                                Spacer()
                                
                                Text(Date().formatted(date: .abbreviated, time: .omitted))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(Color.secondary.opacity(0.6))
                            }
                            
                            Text(test.result ?? "The laboratory is currently processing this specimen. Results will be updated automatically upon completion of the analysis.")
                                .font(.system(size: 15))
                                .foregroundStyle(OrdersTheme.primaryText)
                                .lineSpacing(6)
                                .padding(.vertical, 4)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    }
                    .background(OrdersTheme.cardBackground.opacity(0.3))
                }
            }
            .background(OrdersTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.03), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 📁 AVAILABLE ORDERS SECTION
struct AvailableOrdersSection: View {
    let categories: [DiagnosticCategory]
    let viewModel: DiagnosticsViewModel
    let searchText: String
    @Binding var expandedCategories: Set<String>
    let onOrder: (TestResult) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Order Sets", systemImage: "folder.fill")
                .font(.headline)
                .foregroundStyle(OrdersTheme.secondaryText)
                .padding(.leading, 4)
            
            VStack(spacing: 12) {
                ForEach(categories, id: \.self) { category in
                    let isExpanded = expandedCategories.contains(category.name)
                    
                    VStack(spacing: 0) {
                        // Category Header
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                if isExpanded {
                                    expandedCategories.remove(category.name)
                                } else {
                                    expandedCategories.insert(category.name)
                                }
                            }
                        } label: {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(OrdersTheme.tintColor.opacity(isExpanded ? 1.0 : 0.1))
                                        .frame(width: 36, height: 36)
                                    
                                    Image(systemName: category.iconName)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(isExpanded ? .white : OrdersTheme.tintColor)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(category.name)
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(OrdersTheme.primaryText)
                                    
                                    if !isExpanded {
                                        let count = viewModel.groupedAvailableItems[category.name]?.count ?? 0
                                        Text("\(count) available tests")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.secondary.opacity(0.4))
                                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(OrdersTheme.cardBackground)
                        }
                        .buttonStyle(.plain)
                        
                        // Category Items (Reworked Expanded State)
                        if isExpanded {
                            let items = viewModel.groupedAvailableItems[category.name] ?? []
                            let filtered = items.filter { searchText.isEmpty || $0.testName.localizedStandardContains(searchText) }
                            
                            VStack(spacing: 0) {
                                Rectangle()
                                    .fill(OrdersTheme.divider)
                                    .frame(height: 1)
                                    .padding(.horizontal, 16)
                                
                                ForEach(filtered, id: \.self) { item in
                                    let isOrdered = viewModel.orderedTests.contains { $0.testName == item.testName }
                                    
                                    OrderRow(item: item, isOrdered: isOrdered, onOrder: { onOrder(item) })
                                    
                                    if item != filtered.last {
                                        Rectangle()
                                            .fill(OrdersTheme.divider)
                                            .frame(height: 1)
                                            .padding(.leading, 52) // Align with text
                                    }
                                }
                            }
                            .background(OrdersTheme.cardBackground.opacity(0.5))
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(isExpanded ? 0.08 : 0.03), radius: 8, y: 4)
                }
            }
        }
    }
}

struct OrderRow: View {
    let item: TestResult
    let isOrdered: Bool
    let onOrder: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Test Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isOrdered ? Color.green.opacity(0.1) : Color.primary.opacity(0.03))
                    .frame(width: 32, height: 32)
                
                Image(systemName: isOrdered ? "checkmark.circle.fill" : "doc.text")
                    .font(.system(size: 14))
                    .foregroundStyle(isOrdered ? .green : Color.secondary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.testName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isOrdered ? Color.secondary : Color.primary)
                
                if isOrdered {
                    Text("Report Pending")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.green.opacity(0.8))
                        .textCase(.uppercase)
                }
            }
            
            Spacer()
            
            if isOrdered {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.secondary.opacity(0.3))
                    .padding(8)
            } else {
                Button(action: onOrder) {
                    HStack(spacing: 4) {
                        Text("Order")
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(OrdersTheme.tintColor)
                    .clipShape(Capsule())
                    .shadow(color: OrdersTheme.tintColor.opacity(0.3), radius: 4, y: 2)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - 📝 CLINICAL RATIONALE SHEET
struct ClinicalRationaleSheet: View {
    let testName: String
    @Binding var reason: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                // Instruction
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "text.bubble")
                        .foregroundStyle(OrdersTheme.tintColor)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Clinical Indication")
                            .font(.headline)
                        Text("Why are you ordering \(testName)?")
                            .font(.subheadline)
                            .foregroundStyle(Color.secondary)
                    }
                }
                .padding(.top)
                
                // Input Area
                ZStack(alignment: .topLeading) {
                    if reason.isEmpty {
                        Text("Enter your rationale (e.g., 'Rule out pulmonary embolism')...")
                            .font(.body)
                            .foregroundStyle(Color.secondary.opacity(0.6))
                            .padding(12)
                            .padding(.top, 4)
                    }
                    
                    TextEditor(text: $reason)
                        .font(.body)
                        .frame(height: 120)
                        .padding(8)
                        .scrollContentBackground(.hidden) // Remove default gray
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                }
                
                Spacer()
                
                // Action
                Button(action: onConfirm) {
                    Text("Sign & Submit Order")
                        .font(.system(size: 17, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(reason.isEmpty ? Color.gray.opacity(0.2) : OrdersTheme.tintColor)
                        .foregroundStyle(reason.isEmpty ? Color.secondary : .white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: reason.isEmpty ? .clear : OrdersTheme.tintColor.opacity(0.3), radius: 8, y: 4)
                }
                .disabled(reason.isEmpty)
                .animation(.easeInOut, value: reason.isEmpty)
            }
            .padding(24)
            .background(OrdersTheme.cardBackground.ignoresSafeArea())
            .navigationTitle("Order Confirmation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .tint(OrdersTheme.tintColor)
                }
            }
        }
    }
}

// Helper Shape for partial corner rounding
struct CustomCornerShape: Shape {
    var corners: UIRectCorner
    var radius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}