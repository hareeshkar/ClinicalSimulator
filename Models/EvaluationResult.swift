import Foundation

/// A struct to hold the results of a student's performance evaluation.
/// We make it 'Codable' so we can easily decode it from a JSON response from the Gemini API later.
struct EvaluationResult: Codable, Hashable {
    let overallScore: Int
    let breakdown: [String: Int] // e.g., ["History Taking": 85, "Diagnosis": 90]
    let whatWentWell: String
    let areasForImprovement: String
    
    // We create a static mock property for use in our Xcode Previews.
    // This allows us to build and test our UI without needing a live AI response.
    static var mock: EvaluationResult {
        EvaluationResult(
            overallScore: 88,
            breakdown: [
                "History Taking": 92,
                "Physical Exam": 85,
                "Diagnostic Strategy": 78,
                "Treatment Plan": 95
            ],
            whatWentWell: "Excellent work on the focused history. You correctly identified the key symptoms and asked relevant follow-up questions about triggers and past medical history. Your treatment plan was appropriate and followed best practices.",
            areasForImprovement: "Consider broadening your differential diagnosis initially. While you arrived at the correct conclusion, remember to rule out other possibilities. Your diagnostic ordering could be more targeted to save time and resources."
        )
    }
}
