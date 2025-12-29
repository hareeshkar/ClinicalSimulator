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

- **Clinical-Grade UI**: Redesigned "Clinical Journal" aesthetic with editorial serif typography and matte medical-device visuals
- **Adaptive AI Patients**: Realistic patient interactions powered by Google's Gemini 2.5 Flash with streaming responses
- **Multi-Language Support**: Full simulation experience in English, Tamil (தமிழ்), and Sinhala (සිංහල) with culturally authentic medical terminology
- **Role-Based Learning**: Personalized difficulty and feedback based on learner level (MS1-MS4, Intern, Resident, Fellow, Attending, Consultant, EMT, Pharmacist, Nurse, PA Student, NP Student, Physiotherapy Student, Nursing Student, Respiratory Therapist)
- **Comprehensive Simulation**: Dynamic vital signs with physics-based drift, diagnostic workups, and treatment responses
- **Resilient Evaluation Engine**: Multi-state evaluation system (evaluating/retry/failed) with intelligent API error classification
- **Intelligent Evaluation**: AI-driven performance assessment with detailed competency scoring and age-appropriate feedback
- **Rich Case Library**: Pre-built cases across 12+ medical specialties with varying difficulty levels with atomic upsert synchronization
- **Secure Authentication**: Email-based user accounts with password hashing and profile customization
- **Immersive UI/UX**: Custom liquid-physics score indicator, refined haptic feedback patterns, and specialty-themed visual design

---

## ✨ Features

### 🎨 Clinical-Grade UI Redesign

- **Clinical Journal Aesthetic**: Editorial serif typography creating an authentic clinical environment
- **Matte Medical-Device Visuals**: Professional, minimalist interface design resembling actual medical equipment
- **ClinicalMonitorWidget Integration**: Unified clinical context display across briefing and simulation views
- **Custom Score Indicator**: Liquid-physics-based score visualization with smooth, organic animations
- **Tab Switcher Stability**: Fixed layout instability by anchoring matched geometry effects to background modifiers
- **Refined Haptic Patterns**: Enhanced tactile feedback simulating biometric pulses and clinical alerts

### 🤖 AI-Powered Patient Simulation

- **Natural Conversation**: Stream-based AI responses create realistic patient-doctor dialogue
- **Dynamic Patient State**: Real-time vital sign changes based on clinical decisions
- **Proactive Responses**: AI patients react to treatments and interventions autonomously
- **Persona-Driven Behavior**: Each patient has unique personality, medical history, and presentation style
- **Clinical Priority Sliding Window**: Optimized context management maintaining 100 most relevant messages without losing medical history

### 🧠 AI Preceptor (Consult Attending)

- **Real-Time Socratic Guidance**: Floating hint button provides instant access to attending physician insights
- **Progressive Hint System**: AI adapts hint complexity based on learner level and session progress
- **Contextual Coaching**: Hints consider conversation history, ordered tests, and clinical decisions
- **Alternative Perspectives**: "Get Another Hint" offers different approaches to the same clinical challenge
- **Distinct Visual Styling**: Attending messages appear in dedicated overlay panel with professional branding

### 📊 Clinical Workflow Simulation

- **Multi-Tab Interface**:
  - **Conversation**: Natural dialogue with the AI patient and floating hint access
  - **Diagnostics**: Order tests, imaging, and procedures with realistic results
  - **Notes**: Document clinical reasoning and differential diagnoses
  - **Vitals Monitor**: Real-time patient monitoring with animated transitions

### 🫀 The Living Patient (Physics Engine)

- **Realistic Vital Sign Drift**: Natural physiological variation and baseline fluctuations
- **Clinical State Jitter**: Subtle vital sign changes reflecting patient condition
- **Dynamic Response Modeling**: Vital signs react authentically to interventions and time
- **Physiological Accuracy**: Evidence-based vital sign ranges and transitions
- **Animated Transitions**: Smooth numeric content transitions with visual feedback
- **Real-Time Monitoring**: Continuous vital sign updates during active simulations

### 🌍 Multi-Language Clinical Education

- **Native Language Support**: Choose between English, Tamil (தமிழ்), or Sinhala (සිංහල)
- **Culturally Authentic Medical Terminology**: AI uses proper medical vocabulary as spoken by native healthcare professionals
- **Localized Patient Interactions**: Patients respond in the learner's native language with appropriate colloquialisms
- **Language-Aware Feedback**: Evaluations and hints delivered in selected language while preserving medical terminology
- **Cultural Context Integration**: AI may weave culturally relevant expressions and healthcare contexts naturally into conversations

### 👤 User Profiles & Authentication

- **Secure Email-Based Authentication**: Create accounts with email and password (SHA-256 hashed)
- **Persistent Sessions**: Automatic login with secure credential storage
- **Comprehensive Profiles**: Customize full name, role/title, gender (Male, Female, Non-Binary, Prefer Not to Say), date of birth, and native language
- **Profile Images**: Upload and crop custom profile pictures with real-time sync across views
- **Birthday Celebrations**: Animated rainbow avatar border on your special day
- **Privacy First**: All data stored locally with SwiftData

### 🎨 Polished UI/UX Experience

- **Haptic Feedback**: Tactile responses for button presses, successful actions, and hint delivery
- **Smooth Animations**: Spring-based transitions, fade effects, and scale animations throughout the app
- **Specialty-Themed Colors**: Each medical specialty has distinctive color coding (Cardiology: pink, Emergency: red, Neurology: blue, etc.)
- **Adaptive Theming**: Support for light and dark modes with material backgrounds
- **Animated Statistics**: Number counters, progress bars, and score displays with smooth transitions
- **Professional Typography**: Clear hierarchy with SF Symbols integration

### 🎓 Educational Features

- **Differential Diagnosis Builder**: Structured approach to clinical reasoning with confidence scoring
- **Justification System**: Requires clinical rationale for every action taken
- **Competency Assessment**: Evaluates 4 core domains:
  - Differential Quality
  - Diagnostic Stewardship
  - Harm Avoidance
  - Prioritization & Timeliness
- **Multi-State Evaluation Engine**: Handles evaluating, retry, and failed states with intelligent error recovery
- **Intelligent Error Classification**: Distinguishes between transient API failures and critical errors
- **User-Facing Recovery Paths**: Clear guidance for users when evaluation encounters issues

### 📈 Performance Analytics

- **Detailed Debriefing**: Comprehensive post-simulation review with learning points
- **Performance Dashboard**: Track progress across completed cases
- **Session History**: Review past simulations and decisions
- **Strengths & Feedback**: Personalized constructive feedback calibrated to learner level

### 🗂️ Case Management

- **Extensive Case Library**: Browse 20+ clinical scenarios across 12+ medical specialties
- **Smart Recommendations**: AI-curated cases based on your training level and role
- **Difficulty Filters**: Beginner, Intermediate, and Advanced cases with clear indicators
- **Specialty Categories**:
  - 🚨 **Emergency Medicine**: Acute presentations requiring rapid diagnosis
  - ❤️ **Cardiology**: Cardiovascular emergencies and chronic conditions
  - 🫁 **Pulmonology**: Respiratory pathology and critical care
  - 🧠 **Neurology**: Neurological emergencies and chronic diseases
  - 🩺 **Internal Medicine**: Complex multi-system presentations
  - 👶 **Pediatrics**: Pediatric-specific cases across age groups
  - 🦴 **Orthopedics**: Musculoskeletal injuries and conditions
  - 🦠 **Infectious Disease**: Infectious processes and antimicrobial stewardship
  - 🫀 **Endocrinology**: Hormonal and metabolic disorders
  - 🔪 **Surgery**: Surgical emergencies and perioperative care
  - 👩‍⚕️ **Obstetrics/Gynecology**: OB/GYN presentations and emergencies
  - 🧠 **Psychiatry**: Psychiatric emergencies and mental health crises
  - 🍽️ **Gastroenterology**: Digestive system disorders
  - 💧 **Nephrology**: Renal and electrolyte disorders
- **Specialty-Specific Theming**: Each specialty has unique colors, icons, and descriptions

### 💾 Robust Data Persistence

- **Atomic Upsert Synchronization**: Supports large case library updates while preserving user session history
- **ScenePhase Monitoring**: Automatic session saving when app backgrounds or terminates
- **Crash Recovery**: Session state preservation prevents data loss
- **SwiftData Integration**: Efficient local database with automatic migrations and relationships
- **Real-Time Sync**: Continuous session updates during active simulations
- **User-Scoped Data**: All sessions and progress linked to individual user accounts
- **Profile Image Storage**: Local file system storage with UUID-based filenames
- **Multi-Case Library Management**: Seamless updates to extensive case collections without data loss

---

## 🏗️ Architecture

### Recent Enhancements (Clinical Grade Refactor)

This release introduces a comprehensive redesign and architectural improvements:

**UI/UX Improvements**:

- Migrated to "Clinical Journal" aesthetic with editorial serif typography
- Unified `ClinicalMonitorWidget` component across briefing and simulation views
- Implemented custom liquid-physics score indicator for performance visualization
- Fixed tab switcher layout instability through proper geometry anchoring
- Enhanced haptic feedback with biometric pulse and clinical alert patterns

**Logic & Data Enhancements**:

- Implemented robust multi-state evaluation engine with error classification
- Added atomic upsert synchronization for large case library updates
- Improved API resilience with intelligent error recovery paths
- Enhanced session persistence across app lifecycle events

### Technology Stack

```
┌─────────────────────────────────────────┐
│           SwiftUI + iOS 17+              │
├─────────────────────────────────────────┤
│  ViewModels (MVVM Architecture)         │
│  • ChatViewModel (AI Preceptor)         │
│  • SimulationViewModel (Living Patient) │
│  • DiagnosticsViewModel                  │
│  • EvaluationViewModel                   │
├─────────────────────────────────────────┤
│  Services Layer                          │
│  • GeminiService (Priority Window)       │
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

  - **Clinical Priority Sliding Window**: Maintains 100-message context window for optimal AI performance
  - Streaming patient response generation
  - Professional evaluation with rubric-based scoring and error resilience
  - Dynamic case generation from templates
  - Persona-driven prompt engineering
  - **AI Preceptor Hints**: Socratic guidance with progressive difficulty and contextual awareness
  - **Multi-State Evaluation**: Handles API errors gracefully with retry logic and clear user feedback

- **`DataManager`**:
  - SwiftData integration with scenePhase monitoring
  - Atomic upsert operations for large-scale case library updates
  - JSON case loading with preservation of existing session data
  - Session management with crash recovery
  - Intelligent synchronization preventing data loss during bulk updates

#### 🔹 ViewModels

- **`ChatViewModel`**: Manages conversation flow, AI streaming, and preceptor hints
- **`SimulationViewModel`**: Controls patient state transitions, vital signs, and physics engine
- **`DiagnosticsViewModel`**: Handles test ordering and result revelation
- **`EvaluationViewModel`**:
  - Multi-state evaluation management (idle, evaluating, success, error)
  - Graceful error handling with user-facing recovery options
  - Persistence of evaluation results for offline access
  - Intelligent retry logic for transient API failures
- **`NotesViewModel`**: Clinical notes management
- **`NavigationManager`**: Global navigation state management with evaluation flow integration

#### 🔹 Views

**Main Views**:

- `MainTabView`: Primary navigation container
- `DashboardView`: Personalized home screen with recommendations
- `SimulationView`: Full simulation experience with tab interface
- `CaseLibraryView`: Browse and filter available cases
- `ReportsView`: Performance analytics and history

**Simulation Views**:

- `ConversationTabView`: Chat interface with streaming responses and floating hint panel
- `DiagnosticsTabView`: Diagnostic test ordering interface
- `NotesTabView`: Clinical notes and differential diagnosis builder
- `PatientMonitorView`: Real-time vitals display with physics-based animations

**Evaluation Views**:

- `EvaluationView`: Competency scores and feedback
- `DebriefView`: Final diagnosis reveal and teaching points

---

## 🚀 Getting Started

### Prerequisites

- **macOS**: 14.0 (Sonoma) or later
- **Xcode**: 15.0 or later
- **iOS Device/Simulator**: iOS 17.0+ (optimized for iPhone)
- **Firebase Account**: For Gemini AI integration
- **Google AI API Key**: Required for AI-powered simulations

### Installation

1. **Clone the repository**

   ```bash
   git clone https://github.com/hareeshkar/ClinicalSimulator.git
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

1. Initialize Firebase and Gemini AI
2. Display the Sign Up screen
3. Create your secure user account
4. Load sample cases from `SampleCases.json`
5. Initialize SwiftData database with user profile
6. Display the personalized dashboard

### Creating Your Account

1. **Sign Up**: Enter your full name, email, and password
2. **Customize Profile**: Set your role (e.g., "Medical Student (MS3)"), gender, date of birth, and native language
3. **Upload Avatar** (Optional): Add a profile picture with built-in cropping
4. **Start Learning**: Browse recommended cases or explore the case library

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
- Watch for **streaming responses** that appear word-by-word in real-time
- Patient responses adapt to their current clinical state and your native language
- **Multi-Language Conversations**: Patients communicate in English, Tamil, or Sinhala based on your profile settings
- **Access AI Preceptor**: Tap the floating "Hint" button (bottom-right) for real-time attending physician guidance
- **Progressive Hints**: Receive Socratic questions and clinical insights tailored to your progress
- **Alternative Perspectives**: Use "Get Another Hint" for different approaches to the same challenge
- **Haptic Feedback**: Feel tactile responses when sending messages and receiving hints
- **Smooth Animations**: Message bubbles appear with scale and fade transitions

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

- Swipe down from top to view vital signs in real-time
- Vitals update dynamically based on patient state and interventions
- **Living Patient Physics**: Observe realistic vital sign drift and natural physiological variation
- **Animated Numeric Transitions**: Numbers smoothly morph using SwiftUI's contentTransition API
- **Color-Coded Values**: Critical values highlighted in red, normal in green
- **Specialty Theming**: Monitor styling adapts to case specialty colors

### Ending Simulation

1. Tap "End Simulation" when ready
2. Review your differential diagnosis
3. Receive AI-generated evaluation
4. Study the debrief with teaching points

---

## 🌐 Multi-Language Clinical Education

Clinical Simulator offers a truly immersive multi-language experience, allowing learners to practice medicine in their native language with culturally authentic medical terminology.

### Supported Languages

- **English**: Standard medical English with international terminology
- **Tamil (தமிழ்)**: Full Tamil support with proper medical vocabulary
- **Sinhala (සිංහල)**: Complete Sinhala integration with native healthcare terminology

### Language Features

#### **Native Medical Terminology**

The AI uses authentic medical terms as spoken by native healthcare professionals:

- **Tamil**: Uses proper Tamil medical vocabulary (e.g., "இதய வலி" for chest pain, "மூச்சுத் திணறல்" for shortness of breath)
- **Sinhala**: Uses proper Sinhala medical vocabulary (e.g., "හුස්ම ගැනීමේ අපහසුතාව" for breathing difficulty)

#### **Culturally Authentic Conversations**

- Patients respond naturally using colloquialisms and expressions from their language
- Cultural references and healthcare contexts are woven naturally into conversations
- AI may reference relevant traditional medicine practices when culturally appropriate

#### **Language-Aware Evaluation**

- Feedback delivered in your selected language
- Medical terminology preserved in English where appropriate
- Age and cultural background considered in feedback tone and style

#### **How to Set Your Language**

1. Navigate to **Profile View**
2. Tap **Edit** in the top-right corner
3. Select your preferred language from the **Native Language** dropdown
4. Tap **Save Changes**
5. All future simulations will use your selected language

### Example Interactions

**English Patient Response:**

> "Doctor, I've been having this severe chest pain that started about 2 hours ago. It feels like someone is squeezing my chest."

**Tamil Patient Response:**

> "டாக்டர், எனக்கு இரண்டு மணி நேரத்திற்கு முன்பு மார்பு வலி ஆரம்பமானது. யாரோ என் மார்பை அழுத்துவது போல் உள்ளது."

**Sinhala Patient Response:**

> "ඩොක්ටර්, මට පැය දෙකකට පමණ පෙර ආරම්භ වූ දරුණු පපුවේ වේදනාවක් තියෙනවා. යමෙකු මගේ පපුව මිරිකනවා වගේ දැනෙනවා."

---

## 🧠 AI Preceptor (Consult Attending)

The AI Preceptor provides real-time guidance from a virtual attending physician during active simulations, helping learners develop clinical reasoning skills through Socratic teaching.

### How to Access

- **Floating Hint Button**: Look for the circular "Hint" button in the bottom-right corner of the conversation tab
- **One-Tap Access**: Tap to instantly receive attending physician insights
- **Non-Intrusive**: Hints appear in a dedicated overlay panel without interrupting the conversation flow

### Hint Types

#### **Progressive Difficulty Levels**

- **Level 1 (Subtle)**: Socratic questions pointing to missed patterns
- **Level 2 (Specific)**: Directed clinical reasoning with red flags
- **Level 3 (Direct)**: Strong guidance with narrowed differentials

#### **Contextual Awareness**

- **Conversation History**: Hints consider your dialogue with the patient
- **Ordered Tests**: AI knows what diagnostics you've requested
- **Clinical Actions**: Previous interventions influence guidance
- **Same Section Hints**: When stuck, "Get Another Hint" provides alternative perspectives

### Features

- **Real-Time Coaching**: Immediate feedback on clinical decisions
- **Educational Focus**: Emphasis on teaching rather than giving answers
- **Personalized Guidance**: Adapted to your training level and progress
- **Multiple Perspectives**: Alternative approaches to the same clinical challenge
- **Professional Styling**: Distinct visual design for attending messages

### Example Interactions

**Student Question**: "The patient has chest pain and shortness of breath. Should I order a chest X-ray?"

**Level 1 Hint**: "Looking at the vital signs again, what do you notice about the oxygen saturation relative to the respiratory rate?"

**Level 2 Hint**: "This combination of symptoms suggests a cardiopulmonary process. What conditions cause both chest pain and respiratory distress?"

**Level 3 Hint**: "Consider pulmonary embolism or pneumothorax. Which fits better with this patient's risk factors?"

---

## 👤 User Authentication & Profiles

Clinical Simulator features a comprehensive user authentication system with rich profile customization, ensuring a personalized and secure learning experience.

### Authentication System

#### **Secure Sign Up**

- Email-based account creation
- SHA-256 password hashing for security
- Duplicate email prevention
- Validation for all input fields

#### **Persistent Login**

- Automatic session restoration on app launch
- Secure credential storage using AppStorage
- Email-based user lookup via SwiftData

#### **Session Management**

- One-tap logout functionality
- All user data scoped to individual accounts
- Session history and progress tracked per user

### Profile Customization

#### **Personal Information**

- **Full Name**: Display name shown throughout the app
- **Email Address**: Unique login identifier
- **Role/Title**: Select from 15+ medical professional roles (MS1-MS4, Resident, Attending, etc.)
- **Gender**: Inclusive options (Male, Female, Non-Binary, Prefer Not to Say)
- **Date of Birth**: Optional for age-appropriate feedback and birthday celebrations
- **Native Language**: Choose English, Tamil (தமிழ்), or Sinhala (සිංහල)

#### **Profile Images**

- Upload custom profile pictures
- Built-in image cropping with Mantis framework
- Real-time avatar sync across all views
- UUID-based secure file storage
- Automatic fallback to initials if no image

#### **Birthday Celebrations** 🎉

When it's your birthday, enjoy special touches:

- Animated rainbow border around your profile avatar
- Special birthday greeting on Dashboard
- Celebratory animations throughout the app

### Profile Settings

Access your profile anytime from the **Profile** tab:

1. **View Mode**: See your current settings and stats
2. **Edit Mode**: Tap "Edit" to modify any field
3. **Save Changes**: All updates sync instantly with SwiftData
4. **Reset Options**: Clear simulation history or reload sample cases

### Privacy & Data

- ✅ **All data stored locally**: No cloud storage required
- ✅ **No data sharing**: Your information stays on your device
- ✅ **Secure passwords**: Industry-standard SHA-256 hashing
- ✅ **Profile images**: Stored in app's Documents directory with secure filenames

---

## 🎓 User Roles & Personalization

The app adapts content and evaluation based on your selected role:

| Role                          | Experience Level | Evaluation Focus                        |
| ----------------------------- | ---------------- | --------------------------------------- |
| **Medical Student (MS1-MS2)** | Beginner         | Foundational knowledge, thoroughness    |
| **Medical Student (MS3-MS4)** | Intermediate     | Clinical reasoning, appropriate testing |
| **Intern/Resident**           | Advanced         | Efficiency, evidence-based practice     |
| **Fellow/Attending**          | Expert           | Leadership, complex decision-making     |
| **EMT**                       | Beginner         | Basic assessment, stabilization         |
| **Pharmacist**                | Intermediate     | Medication management, interactions     |
| **Nurse**                     | Intermediate     | Patient care, monitoring                |
| **PA Student/NP Student**     | Intermediate     | Clinical skills, diagnosis              |
| **Physiotherapy Student**     | Beginner         | Rehabilitation, mobility                |
| **Nursing Student**           | Beginner         | Basic care, assessment                  |
| **Respiratory Therapist**     | Intermediate     | Ventilation, oxygenation                |

**Set your preferences in Profile View** to receive personalized:

- **Case Recommendations**: Tailored to your training level and role
- **Evaluation Rubrics**: Adapted difficulty and scoring criteria
- **AI Patient Communication**: Response style matches your experience level
- **Feedback Calibration**: Age-appropriate and culturally sensitive feedback
- **Language Selection**: Choose English, Tamil (தமிழ்), or Sinhala (සිංහල) for full immersion
- **Profile Customization**: Update name, role, gender, date of birth, and avatar image

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
│   ├── User.swift                      # User authentication & profile
│   ├── UserProfile.swift               # Profile roles & settings
│   ├── CaseTemplate.swift              # Case generation templates
│   └── EvaluationResult.swift          # Assessment data model
│
├── Views/
│   ├── MainTabView.swift               # Main navigation
│   ├── DashboardView.swift             # Personalized home screen with stats
│   ├── SimulationView.swift            # Simulation container with tabs
│   ├── ConversationTabView.swift       # Chat interface with hint panel
│   ├── DiagnosticsTabView.swift        # Test ordering with justifications
│   ├── NotesTabView.swift              # Clinical notes & differentials
│   ├── PatientMonitorView.swift        # Real-time vitals with animations
│   ├── EvaluationView.swift            # AI-powered performance review
│   ├── DebriefView.swift               # Teaching points & diagnosis reveal
│   ├── CaseLibraryView.swift           # Filterable case browser
│   ├── CaseBriefingView.swift          # Detailed case preview
│   ├── ProfileView.swift               # User settings & profile editor
│   ├── ReportsView.swift               # Session history & analytics
│   ├── AnimatedAvatarView.swift        # Birthday celebration avatar
│   ├── CategoryCardView.swift          # Specialty category cards
│   ├── CaseListItemView.swift          # Individual case list item
│   └── Auth/
│       ├── LoginView.swift             # Email/password login
│       ├── SignUpView.swift            # User registration
│       └── AuthHeaderView.swift        # Auth screen branding
│
├── ViewModels/
│   ├── ChatViewModel.swift             # Conversation logic + AI Preceptor
│   ├── SimulationViewModel.swift       # State management + Living Patient physics
│   ├── DiagnosticsViewModel.swift      # Test ordering logic
│   ├── EvaluationViewModel.swift       # Assessment generation
│   ├── NotesViewModel.swift            # Notes management
│   └── NavigationManager.swift         # Global navigation
│
├── Services/
│   ├── GeminiService.swift             # AI integration + Priority Window
│   ├── DataManager.swift               # Data persistence + case loading
│   └── Auth/
│       └── AuthService.swift           # User authentication & session management
│
├── Shared/
│   ├── CaseRow.swift                   # Reusable case card component
│   ├── ProfileAvatarView.swift         # User avatar with image loading
│   └── SpecialtyDetailsProvider.swift  # Specialty colors, icons & descriptions
│
├── Resources/
│   ├── SampleCases.json                # Pre-built cases
│   └── Assets.xcassets/                # Images and colors
│
└── Utils/
    ├── AppNotifications.swift          # NotificationCenter extensions
    ├── ImageCropper.swift              # Profile image cropping utility
    └── KeyboardHelper.swift            # Keyboard dismissal helpers
```

---

## 🧪 Sample Cases

The app includes 20+ pre-built cases covering:

### Specialties

- 🚨 **Emergency Medicine**: Acute presentations requiring rapid diagnosis (e.g., Pulmonary Embolism, DKA, Ischemic Stroke, Septic Shock)
- ❤️ **Cardiology**: Cardiovascular emergencies and chronic conditions (e.g., Acute MI, Aortic Dissection, Hypertensive Emergency, Pericardial Tamponade)
- 🫁 **Pulmonology**: Respiratory pathology and critical care (e.g., COPD Exacerbation, Spontaneous Pneumothorax, Flash Pulmonary Edema, PCP in HIV)
- 🧠 **Neurology**: Neurological emergencies and chronic diseases (e.g., Status Epilepticus, Meningitis, Guillain-Barré Syndrome, Stroke with LVO)
- 🩺 **Internal Medicine**: Complex multi-system presentations (e.g., Community-Acquired Pneumonia, Rhabdomyolysis and AKI, Upper GI Bleed)
- 👶 **Pediatrics**: Pediatric-specific cases (e.g., Febrile Seizure, Kawasaki Disease, Intussusception, Bronchiolitis, New Onset Type 1 Diabetes)
- 🏥 **Critical Care**: ICU-level management scenarios (e.g., Thyroid Storm, Myxedema Coma)
- 🦴 **Orthopedics**: Musculoskeletal injuries (e.g., Ankle Fracture, Open Tibial Fracture, Elderly Hip Fracture)
- 🦠 **Infectious Disease**: Infectious processes (e.g., Infective Endocarditis)
- 🫀 **Endocrinology**: Endocrine disorders (e.g., Gestational Diabetes)
- 🔪 **Surgery**: Surgical emergencies (e.g., Perforated Peptic Ulcer, Necrotizing Fasciitis)
- 👩‍⚕️ **Obstetrics/Gynecology**: Obstetric and gynecologic cases (e.g., Preeclampsia, Pelvic Inflammatory Disease, Ruptured Ectopic Pregnancy)
- 🧠 **Psychiatry**: Psychiatric emergencies (e.g., Acute Manic Episode, Serotonin Syndrome, Opioid Overdose)

### Difficulty Levels

- **Beginner**: Clear presentations, limited differential (e.g., Febrile Seizure, Community-Acquired Pneumonia)
- **Intermediate**: Moderate complexity, multiple possibilities (e.g., DKA, Kawasaki Disease, COPD Exacerbation)
- **Advanced**: Complex presentations, rare diagnoses, time-critical (e.g., Massive PE, Ischemic Stroke, Thyroid Storm)

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

- ✅ **Local-First Architecture**: All user data, sessions, and patient cases stored locally using SwiftData
- ✅ **Secure Authentication**: SHA-256 password hashing with salt
- ✅ **No PII Storage**: Fictional patient cases only—no real patient data
- ✅ **Gitignored Secrets**: API keys and configuration files excluded from version control
- ✅ **Firebase Security**: Secure API communication with Gemini AI
- ✅ **User Data Isolation**: All sessions and progress scoped to individual user accounts
- ✅ **Profile Image Security**: UUID-based filenames prevent unauthorized access

### Authentication Security

- **Password Requirements**: Enforced minimum complexity
- **Email Validation**: Prevents invalid email formats
- **Duplicate Prevention**: Email uniqueness enforced at database level
- **Secure Storage**: User credentials never logged or transmitted insecurely

### Excluded Files

```gitignore
GoogleService-Info.plist
.env
*.key
*.pem
Secrets.xcconfig
*.xcuserstate
UserInterfaceState.xcuserstate
```

### Firebase Integration

The app uses Firebase AI (Gemini) for:

- ✅ Patient conversation generation
- ✅ Clinical evaluation and feedback
- ✅ AI Preceptor hints and guidance
- ✅ Case generation from templates

**Note**: Firebase Analytics is configured but can be disabled in settings.

---

## 🧪 Testing

### Manual Testing Checklist

#### Authentication & Profile

- [ ] Sign up with new email and password
- [ ] Log in with existing credentials
- [ ] Update profile settings (name, role, gender, DOB, language)
- [ ] Upload and crop profile image
- [ ] Log out and verify session cleared

#### Dashboard & Navigation

- [ ] View personalized greeting and stats
- [ ] Check birthday animation (if applicable)
- [ ] Browse recommended cases for role
- [ ] Filter cases by specialty and difficulty
- [ ] Continue in-progress sessions

#### Simulation Experience

- [ ] Start new simulation and read briefing
- [ ] Send chat messages with streaming responses
- [ ] Test multi-language patient responses (Tamil, Sinhala)
- [ ] Request AI Preceptor hints and verify panel display
- [ ] Get another hint and verify different perspective
- [ ] Order diagnostic tests with justifications
- [ ] Build differential diagnosis with confidence levels
- [ ] Verify vital sign updates with smooth animations
- [ ] Monitor living patient physics (vital sign drift)
- [ ] Complete simulation and view AI-generated evaluation

#### Reports & Analytics

- [ ] Check performance dashboard and statistics
- [ ] Review session history with specialty theming
- [ ] Test role-based recommendations
- [ ] Verify haptic feedback throughout app

### Known Issues

- Performance may vary based on network speed (AI streaming)
- Some animations may stutter on older devices (iOS 17.0 minimum)
- First AI response may have slight delay (Gemini API cold start)
- Profile image cropping requires iOS 17+ for optimal experience
- Haptic feedback unavailable on simulator (test on physical device)

---

## 🛣️ Roadmap

### Planned Features

- [ ] **Additional Languages**: Hindi, Spanish, Mandarin, Arabic support
- [ ] **Multi-Patient Rounds**: Manage multiple patients simultaneously
- [ ] **Team Collaboration**: Multi-user simulations with role assignments
- [ ] **Voice Input**: Speak to patients naturally with speech-to-text
- [ ] **Advanced Analytics**: Machine learning insights and trend analysis
- [ ] **Custom Cases**: User-generated content and case sharing
- [ ] **Offline Mode**: Local AI model fallback for network-free practice
- [ ] **Export Reports**: PDF performance summaries and certificates
- [ ] **Gamification**: Achievements, badges, and leaderboards
- [ ] **Cloud Sync**: Optional cloud backup and multi-device sync
- [ ] **Video Briefings**: Multimedia case presentations
- [ ] **AR Patient Examination**: Augmented reality physical exam features

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

Copyright (c) 2025 hareeshkar

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

- **Lead Developer**: hareeshkar
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
- 🐛 **Bug Reports**: [GitHub Issues](https://github.com/hareeshkar/ClinicalSimulator/issues)
- 📖 **Documentation**: [Wiki](https://github.com/hareeshkar/ClinicalSimulator/wiki)

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

[Report Bug](https://github.com/hareeshkar/ClinicalSimulator/issues) • [Request Feature](https://github.com/hareeshkar/ClinicalSimulator/issues) • [View Demo](https://youtu.be/demo)

</div>
