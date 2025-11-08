// Views/PatientMonitorView.swift

import SwiftUI

struct PatientMonitorView: View {
    // MARK: - Properties (Backend-driven)
    let patientProfile: PatientProfile?
    let vitals: Vitals
    @Binding var isSheetPresented: Bool
    @Binding var isHudExpanded: Bool
    
    // MARK: - Main Body
    var body: some View {
        VStack(spacing: 0) { // Removed spacing for a tighter composition
            
            // The header is now more compact and acts as the main tap target.
            headerView
            
            // The vitals grid smoothly transitions in and out.
            if isHudExpanded {
                VitalsGridView(vitals: vitals)
                    .padding(.top, 12)
                    .padding(10) // slight full padding around vitals
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .top)))
            }
        }
        .padding(12)
        .contentShape(Rectangle()) // Makes the entire padded area tappable
        .onTapGesture {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isHudExpanded.toggle()
            }
        }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: isHudExpanded)

    }
    
    // MARK: - ViewBuilder Sub-components
    
    @ViewBuilder
    private var headerView: some View {
        HStack(spacing: 8) {
            if let profile = patientProfile {
                Text(profile.name)
                    .font(.headline.weight(.semibold)) // slightly smaller than title3
                
                Text("(\(profile.age))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // The chart button is now a clearer, labeled button style.
            Button(action: { isSheetPresented = true }) {
                Image(systemName: "list.clipboard.fill")
                Text("Chart")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .font(.caption2) // reduce button label size
            .tint(.secondary)
            
            // The chevron uses a capsule background for a more defined look.
            Image(systemName: "chevron.up")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)
                .background(Color(.systemGray5), in: Circle())
                .rotationEffect(.degrees(isHudExpanded ? 0 : -180)) // Flip animation
        }
    }
}

// MARK: - Vitals Grid
struct VitalsGridView: View {
    let vitals: Vitals
    
    var body: some View {
        // Increased spacing for a cleaner, more readable layout.
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
            GridRow {
                VitalSignView(label: "HR", vitals: vitals)
                VitalSignView(label: "BP", vitals: vitals)
            }
            GridRow {
                VitalSignView(label: "RR", vitals: vitals)
                VitalSignView(label: "SpO2", vitals: vitals)
            }
        }
    }
}

// MARK: - Enhanced Vital Sign View (with "Live" Animation)
struct VitalSignView: View {
    let label: String
    let vitals: Vitals
    
    // A helper struct to encapsulate the complex logic, keeping the view body clean.
    private var context: ClinicalContext {
        ClinicalContext(label: label, vitals: vitals)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                // The core of the new animation.
                Text(context.value)
                    .font(.system(.title3, design: .monospaced).weight(.semibold))
                    .foregroundStyle(context.color)
                    // This tells SwiftUI to animate changes to numbers with a vertical slide.
                    .contentTransition(.numericText(value: context.numericValue))
                
                if !context.unit.isEmpty {
                    Text(context.unit)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            if let status = context.status {
                Text(status)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(context.color.opacity(0.15))
                    .foregroundStyle(context.color)
                    .clipShape(Capsule())
            } else {
                // Add an empty capsule to maintain layout consistency when there's no status.
                Capsule().fill(Color.clear).frame(height: 16)
            }
        }
        // Animate all changes within this view with a snappy spring.
        .animation(.spring(response: 0.36, dampingFraction: 0.8), value: context.value)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // A helper struct to encapsulate the complex display logic, keeping the view body clean.
    private struct ClinicalContext {
        let label: String
        let vitals: Vitals
        
        var value: String {
            switch label {
            case "HR": return vitals.heartRate.map(String.init) ?? "--"
            case "BP": return vitals.bloodPressure ?? "--/--"
            case "RR": return vitals.respiratoryRate.map(String.init) ?? "--"
            case "SpO2": return vitals.oxygenSaturation.map { "\($0)%" } ?? "--%"
            default: return "--"
            }
        }
        
        // A numeric representation used for the contentTransition.
        var numericValue: Double {
            switch label {
            case "HR": return Double(vitals.heartRate ?? 0)
            case "RR": return Double(vitals.respiratoryRate ?? 0)
            case "SpO2": return Double(vitals.oxygenSaturation ?? 0)
            default: return 0 // BP is non-numeric, so it will fall back to a fade.
            }
        }
        
        var unit: String {
            switch label {
            case "HR": return "bpm"
            case "BP": return "mmHg"
            case "RR": return "/min"
            default: return ""
            }
        }
        
        var status: String? {
            switch label {
            case "HR":
                guard let hr = vitals.heartRate else { return nil }
                return hr < 60 ? "Low" : hr > 100 ? "High" : nil
            case "BP":
                guard let bp = vitals.bloodPressure else { return nil }
                let components = bp.split(separator: "/")
                if components.count == 2, let systolic = Int(components[0]), let diastolic = Int(components[1]) {
                    return systolic > 140 || diastolic > 90 ? "High" : systolic < 90 || diastolic < 60 ? "Low" : nil
                }
                return nil
            case "RR":
                guard let rr = vitals.respiratoryRate else { return nil }
                return rr < 12 ? "Low" : rr > 20 ? "High" : nil
            case "SpO2":
                guard let spo2 = vitals.oxygenSaturation else { return nil }
                return spo2 < 95 ? "Low" : nil
            default: return nil
            }
        }
        
        var color: Color {
            switch label {
            case "HR":
                guard let hr = vitals.heartRate else { return .gray }
                return hr < 60 ? .blue : hr > 100 ? .red : .primary
            case "BP":
                guard let status = status else { return .primary }
                return status == "High" ? .red : status == "Low" ? .blue : .primary
            case "RR":
                guard let rr = vitals.respiratoryRate else { return .gray }
                return rr < 12 ? .blue : rr > 20 ? .red : .primary
            case "SpO2":
                guard let spo2 = vitals.oxygenSaturation else { return .gray }
                return spo2 < 95 ? .red : .primary
            default: return .gray
            }
        }
    }
}


// MARK: - Preview (with live update simulation)
#Preview {
    struct PatientMonitorPreview: View {
        @State var vitals = Vitals(heartRate: 145, respiratoryRate: 38, bloodPressure: "98/65 mmHg", oxygenSaturation: 98)
        @State var isSheetPresented = false
        @State var isHudExpanded = true
        
        var body: some View {
            VStack(spacing: 20) {
                PatientMonitorView(
                    patientProfile: PatientProfile(name: "Leo Chen", age: "2 years old", gender: "Male"),
                    vitals: vitals,
                    isSheetPresented: $isSheetPresented,
                    isHudExpanded: $isHudExpanded
                )
                .background(.regularMaterial)
                .cornerRadius(20)
                .shadow(radius: 5)

                Button("Simulate Vitals Change") {
                    // This simulates the patient's condition improving
                    vitals = Vitals(heartRate: 90, respiratoryRate: 22, bloodPressure: "105/70 mmHg", oxygenSaturation: 99)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
            }
            .padding()
            .background(Color(.systemGroupedBackground))
        }
    }
    return PatientMonitorPreview()
}
