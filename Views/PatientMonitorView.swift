import SwiftUI
import CoreHaptics
import UIKit

// MARK: - 🏥 CLINICAL DESIGN SYSTEM
private enum ClinicalTheme {
    // Backgrounds
    static let surface = Material.regular // Glassmorphic base
    static let panelBackground = Color(red: 0.1, green: 0.1, blue: 0.12) // Matte medical dark grey
    
    // Status
    static let critical = Color(red: 0.8, green: 0.0, blue: 0.0)
    static let stable = Color.green
}

// MARK: - 🎨 DYNAMIC VITAL SIGN COLORS (Superior Logic - Shared across app)
enum VitalColors {
    
    static func heartRate(bpm: Int?) -> Color {
        guard let bpm = bpm else { return .gray }
        switch bpm {
        case ..<40:           return Color(red: 0.8, green: 0.0, blue: 0.0)  // Critical low
        case 40..<50:         return Color(red: 0.95, green: 0.5, blue: 0.0) // Moderate low
        case 50..<60:         return Color(red: 1.0, green: 0.8, blue: 0.2)  // Mild low
        case 60...100:        return Color(red: 0.2, green: 0.8, blue: 0.3)  // Normal (green)
        case 101...120:       return Color(red: 1.0, green: 0.8, blue: 0.2)  // Mild high
        case 121...140:       return Color(red: 0.95, green: 0.5, blue: 0.0) // Moderate high
        default:              return Color(red: 0.8, green: 0.0, blue: 0.0)  // Critical high
        }
    }
    
    static func oxygenSaturation(percentage: Int?) -> Color {
        guard let percentage = percentage else { return .gray }
        switch percentage {
        case ..<85:           return Color(red: 0.8, green: 0.0, blue: 0.0)  // Critical
        case 85..<90:         return Color(red: 0.95, green: 0.5, blue: 0.0) // Moderate
        case 90..<94:         return Color(red: 1.0, green: 0.8, blue: 0.2)  // Mild
        case 94...100:        return Color(red: 0.2, green: 0.7, blue: 0.9)  // Normal (cyan)
        default:              return Color(red: 0.2, green: 0.7, blue: 0.9)
        }
    }
    
    static func respiratoryRate(rpm: Int?) -> Color {
        guard let rpm = rpm else { return .gray }
        switch rpm {
        case ..<8:            return Color(red: 0.8, green: 0.0, blue: 0.0)  // Critical low
        case 8..<10:          return Color(red: 0.95, green: 0.5, blue: 0.0) // Moderate low
        case 10..<12:         return Color(red: 1.0, green: 0.8, blue: 0.2)  // Mild low
        case 12...20:         return Color(red: 1.0, green: 0.8, blue: 0.2)  // Normal (amber)
        case 21...25:         return Color(red: 0.95, green: 0.5, blue: 0.0) // Mild high
        case 26...30:         return Color(red: 0.95, green: 0.5, blue: 0.0) // Moderate high
        default:              return Color(red: 0.8, green: 0.0, blue: 0.0)  // Critical high
        }
    }
    
    static func bloodPressure(bpString: String?) -> Color {
        guard let bpString = bpString,
              let systolic = extractSystolic(from: bpString) else {
            return .primary
        }
        switch systolic {
        case ..<90:           return Color(red: 0.8, green: 0.0, blue: 0.0)  // Hypotension
        case 90..<100:        return Color(red: 0.95, green: 0.5, blue: 0.0) // Low-normal
        case 100..<120:       return Color.white                          // Normal
        case 120..<140:       return Color(red: 1.0, green: 0.8, blue: 0.2)  // Elevated
        case 140..<160:       return Color(red: 0.95, green: 0.5, blue: 0.0) // Stage 1 HTN
        default:              return Color(red: 0.8, green: 0.0, blue: 0.0)  // Stage 2+ HTN
        }
    }
    
    static func isCritical(heartRate: Int?, oxygenSaturation: Int?) -> Bool {
        let hr = heartRate ?? 80
        let spo2 = oxygenSaturation ?? 99
        return hr > 130 || hr < 40 || spo2 < 90
    }
    
    private static func extractSystolic(from bpString: String) -> Int? {
        let components = bpString.split(separator: "/")
        guard let systolicString = components.first,
              let systolic = Int(systolicString.trimmingCharacters(in: .whitespaces)) else {
            return nil
        }
        return systolic
    }
}

struct PatientMonitorView: View {
    // MARK: - Properties
    let patientProfile: PatientProfile?
    let vitals: Vitals
    @Binding var isSheetPresented: Bool
    @Binding var isHudExpanded: Bool
    
    // MARK: - Body
    var body: some View {
        ClinicalMonitorWidget(
            patientProfile: patientProfile,
            vitals: vitals,
            isExpanded: $isHudExpanded,
            onChartAction: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                isSheetPresented = true
            },
            showChartButton: true
        )
    }
}

// MARK: - 🏥 REUSABLE COMPONENT: CLINICAL MONITOR WIDGET
/// Complete monitor display with ECG, haptics, and dynamic vitals
/// Used by PatientMonitorView and CaseBriefingView
struct ClinicalMonitorWidget: View {
    let patientProfile: PatientProfile?
    let vitals: Vitals
    @Binding var isExpanded: Bool
    let onChartAction: (() -> Void)?
    let showChartButton: Bool
    
    // Engines
    @StateObject private var haptics = CardiacHaptics()
    
    // App lifecycle
    @Environment(\.scenePhase) private var scenePhase
    
    // Computed State
    private var isCritical: Bool {
        VitalColors.isCritical(heartRate: vitals.heartRate, oxygenSaturation: vitals.oxygenSaturation)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 1. Interactive Header (Always Visible)
            MonitorHeader(
                profile: patientProfile,
                vitals: vitals,
                isExpanded: isExpanded,
                isCritical: isCritical,
                onChartAction: onChartAction,
                onToggleAction: toggleExpansion,
                showChartButton: showChartButton
            )
            .padding(16)
            .background(ClinicalTheme.panelBackground)
            
            // 2. Expanded Clinical Details (Collapsible)
            if isExpanded {
                VStack(spacing: 0) {
                    Divider().overlay(Color.white.opacity(0.1))
                    
                    // Live ECG
                    ECGStripView(
                        heartRate: vitals.heartRate ?? 80,
                        color: isCritical ? ClinicalTheme.critical : VitalColors.heartRate(bpm: vitals.heartRate)
                    )
                    .frame(height: 60)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 16)
                    
                    // Data Grid
                    ClinicalDataGrid(vitals: vitals)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                }
                .background(ClinicalTheme.panelBackground)
                .transition(.move(edge: .top).combined(with: .opacity))
                .clipped()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
        .padding(16)
        .onChange(of: vitals.heartRate) { _, newRate in
            haptics.sync(rate: newRate, active: isExpanded && scenePhase == .active)
        }
        .onChange(of: isExpanded) { _, expanded in
            haptics.sync(rate: vitals.heartRate, active: expanded && scenePhase == .active)
        }
        .onChange(of: scenePhase) { _, newPhase in
            haptics.sync(rate: vitals.heartRate, active: isExpanded && newPhase == .active)
        }
        .onAppear {
            if isExpanded && scenePhase == .active {
                haptics.sync(rate: vitals.heartRate, active: true)
            }
        }
        .onDisappear { haptics.stop() }
    }
    
    private func toggleExpansion() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            isExpanded.toggle()
        }
    }
}

// MARK: - 📟 COMPONENT: HEADER
struct MonitorHeader: View {
    let profile: PatientProfile?
    let vitals: Vitals
    let isExpanded: Bool
    let isCritical: Bool
    let onChartAction: (() -> Void)?
    let onToggleAction: () -> Void
    let showChartButton: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // A. Patient Context
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(isCritical ? ClinicalTheme.critical : ClinicalTheme.stable)
                        .frame(width: 6, height: 6)
                        .shadow(color: (isCritical ? ClinicalTheme.critical : ClinicalTheme.stable).opacity(0.5), radius: 4)
                    
                    Text(profile?.name ?? "Unknown Patient")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
                
                HStack(spacing: 6) {
                    Text(profile?.age ?? "--")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.gray)
                    
                    if !isExpanded {
                        Text("•")
                            .foregroundStyle(.gray.opacity(0.8))
                        Text("HR \(vitals.heartRate ?? 0) • \(vitals.oxygenSaturation ?? 0)%")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
            
            Spacer()
            
            // B. Chart Button (Only show if enabled)
            if showChartButton, let onChartAction = onChartAction {
                Button(action: onChartAction) {
                    HStack(spacing: 6) {
                        Image(systemName: "list.clipboard")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Chart")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundStyle(.white)
            }
            
            // C. Chevron Toggle
            Button(action: onToggleAction) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.gray)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
        }
        .contentShape(Rectangle()) // Make header tappable for toggle
        .onTapGesture(perform: onToggleAction)
    }
}

// MARK: - 🔢 COMPONENT: DATA GRID
struct ClinicalDataGrid: View {
    let vitals: Vitals
    
    var body: some View {
        HStack(spacing: 0) {
            // Heart Rate
            MetricCell(
                value: vitals.heartRate.map(String.init) ?? "--",
                label: "HR",
                unit: "bpm",
                color: VitalColors.heartRate(bpm: vitals.heartRate)
            )
            
            Spacer()
            
            // BP
            MetricCell(
                value: vitals.bloodPressure ?? "--/--",
                label: "NIBP",
                unit: "mmHg",
                color: VitalColors.bloodPressure(bpString: vitals.bloodPressure)
            )
            
            Spacer()
            
            // Saturation
            MetricCell(
                value: vitals.oxygenSaturation.map(String.init) ?? "--",
                label: "SpO₂",
                unit: "%",
                color: VitalColors.oxygenSaturation(percentage: vitals.oxygenSaturation)
            )
            
            Spacer()
            
            // Respiratory Rate
            MetricCell(
                value: vitals.respiratoryRate.map(String.init) ?? "--",
                label: "RR",
                unit: "/min",
                color: VitalColors.respiratoryRate(rpm: vitals.respiratoryRate)
            )
        }
    }
}

struct MetricCell: View {
    let value: String
    let label: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
                Text(unit)
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundStyle(.gray)
            }
            
            Text(value)
                .font(.system(size: 24, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
                .contentTransition(.numericText()) // iOS 17 Animation
                .animation(.snappy, value: value)
        }
        .frame(minWidth: 60, alignment: .leading)
    }
}

// MARK: - 📉 COMPONENT: ECG STRIP (High Fidelity)
struct ECGStripView: View {
    let heartRate: Int
    let color: Color

    @State private var displayedBPM: Double

    init(heartRate: Int, color: Color) {
        self.heartRate = heartRate
        self.color = color
        let clamped = max(30, min(heartRate, 220))
        _displayedBPM = State(initialValue: Double(clamped))
    }
    
    var body: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let widthScale: Double = 240.0 // Slower scan speed (prevents "flashing")
            
            Canvas { context, size in
                var path = Path()
                let midY = size.height / 2
                
                // Draw logic
                path.move(to: CGPoint(x: 0, y: midY))

                // Use a 1pt step: crisp but stable
                let bpm = max(30.0, min(displayedBPM, 220.0))
                let secondsPerBeat = 60.0 / bpm

                func gaussian(_ phase: Double, center: Double, width: Double, amplitude: Double) -> Double {
                    let z = (phase - center) / width
                    return amplitude * exp(-0.5 * z * z)
                }

                for x in stride(from: 0, through: size.width, by: 1.0) {
                    // Sample time shifted by scan position to create a true scrolling strip.
                    let sampleTime = time - (Double(x) / widthScale)

                    // Subtle RR variability (kept small to avoid "flutter" look)
                    let rrMod = 1.0 + (sin(sampleTime * 0.35) * 0.012)
                    let adjustedSecondsPerBeat = secondsPerBeat * rrMod

                    var phase = (sampleTime / adjustedSecondsPerBeat).truncatingRemainder(dividingBy: 1.0)
                    if phase < 0 { phase += 1.0 }

                    // Clinically recognizable morphology
                    let p = gaussian(phase, center: 0.18, width: 0.030, amplitude: 0.10)
                    let q = gaussian(phase, center: 0.49, width: 0.010, amplitude: -0.18)
                    let r = gaussian(phase, center: 0.50, width: 0.006, amplitude: 1.00)
                    let s = gaussian(phase, center: 0.515, width: 0.012, amplitude: -0.28)
                    let tWave = gaussian(phase, center: 0.76, width: 0.055, amplitude: 0.30)
                    let u = gaussian(phase, center: 0.90, width: 0.030, amplitude: 0.05)

                    let signal = p + q + r + s + tWave + u

                    // Organic but stable baseline
                    let wander = sin(sampleTime * 0.9) * 1.2
                    let noise = (sin(sampleTime * 31.0) * 0.18) + (sin(sampleTime * 9.0) * 0.10)

                    let gain = size.height * 0.42
                    let yOffset = -CGFloat(signal) * gain

                    path.addLine(to: CGPoint(x: x, y: midY + yOffset + CGFloat(wander + noise)))
                }
                
                // Stroke with fade gradient at scanning edge
                context.stroke(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [color.opacity(0.1), color, color]),
                        startPoint: CGPoint(x: 0, y: 0),
                        endPoint: CGPoint(x: size.width, y: 0)
                    ),
                    lineWidth: 2
                )
            }
        }
        .background(
            // Grid Lines (Subtle)
            ZStack {
                Color.black.opacity(0.3)
                VStack(spacing: 15) { Divider().overlay(Color.white.opacity(0.05)) }
                HStack(spacing: 15) { Divider().overlay(Color.white.opacity(0.05)) }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .onChange(of: heartRate) { _, newValue in
            let clamped = max(30, min(newValue, 220))
            withAnimation(.easeOut(duration: 0.35)) {
                displayedBPM = Double(clamped)
            }
        }
    }
}

// MARK: - 🫀 HAPTIC ENGINE
@MainActor
class CardiacHaptics: ObservableObject {
    private var engine: CHHapticEngine?
    private var timer: Timer?
    private var isRunning = false
    private var lastRate: Int?
    
    init() {
        setupEngine()

        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.resumeIfNeeded()
            }
        }
    }

    private func setupEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            engine?.stoppedHandler = { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.resumeIfNeeded()
                }
            }
            engine?.resetHandler = { [weak self] in
                Task { @MainActor [weak self] in
                    self?.resumeIfNeeded()
                }
            }
            try engine?.start()
        } catch {
            engine = nil
        }
    }

    private func ensureEngineRunning() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        if engine == nil {
            setupEngine()
        }
        do {
            try engine?.start()
        } catch {
            engine = nil
        }
    }

    private func resumeIfNeeded() {
        guard isRunning else { return }
        ensureEngineRunning()
        if let lastRate {
            timer?.invalidate()
            beat(rate: lastRate)
        }
    }

    func sync(rate: Int?, active: Bool) {
        if active {
            start(rate: rate)
        } else {
            stop()
        }
    }
    
    func start(rate: Int?) {
        guard let rate else { return }
        let clamped = max(30, min(rate, 220))
        lastRate = clamped

        ensureEngineRunning()

        if isRunning {
            updateRate(clamped)
            return
        }

        isRunning = true
        beat(rate: clamped)
    }
    
    func stop() {
        isRunning = false
        timer?.invalidate()
    }
    
    func updateRate(_ rate: Int?) {
        guard let rate else { return }
        let clamped = max(30, min(rate, 220))
        lastRate = clamped
        guard isRunning else { return }
        timer?.invalidate()
        beat(rate: clamped)
    }
    
    private func beat(rate: Int) {
        let interval = 60.0 / Double(rate)
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.triggerThud()
            }
        }

        // Reduce drift but keep scheduling stable
        timer?.tolerance = min(0.03, interval * 0.06)
    }
    
    private func triggerThud() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        ensureEngineRunning()

        // Scale the "dub" delay with rate so it stays natural at tachycardia.
        let bpm = Double(max(30, min(lastRate ?? 80, 220)))
        let interval = 60.0 / bpm
        let lubDubDelay = min(0.18, max(0.10, interval * 0.35))
        
        // Premium lub-dub: tiny low-frequency body + two transients.
        let events = [
            CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    .init(parameterID: .hapticIntensity, value: 0.22),
                    .init(parameterID: .hapticSharpness, value: 0.10)
                ],
                relativeTime: 0,
                duration: 0.07
            ),
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    .init(parameterID: .hapticIntensity, value: 0.78),
                    .init(parameterID: .hapticSharpness, value: 0.34)
                ],
                relativeTime: 0
            ),
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    .init(parameterID: .hapticIntensity, value: 0.60),
                    .init(parameterID: .hapticSharpness, value: 0.30)
                ],
                relativeTime: lubDubDelay
            )
        ]
        
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            print("Haptic Error: \(error)")
        }
    }
}

// MARK: - 💓 REUSABLE COMPONENT: UNIFIED VITALS STRIP
/// Used by both PatientMonitorView and CaseBriefingView for consistent vitals display
struct VitalsStripComponent: View {
    let vitals: Vitals
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Initial Vitals", systemImage: "waveform.path.ecg")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.secondary)
                .textCase(.uppercase)
                .tracking(1)
                .padding(.leading, 4)
            
            HStack(spacing: 12) {
                VitalsMetricCell(
                    label: "HR",
                    value: vitals.heartRate.map(String.init) ?? "--",
                    unit: "bpm",
                    color: VitalColors.heartRate(bpm: vitals.heartRate)
                )
                VitalsMetricCell(
                    label: "BP",
                    value: vitals.bloodPressure ?? "--/--",
                    unit: "mmHg",
                    color: VitalColors.bloodPressure(bpString: vitals.bloodPressure)
                )
                VitalsMetricCell(
                    label: "SpO2",
                    value: "\(vitals.oxygenSaturation ?? 0)",
                    unit: "%",
                    color: VitalColors.oxygenSaturation(percentage: vitals.oxygenSaturation)
                )
                VitalsMetricCell(
                    label: "RR",
                    value: vitals.respiratoryRate.map(String.init) ?? "--",
                    unit: "/min",
                    color: VitalColors.respiratoryRate(rpm: vitals.respiratoryRate)
                )
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 8, y: 4)
        }
    }
}

// MARK: - 📊 REUSABLE SUB-COMPONENT: VITAL METRIC CELL
struct VitalsMetricCell: View {
    let label: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color.opacity(0.8))
                .textCase(.uppercase)
            
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
            
            Text(unit)
                .font(.system(size: 10))
                .foregroundStyle(Color.primary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}