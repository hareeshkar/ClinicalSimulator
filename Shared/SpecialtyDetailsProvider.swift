import Foundation
import SwiftUI

/// A centralized provider for UI-related details of medical specialties.
/// This struct ensures consistent icons, descriptions, and colors across the app.
struct SpecialtyDetailsProvider {
    
    /// Returns a color associated with the given medical specialty.
    /// - Parameter specialty: The name of the medical specialty.
    /// - Returns: A `Color` specific to the specialty.
    static func color(for specialty: String) -> Color {
        switch specialty {
        case "Gastroenterology":
            return .orange
        case "Pulmonology":
            return .teal
        case "Nephrology":
            return .blue
        case "Endocrinology":
            return .yellow
        case "Orthopedics":
            return .brown
        case "Emergency Medicine":
            return .red
        case "Internal Medicine":
            return .indigo
        case "Pediatrics":
            return .cyan
        case "Surgery":
            return .gray
        case "Psychiatry":
            return .purple
        case "Cardiology":
            return .pink
        case "Neurology":
            return .blue
        default:
            return .accentColor
        }
    }
    
    /// Returns an icon name and description associated with the given medical specialty.
    /// - Parameter specialty: The name of the medical specialty.
    /// - Returns: A tuple containing the icon name and a brief description.
    ///
    /// Notes:
    /// - Icon names are chosen to match SF Symbols where possible. If a highly specific organ
    ///   icon (for example, a kidney or stomach glyph) is not available in SF Symbols, we use
    ///   the closest conceptual symbol (e.g. `drop.fill` for renal / fluid balance) or recommend
    ///   a custom image asset for pixel-perfect anatomy icons.
    static func details(for specialty: String) -> (iconName: String, description: String) {
        switch specialty {
        case "Gastroenterology":
            return (
                iconName: "fork.knife",
                description: "Digestive system specialists: esophagus, stomach, intestines, liver — manage conditions like IBD, hepatitis, GERD and functional GI disorders."
            )
        case "Pulmonology":
            return (
                iconName: "lungs.fill",
                description: "Diagnose and treat respiratory and thoracic diseases such as asthma, COPD, pneumonia, and interstitial lung disease."
            )
        case "Nephrology":
            return (
                iconName: "drop.fill",
                description: "Focus on kidney function, electrolyte & fluid balance, dialysis, and hypertensive renal disease."
            )
        case "Endocrinology":
            return (
                iconName: "syringe.fill",
                description: "Hormonal and metabolic disorders: diabetes management, thyroid disease, adrenal and pituitary disorders, and hormone replacement."
            )
        case "Orthopedics":
            return (
                iconName: "figure.roll",
                description: "Musculoskeletal care: bones, joints, ligaments and tendons — fractures, arthroplasty, sports injuries and rehabilitation."
            )
        case "Emergency Medicine":
            return (
                iconName: "bolt.heart.fill",
                description: "Handle acute, life‑threatening conditions in a high‑pressure environment — rapid assessment, resuscitation, and stabilization."
            )
        case "Internal Medicine":
            return (
                iconName: "cross.case.fill",
                description: "Diagnose and manage a wide range of complex adult illnesses across organ systems; coordinate long‑term care."
            )
        case "Pediatrics":
            return (
                iconName: "figure.2.and.child.holdinghands",
                description: "Care for infants, children, and adolescents with an emphasis on growth, development, and preventive care."
            )
        case "Surgery":
            return (
                iconName: "scissors",
                description: "Address conditions requiring operative procedures, perioperative and post‑operative care across surgical subspecialties."
            )
        case "Psychiatry":
            return (
                iconName: "brain.head.profile",
                description: "Focus on mental, emotional, and behavioral disorders; combine psychotherapy, pharmacotherapy, and multidisciplinary care."
            )
        case "Cardiology":
            return (
                iconName: "heart.fill",
                description: "Specialize in disorders of the heart and cardiovascular system: ischemic heart disease, heart failure, arrhythmias, and preventive cardiology."
            )
        case "Neurology":
            return (
                iconName: "brain",
                description: "Treat diseases of the nervous system including the brain, spinal cord, peripheral nerves and neuromuscular junction."
            )
        case "Dermatology":
            return (
                iconName: "hand.raised.fill",
                description: "Specialize in skin, hair, and nail disorders: acne, eczema, psoriasis, skin cancers, and cosmetic dermatology."
            )
        case "Infectious Disease":
            return (
                iconName: "bacteria.fill",
                description: "Focus on infections caused by bacteria, viruses, fungi, and parasites; manage complex or resistant infections and travel medicine."
            )
        case "Obstetrics/Gynecology":
            return (
                iconName: "figure.dress.line.vertical.figure",
                description: "Provide comprehensive care for women's reproductive health: pregnancy, childbirth, gynecological disorders, and preventive screenings."
            )
        default:
            return (
                iconName: "star.fill",
                description: "Explore clinical cases in this specialty."
            )
        }
    }
}

// MARK: - Specialty Cinematic Background View
/// A view that displays a specialty-specific background image with a Ken Burns zoom effect.
/// Used for category cards and headers to provide visual context.
struct SpecialtyCinematicBackground: View {
    let specialty: String
    let color: Color
    
    // Normalized asset name generator
    // e.g., "Emergency Medicine" -> "img_emergency_medicine"
    private var assetName: String {
        let normalized = specialty.lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "_")
        return "img_\(normalized)"
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background Base
                Color(red: 0.05, green: 0.05, blue: 0.05) // Near black
                
                if UIImage(named: assetName) != nil {
                    // OPTION A: High-Fidelity Asset found
                    Image(assetName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                    // Tint the photo slightly with the specialty color for brand consistency
                        .overlay(color.opacity(0.2).blendMode(.overlay))
                    // Desaturate slightly for "Documentary" look
                        .saturation(0.8)
                } else {
                    // OPTION B: Procedural "Atmosphere" (Fallback)
                    // Not vector shapes. Instead, soft light leaks.
                    ZStack {
                        // Main Mood Light
                        RadialGradient(
                            colors: [color.opacity(0.5), color.opacity(0.1), .clear],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: geo.size.width * 1.2
                        )
                        .blendMode(.screen)
                        
                        // Secondary "Shadow" Light (creates depth)
                        RadialGradient(
                            colors: [.clear, .black.opacity(0.6)],
                            center: .center,
                            startRadius: 0,
                            endRadius: geo.size.width
                        )
                        
                        // Film Grain Texture (The Anti-Tech secret sauce)
                        // Adds organic noise so gradients don't look digital
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.05), .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .blendMode(.overlay)
                        
                        // Subtle Noise Pattern
                        Color.white.opacity(0.03)
                    }
                }
            }
        }
    }
}
