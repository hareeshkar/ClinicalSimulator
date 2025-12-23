import Foundation

// MARK: - Top-Level Case Structure

struct EnhancedCaseDetail: Codable {
    let metadata: Metadata
    let patientProfile: PatientProfile
    let initialPresentation: InitialPresentation
    let dynamicState: DynamicState
    let dataSources: DataSources
}

// MARK: - Core Components

struct Metadata: Codable {
    let caseId: String
    let title: String
    let specialty: String
    let difficulty: String
    let finalDiagnosis: String?
    let teachingPoints: [String]?
    // ✅ NEW: decode optional recommendedForLevels from JSON
    let recommendedForLevels: [String]?
}

struct PatientProfile: Codable {
    let name: String
    let age: String
    let gender: String
}

// MARK: - Patient Presentation

struct InitialPresentation: Codable {
    let chiefComplaint: String
    let summary: String
    let history: History
    let vitals: Vitals
}

struct StructuredPastHistory: Codable {
    let medicalHistory: String
    let surgicalHistory: String
    let medications: String
    let allergies: String
    let socialHistory: String
}

struct History: Codable {
    let presentIllness: String
    let pastMedicalHistory: StructuredPastHistory
}

struct Vitals: Codable, Hashable {
    var heartRate: Int?
    var respiratoryRate: Int?
    var bloodPressure: String?
    var oxygenSaturation: Int?
}

// MARK: - Dynamic Simulation State

struct DynamicState: Codable {
    let states: [String: StateDetail]
}

struct StateDetail: Codable {
    let description: String
    let trigger: String?
    let vitals: Vitals?
    let physicalExamFindings: [String: String]?
    let consequences: [TriggerConsequence]?
}

struct TriggerConsequence: Codable {
    let trigger: String
    let targetState: String
    let probability: Double?
    let severity: String?
}

// MARK: - Data Sources & Orderable Items

struct DataSources: Codable {
    let orderableItems: [TestResult]
}

// ✅ FIXED: Added Identifiable conformance to TestResult
struct TestResult: Codable, Hashable, Identifiable {
    let testName: String
    var result: String?
    let category: String
    let isCriticalIntervention: Bool?
    let isLowYield: Bool?
    
    /// Unique identifier based on testName
    var id: String { testName }
}

// MARK: - EnhancedCaseDetail Extensions

extension EnhancedCaseDetail {
    
    /// Encodes the current instance into a pretty-printed JSON string.
    func toJSONString() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        do {
            let data = try encoder.encode(self)
            return String(data: data, encoding: .utf8) ?? "{\"error\":\"Failed to encode case to JSON string.\"}"
        } catch {
            return "{\"error\":\"Failed to encode case: \(error.localizedDescription)\"}"
        }
    }
    
    /// Redacts sensitive details and returns a student-safe JSON string.
    func studentFacingJSON(anonymizeName: Bool = false) -> String {
        // Step 1: Encode to Data
        guard let data = try? JSONEncoder().encode(self) else {
            return "{\"error\":\"CRITICAL: Failed to encode original case.\"}"
        }

        // Step 2: Convert to mutable dictionary
        guard var json = (try? JSONSerialization.jsonObject(with: data, options: .mutableContainers)) as? [String: Any] else {
            return "{\"error\":\"CRITICAL: Failed to parse case into a mutable dictionary.\"}"
        }

        // --- Redact metadata ---
        if var metadata = json["metadata"] as? [String: Any] {
            metadata["finalDiagnosis"] = "Withheld for simulation."
            metadata.removeValue(forKey: "teachingPoints")
            json["metadata"] = metadata
        }

        // --- Redact patient name ---
        if anonymizeName, var profile = json["patientProfile"] as? [String: Any] {
            profile["name"] = "Anonymous Patient"
            json["patientProfile"] = profile
        }

        // --- Redact test results ---
        if var dataSources = json["dataSources"] as? [String: Any],
           let items = dataSources["orderableItems"] as? [[String: Any]] {
            
            let maskedItems = items.map { item -> [String: Any] in
                var mutableItem = item
                mutableItem["result"] = "Result will be available once ordered."
                mutableItem.removeValue(forKey: "isLowYield")
                mutableItem.removeValue(forKey: "isCriticalIntervention")
                return mutableItem
            }
            dataSources["orderableItems"] = maskedItems
            json["dataSources"] = dataSources
        }

        // Step 3: Re-encode redacted JSON
        guard let redactedData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted]),
              let redactedString = String(data: redactedData, encoding: .utf8) else {
            return "{\"error\":\"CRITICAL: Failed to re-encode redacted JSON.\"}"
        }

        return redactedString
    }
}

// MARK: - Vitals Extension (Physiology Engine Helpers)

extension Vitals {
    /// Helper to decompose BP string "120/80 mmHg" into (120, 80).
    var bpComponents: (systolic: Int, diastolic: Int)? {
        guard let bp = bloodPressure else { return nil }
        let clean = bp.replacingOccurrences(of: " mmHg", with: "")
        let parts = clean.components(separatedBy: "/")
        guard parts.count == 2,
              let sys = Int(parts[0].trimmingCharacters(in: .whitespaces)),
              let dia = Int(parts[1].trimmingCharacters(in: .whitespaces)) else {
            return nil
        }
        return (sys, dia)
    }
    
    /// Helper to reconstruct BP string from integers.
    static func formatBP(systolic: Int, diastolic: Int) -> String {
        return "\(systolic)/\(diastolic) mmHg"
    }
}
