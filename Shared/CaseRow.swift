import SwiftUI

struct CaseRow: View {
    let patientCase: PatientCase
    let session: StudentSession?
    let action: ActionType
    let onTap: () -> Void
    
    enum ActionType { case start, `continue`, review }
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(patientCase.title)
                        .font(.headline)
                    Text(patientCase.specialty)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if action == .review, let score = session?.score {
                    Text("\(Int(score))%")
                        .font(.title2.bold())
                        .foregroundColor(.accentColor)
                } else if action == .continue {
                    Image(systemName: "play.circle.fill")
                        .font(.title)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
        }
        .foregroundColor(.primary)
    }
}
