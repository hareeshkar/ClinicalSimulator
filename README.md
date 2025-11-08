# 🏥 Clinical Simulator

<div align="center">

![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)
![iOS](https://img.shields.io/badge/iOS-17.0+-blue.svg)
![SwiftUI](https://img.shields.io/badge/SwiftUI-5.0-blue.svg)
![Firebase](https://img.shields.io/badge/Firebase-AI-yellow.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

**An AI-powered clinical simulation platform for medical education**

[Features](#-features) • [Architecture](#-architecture) • [Getting Started](#-getting-started) • [Usage](#-usage) • [Documentation](#-documentation)

</div>

---

## 📋 Overview

**Clinical Simulator** is a cutting-edge iOS application designed to revolutionize medical education through interactive, AI-powered patient simulations. Built with SwiftUI and powered by Google's Gemini AI, the app provides realistic clinical scenarios that adapt to learner interactions, offering an immersive learning experience for medical students, residents, and healthcare professionals.

### 🎯 Key Highlights

- **Adaptive AI Patients**: Realistic patient interactions powered by Google's Gemini 2.5 Flash
- **Role-Based Learning**: Personalized difficulty and feedback based on learner level (MS1-MS4, Resident, Fellow, Attending)
- **Comprehensive Simulation**: Dynamic vital signs, diagnostic workups, and treatment responses
- **Intelligent Evaluation**: AI-driven performance assessment with detailed competency scoring
- **Rich Case Library**: Pre-built cases across multiple specialties with varying difficulty levels

---

## ✨ Features

### 🤖 AI-Powered Patient Simulation

- **Natural Conversation**: Stream-based AI responses create realistic patient-doctor dialogue
- **Dynamic Patient State**: Real-time vital sign changes based on clinical decisions
- **Proactive Responses**: AI patients react to treatments and interventions autonomously
- **Persona-Driven Behavior**: Each patient has unique personality, medical history, and presentation style

### 📊 Clinical Workflow Simulation

- **Multi-Tab Interface**:
  - **Conversation**: Natural dialogue with the AI patient
  - **Diagnostics**: Order tests, imaging, and procedures with realistic results
  - **Notes**: Document clinical reasoning and differential diagnoses
  - **Vitals Monitor**: Real-time patient monitoring with animated transitions

### 🎓 Educational Features

- **Differential Diagnosis Builder**: Structured approach to clinical reasoning with confidence scoring
- **Justification System**: Requires clinical rationale for every action taken
- **Competency Assessment**: Evaluates 4 core domains:
  - Differential Quality
  - Diagnostic Stewardship
  - Harm Avoidance
  - Prioritization & Timeliness

### 📈 Performance Analytics

- **Detailed Debriefing**: Comprehensive post-simulation review with learning points
- **Performance Dashboard**: Track progress across completed cases
- **Session History**: Review past simulations and decisions
- **Strengths & Feedback**: Personalized constructive feedback calibrated to learner level

### 🗂️ Case Management

- **Case Library**: Browse 100+ clinical scenarios across specialties
- **Smart Recommendations**: AI-curated cases based on your training level
- **Difficulty Filters**: Beginner, Intermediate, and Advanced cases
- **Specialty Categories**: Emergency Medicine, Cardiology, Internal Medicine, and more

---

## 🏗️ Architecture

### Technology Stack

```
┌─────────────────────────────────────────┐
│           SwiftUI + iOS 17+              │
├─────────────────────────────────────────┤
│  ViewModels (MVVM Architecture)         │
│  • ChatViewModel                         │
│  • SimulationViewModel                   │
│  • DiagnosticsViewModel                  │
│  • EvaluationViewModel                   │
├─────────────────────────────────────────┤
│  Services Layer                          │
│  • GeminiService (AI Integration)        │
│  • DataManager (Persistence)             │
├─────────────────────────────────────────┤
│  Data Layer (SwiftData)                  │
│  • PatientCase                           │
│  • StudentSession                        │
│  • ConversationMessage                   │
├─────────────────────────────────────────┤
│  External Services                       │
│  • Firebase AI (Gemini 2.5 Flash)        │
│  • Firebase Analytics                    │
└─────────────────────────────────────────┘
```

### Core Components

#### 🔹 Models

- **`PatientCase`**: SwiftData model storing complete case information including metadata, patient profile, and dynamic states
- **`StudentSession`**: Tracks learner progress, actions, differential diagnoses, and evaluation results
- **`EnhancedCaseDetail`**: Complex case structure with state machine for patient progression
- **`ConversationMessage`**: Chat messages with timestamp and sender information
- **`DifferentialItem`**: Structured differential diagnosis with confidence and rationale

#### 🔹 Services

- **`GeminiService`**:

  - Streaming patient response generation
  - Professional evaluation with rubric-based scoring
  - Dynamic case generation from templates
  - Persona-driven prompt engineering

- **`DataManager`**:
  - SwiftData integration
  - JSON case loading
  - Session management

#### 🔹 ViewModels

- **`ChatViewModel`**: Manages conversation flow and AI streaming
- **`SimulationViewModel`**: Controls patient state transitions and vital signs
- **`DiagnosticsViewModel`**: Handles test ordering and result revelation
- **`EvaluationViewModel`**: Generates and presents performance assessments
- **`NavigationManager`**: Global navigation state management

#### 🔹 Views

**Main Views**:

- `MainTabView`: Primary navigation container
- `DashboardView`: Personalized home screen with recommendations
- `SimulationView`: Full simulation experience with tab interface
- `CaseLibraryView`: Browse and filter available cases
- `ReportsView`: Performance analytics and history

**Simulation Views**:

- `ConversationTabView`: Chat interface with streaming responses
- `DiagnosticsTabView`: Diagnostic test ordering interface
- `NotesTabView`: Clinical notes and differential diagnosis builder
- `PatientMonitorView`: Real-time vitals display

**Evaluation Views**:

- `EvaluationView`: Competency scores and feedback
- `DebriefView`: Final diagnosis reveal and teaching points

---

## 🚀 Getting Started

### Prerequisites

- **macOS**: 14.0 (Sonoma) or later
- **Xcode**: 15.0 or later
- **iOS Device/Simulator**: iOS 17.0+
- **Firebase Account**: For AI and Analytics services

### Installation

1. **Clone the repository**

   ```bash
   git clone https://github.com/yourusername/ClinicalSimulator.git
   cd ClinicalSimulator
   ```

2. **Install dependencies**

   This project uses Swift Package Manager. Dependencies will be resolved automatically when you open the project in Xcode.

   **Required Packages**:

   - Firebase AI (Gemini Integration)
   - Firebase Analytics
   - Mantis (Image cropping)

3. **Configure Firebase**

   - Create a new Firebase project at [Firebase Console](https://console.firebase.google.com/)
   - Enable **Firebase AI** and **Firebase Analytics**
   - Download your `GoogleService-Info.plist`
   - Add it to the project root (it's gitignored for security)

4. **Add Google AI API Key**

   - Obtain a Gemini API key from [Google AI Studio](https://makersuite.google.com/app/apikey)
   - Add it to your Firebase project configuration

5. **Open in Xcode**

   ```bash
   open ClinicalSimulator.xcodeproj
   ```

6. **Build and Run**
   - Select your target device/simulator
   - Press `Cmd + R` to build and run

### First Launch

On first launch, the app will:

1. Initialize Firebase
2. Load sample cases from `SampleCases.json`
3. Create SwiftData database
4. Display the personalized dashboard

---

## 📱 Usage

### Starting a Simulation

1. **Browse Cases**: Navigate to the Case Library or use Dashboard recommendations
2. **Select a Case**: Tap on a case card to view the briefing
3. **Review Briefing**: Read the patient's chief complaint and initial presentation
4. **Begin Simulation**: Tap "Start Simulation" to enter the interactive environment

### During Simulation

#### 💬 Conversation Tab

- Type messages to interact with the AI patient
- Watch for streaming responses that appear word-by-word
- Patient responses adapt to their current clinical state

#### 🔬 Diagnostics Tab

- Search and order tests, imaging, or procedures
- Provide clinical justification for each order
- Results are revealed after ordering
- Critical interventions trigger immediate state changes

#### 📝 Notes Tab

- Document clinical reasoning
- Build differential diagnosis with:
  - Diagnosis name
  - Confidence level (0-100%)
  - Supporting rationale
- Save and edit throughout the simulation

#### 💓 Patient Monitor

- Swipe down from top to view vital signs
- Vitals update dynamically based on patient state
- Animated transitions show clinical changes

### Ending Simulation

1. Tap "End Simulation" when ready
2. Review your differential diagnosis
3. Receive AI-generated evaluation
4. Study the debrief with teaching points

---

## 🎓 User Roles & Personalization

The app adapts content and evaluation based on your selected role:

| Role                          | Experience Level | Evaluation Focus                        |
| ----------------------------- | ---------------- | --------------------------------------- |
| **Medical Student (MS1-MS2)** | Beginner         | Foundational knowledge, thoroughness    |
| **Medical Student (MS3-MS4)** | Intermediate     | Clinical reasoning, appropriate testing |
| **Intern/Resident**           | Advanced         | Efficiency, evidence-based practice     |
| **Fellow/Attending**          | Expert           | Leadership, complex decision-making     |

**Set your role in Profile View** to receive personalized:

- Case recommendations
- Evaluation rubrics
- AI patient communication style
- Feedback calibration

---

## 📂 Project Structure

```
ClinicalSimulator/
├── App/
│   ├── ClinicalSimulatorApp.swift      # App entry point
│   └── GoogleService-Info.plist        # Firebase config (gitignored)
│
├── Models/
│   ├── PatientCase.swift               # Case data model
│   ├── StudentSession.swift            # Session tracking
│   ├── EnhancedCaseDetail.swift        # Complex case structure
│   ├── ConversationMessage.swift       # Chat messages
│   ├── UserProfile.swift               # User settings
│   └── CaseTemplate.swift              # Case generation templates
│
├── Views/
│   ├── MainTabView.swift               # Main navigation
│   ├── DashboardView.swift             # Home screen
│   ├── SimulationView.swift            # Simulation container
│   ├── ConversationTabView.swift       # Chat interface
│   ├── DiagnosticsTabView.swift        # Test ordering
│   ├── NotesTabView.swift              # Clinical notes
│   ├── PatientMonitorView.swift        # Vitals display
│   ├── EvaluationView.swift            # Performance review
│   ├── DebriefView.swift               # Teaching points
│   ├── CaseLibraryView.swift           # Case browser
│   ├── CaseBriefingView.swift          # Case preview
│   └── ProfileView.swift               # User settings
│
├── ViewModels/
│   ├── ChatViewModel.swift             # Conversation logic
│   ├── SimulationViewModel.swift       # State management
│   ├── DiagnosticsViewModel.swift      # Test ordering logic
│   ├── EvaluationViewModel.swift       # Assessment generation
│   ├── NotesViewModel.swift            # Notes management
│   └── NavigationManager.swift         # Global navigation
│
├── Services/
│   ├── GeminiService.swift             # AI integration
│   └── DataManager.swift               # Data persistence
│
├── Shared/
│   ├── CaseRow.swift                   # Reusable case card
│   ├── ProfileAvatarView.swift         # User avatar
│   └── SpecialtyDetailsProvider.swift  # Specialty metadata
│
├── Resources/
│   ├── SampleCases.json                # Pre-built cases
│   └── Assets.xcassets/                # Images and colors
│
└── Utils/
    ├── AppNotifications.swift          # Notification helpers
    ├── ImageCropper.swift              # Image utilities
    └── KeyboardHelper.swift            # Keyboard management
```

---

## 🧪 Sample Cases

The app includes 100+ pre-built cases covering:

### Specialties

- 🚨 **Emergency Medicine**: Acute presentations requiring rapid diagnosis
- ❤️ **Cardiology**: Cardiovascular emergencies and chronic conditions
- 🫁 **Pulmonology**: Respiratory pathology and critical care
- 🧠 **Neurology**: Neurological emergencies and chronic diseases
- 🩺 **Internal Medicine**: Complex multi-system presentations
- 🏥 **Critical Care**: ICU-level management scenarios

### Difficulty Levels

- **Beginner**: Clear presentations, limited differential
- **Intermediate**: Moderate complexity, multiple possibilities
- **Advanced**: Complex presentations, rare diagnoses, time-critical

### Example Case: Massive Pulmonary Embolism

```json
{
  "metadata": {
    "caseId": "EMED-RAND-731",
    "title": "Pulmonary Embolism",
    "specialty": "Emergency Medicine",
    "difficulty": "Advanced",
    "recommendedForLevels": ["MS4", "Resident", "Fellow"]
  },
  "patientProfile": {
    "name": "Brenda Thompson",
    "age": "62 years old",
    "gender": "Female"
  },
  "initialPresentation": {
    "chiefComplaint": "Acute onset pleuritic chest pain and shortness of breath",
    "vitals": {
      "heartRate": 128,
      "respiratoryRate": 28,
      "bloodPressure": "92/58 mmHg",
      "oxygenSaturation": 89
    }
  }
}
```

---

## 🔧 Configuration

### Firebase Setup

Ensure your `GoogleService-Info.plist` includes:

```xml
<key>API_KEY</key>
<string>YOUR_FIREBASE_API_KEY</string>
<key>PROJECT_ID</key>
<string>YOUR_PROJECT_ID</string>
```

### AI Model Configuration

The app uses **Gemini 2.5 Flash** for optimal performance:

```swift
// In GeminiService.swift
private let model = FirebaseAI.firebaseAI(backend: .googleAI())
    .generativeModel(modelName: "gemini-2.5-flash")
```

---

## 🎨 UI/UX Features

### Design Principles

- **Clean & Professional**: Medical-grade interface design
- **Intuitive Navigation**: Tab-based simulation flow
- **Smooth Animations**: Spring-based transitions
- **Accessibility**: VoiceOver support, Dynamic Type
- **Dark Mode**: Full dark mode support

### Key UI Components

- **Streaming Chat**: Word-by-word AI responses with typing indicator
- **Animated Vitals**: Smooth transitions for vital sign changes
- **Category Cards**: Visual specialty organization
- **Performance Graphs**: Visual performance tracking
- **Glassmorphism**: Modern frosted glass effects

---

## 📊 Data Persistence

### SwiftData Schema

```swift
@Model
class PatientCase {
    @Attribute(.unique) var caseId: String
    var title: String
    var specialty: String
    var difficulty: String
    var chiefComplaint: String
    var fullCaseJSON: String
    var recommendedForLevels: [String]
}

@Model
class StudentSession {
    @Attribute(.unique) var sessionId: UUID
    var caseId: String
    var isCompleted: Bool
    var score: Double?
    var performedActions: [PerformedAction]
    var differentialDiagnosis: [DifferentialItem]
    var notes: String

    @Relationship(deleteRule: .cascade)
    var messages: [ConversationMessage]
}
```

### Database Structure

- **Automatic persistence** via SwiftData
- **iCloud sync ready** (can be enabled)
- **Cascading deletes** for related data
- **Query predicates** for efficient filtering

---

## 🤖 AI Integration

### Gemini Service Features

#### 1. **Patient Response Generation**

```swift
func generatePatientResponseStream(
    patientCase: PatientCase,
    session: StudentSession,
    userRole: String
) -> AsyncThrowingStream<String, Error>
```

- Streams responses for real-time UI updates
- Adapts communication style to learner role
- Maintains conversation context and patient state

#### 2. **Performance Evaluation**

```swift
func generateEvaluation(
    caseDetail: EnhancedCaseDetail,
    session: StudentSession,
    userRole: String
) async throws -> ProfessionalEvaluationResult
```

- 4-domain competency scoring
- Calibrated feedback based on training level
- Structured debrief with teaching points

#### 3. **Case Generation**

```swift
func generateNewCase(
    from template: CaseTemplate
) async throws -> String
```

- Creates new cases from templates
- Ensures medical accuracy
- Maintains internal consistency

### Prompt Engineering

The app uses sophisticated prompt engineering:

- **Persona Blocks**: Define patient characteristics
- **Memory System**: Chronological event logs
- **Role Adaptation**: Dynamic difficulty calibration
- **Rubric-Based**: Structured evaluation criteria

---

## 🔒 Security & Privacy

### Data Protection

- ✅ **Local-First**: All patient data stored locally
- ✅ **No PII Storage**: Fictional patient cases only
- ✅ **Gitignored Secrets**: API keys excluded from version control
- ✅ **Firebase Security**: Authentication and encryption ready

### Excluded Files

```gitignore
GoogleService-Info.plist
.env
*.key
*.pem
Secrets.xcconfig
```

---

## 🧪 Testing

### Manual Testing Checklist

- [ ] Start new simulation
- [ ] Send chat messages with streaming responses
- [ ] Order diagnostic tests with justifications
- [ ] Build differential diagnosis
- [ ] Verify vital sign updates
- [ ] Complete simulation and view evaluation
- [ ] Check performance dashboard
- [ ] Test role-based recommendations

### Known Issues

- Performance may vary based on network speed (AI streaming)
- Some animations may stutter on older devices
- First AI response may have slight delay (cold start)

---

## 🛣️ Roadmap

### Planned Features

- [ ] **Multi-Patient Rounds**: Manage multiple patients simultaneously
- [ ] **Team Collaboration**: Multi-user simulations
- [ ] **Voice Input**: Speak to patients naturally
- [ ] **Advanced Analytics**: Machine learning insights
- [ ] **Custom Cases**: User-generated content
- [ ] **Offline Mode**: Local AI model fallback
- [ ] **Export Reports**: PDF performance summaries
- [ ] **Gamification**: Achievements and leaderboards

---

## 🤝 Contributing

We welcome contributions! Here's how you can help:

1. **Fork the repository**
2. **Create a feature branch** (`git checkout -b feature/AmazingFeature`)
3. **Commit your changes** (`git commit -m 'Add some AmazingFeature'`)
4. **Push to the branch** (`git push origin feature/AmazingFeature`)
5. **Open a Pull Request**

### Contribution Guidelines

- Follow Swift style guide
- Write descriptive commit messages
- Update documentation for new features
- Test on multiple devices
- Ensure no API keys are committed

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

```
MIT License

Copyright (c) 2025 Clinical Simulator Team

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
```

---

## 👥 Authors & Acknowledgments

### Development Team

- **Lead Developer**: [Your Name]
- **UI/UX Design**: Clinical Simulator Team
- **Medical Content**: Medical education consultants

### Special Thanks

- **Google AI**: For Gemini 2.5 Flash API
- **Firebase Team**: For backend services
- **SwiftUI Community**: For inspiration and support
- **Medical Educators**: For feedback and guidance

---

## 📞 Support & Contact

### Get Help

- 📧 **Email**: support@clinicalsimulator.com
- 💬 **Discord**: [Join our community](https://discord.gg/clinicalsimulator)
- 🐛 **Bug Reports**: [GitHub Issues](https://github.com/yourusername/ClinicalSimulator/issues)
- 📖 **Documentation**: [Wiki](https://github.com/yourusername/ClinicalSimulator/wiki)

### Social Media

- 🐦 **Twitter**: [@ClinicalSim](https://twitter.com/clinicalsim)
- 💼 **LinkedIn**: [Clinical Simulator](https://linkedin.com/company/clinicalsimulator)

---

## 📚 Additional Resources

### Medical Education

- [AAMC Clinical Skills Development](https://www.aamc.org/)
- [MedEdPortal Case Collection](https://www.mededportal.org/)
- [NEJM Clinical Cases](https://www.nejm.org/)

### Development Resources

- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui/)
- [SwiftData Guide](https://developer.apple.com/documentation/swiftdata)
- [Firebase AI Documentation](https://firebase.google.com/docs/genai-sdk)
- [Gemini API Reference](https://ai.google.dev/docs)

---

<div align="center">

### ⭐ Star this repository if you find it helpful!

**Built with ❤️ for medical education**

[Report Bug](https://github.com/yourusername/ClinicalSimulator/issues) • [Request Feature](https://github.com/yourusername/ClinicalSimulator/issues) • [View Demo](https://youtu.be/demo)

</div>
