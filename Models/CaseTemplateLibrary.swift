// Models/CaseTemplateLibrary.swift

import Foundation

struct CaseTemplateLibrary {
    
    static let allTemplates: [CaseTemplate] =
        emergencyMedicineCases +
        internalMedicineCases +
        pediatricsCases +
        surgeryCases +
        psychiatryCases +
        cardiologyCases +
        neurologyCases

    // MARK: - Emergency Medicine
    static let emergencyMedicineCases: [CaseTemplate] = [
        CaseTemplate(
            title: "Anaphylactic Shock",
            specialty: "Emergency Medicine",
            difficulty: "Intermediate",
            chiefComplaint: "45-year-old with sudden shortness of breath and hives after a bee sting.",
            finalDiagnosis: "Anaphylaxis",
            iconName: "bolt.heart.fill"
        ),
        CaseTemplate(
            title: "Pulmonary Embolism",
            specialty: "Emergency Medicine",
            difficulty: "Advanced",
            chiefComplaint: "A 62-year-old female presents with acute onset pleuritic chest pain and tachycardia.",
            finalDiagnosis: "Massive Pulmonary Embolism",
            iconName: "bolt.heart.fill"
        ),
        CaseTemplate(
            title: "Diabetic Ketoacidosis (DKA)",
            specialty: "Emergency Medicine",
            difficulty: "Intermediate",
            chiefComplaint: "19-year-old with known Type 1 Diabetes presenting with nausea, vomiting, and fruity-smelling breath.",
            finalDiagnosis: "Diabetic Ketoacidosis",
            iconName: "bolt.heart.fill"
        ),
        CaseTemplate(
            title: "Ischemic Stroke",
            specialty: "Emergency Medicine",
            difficulty: "Advanced",
            chiefComplaint: "72-year-old male with sudden onset of right-sided weakness and facial droop.",
            finalDiagnosis: "Acute Ischemic Stroke",
            iconName: "bolt.heart.fill"
        )
    ]

    // MARK: - Internal Medicine
    static let internalMedicineCases: [CaseTemplate] = [
        CaseTemplate(
            title: "Community-Acquired Pneumonia",
            specialty: "Internal Medicine",
            difficulty: "Beginner",
            chiefComplaint: "68-year-old with a 3-day history of productive cough, fever, and malaise.",
            finalDiagnosis: "Community-Acquired Pneumonia (CAP)",
            iconName: "cross.case.fill"
        ),
        CaseTemplate(
            title: "Decompensated Heart Failure",
            specialty: "Internal Medicine",
            difficulty: "Intermediate",
            chiefComplaint: "75-year-old with worsening shortness of breath, leg swelling, and orthopnea.",
            finalDiagnosis: "Acute Decompensated Heart Failure",
            iconName: "cross.case.fill"
        ),
        CaseTemplate(
            title: "Acute Kidney Injury",
            specialty: "Internal Medicine",
            difficulty: "Intermediate",
            chiefComplaint: "80-year-old nursing home resident with decreased urine output and confusion.",
            finalDiagnosis: "Acute Kidney Injury (AKI) secondary to dehydration",
            iconName: "cross.case.fill"
        ),
        CaseTemplate(
            title: "New Onset Atrial Fibrillation",
            specialty: "Internal Medicine",
            difficulty: "Intermediate",
            chiefComplaint: "67-year-old female complaining of palpitations and lightheadedness.",
            finalDiagnosis: "Atrial Fibrillation with Rapid Ventricular Response",
            iconName: "cross.case.fill"
        )
    ]
    
    // MARK: - Pediatrics
    static let pediatricsCases: [CaseTemplate] = [
        CaseTemplate(
            title: "Febrile Seizure",
            specialty: "Pediatrics",
            difficulty: "Beginner",
            chiefComplaint: "An 18-month-old presents after a 2-minute episode of full-body shaking, and has a fever.",
            finalDiagnosis: "Simple Febrile Seizure",
            iconName: "figure.2.and.child.holdinghands"
        ),
        CaseTemplate(
            title: "Asthma Exacerbation",
            specialty: "Pediatrics",
            difficulty: "Intermediate",
            chiefComplaint: "A 7-year-old with a history of asthma presents with audible wheezing and shortness of breath.",
            finalDiagnosis: "Moderate Asthma Exacerbation",
            iconName: "figure.2.and.child.holdinghands"
        ),
        CaseTemplate(
            title: "Acute Otitis Media",
            specialty: "Pediatrics",
            difficulty: "Beginner",
            chiefComplaint: "A 2-year-old is crying, pulling at their left ear, and has a fever.",
            finalDiagnosis: "Acute Otitis Media",
            iconName: "figure.2.and.child.holdinghands"
        ),
        CaseTemplate(
            title: "Viral Croup",
            specialty: "Pediatrics",
            difficulty: "Beginner",
            chiefComplaint: "A 3-year-old presents with a 'barking' cough and noisy breathing, worse at night.",
            finalDiagnosis: "Laryngotracheitis (Croup)",
            iconName: "figure.2.and.child.holdinghands"
        )
    ]

    // MARK: - Surgery
    static let surgeryCases: [CaseTemplate] = [
        CaseTemplate(
            title: "Acute Appendicitis",
            specialty: "Surgery",
            difficulty: "Beginner",
            chiefComplaint: "21-year-old male with migrating abdominal pain, now localized to the right lower quadrant.",
            finalDiagnosis: "Acute Appendicitis",
            iconName: "scissors"
        ),
        CaseTemplate(
            title: "Small Bowel Obstruction",
            specialty: "Surgery",
            difficulty: "Intermediate",
            chiefComplaint: "70-year-old with a history of abdominal surgery presents with vomiting and abdominal distention.",
            finalDiagnosis: "Small Bowel Obstruction (SBO)",
            iconName: "scissors"
        ),
        CaseTemplate(
            title: "Acute Cholecystitis",
            specialty: "Surgery",
            difficulty: "Intermediate",
            chiefComplaint: "A 45-year-old female presents with right upper quadrant pain after eating a fatty meal.",
            finalDiagnosis: "Acute Cholecystitis",
            iconName: "scissors"
        )
    ]

    // MARK: - Psychiatry
    static let psychiatryCases: [CaseTemplate] = [
        CaseTemplate(
            title: "Major Depressive Disorder",
            specialty: "Psychiatry",
            difficulty: "Beginner",
            chiefComplaint: "A 34-year-old reports a 2-month history of low mood, loss of interest, and poor sleep.",
            finalDiagnosis: "Major Depressive Disorder (MDD)",
            iconName: "brain.head.profile"
        ),
        CaseTemplate(
            title: "Panic Attack",
            specialty: "Psychiatry",
            difficulty: "Beginner",
            chiefComplaint: "A 28-year-old presents to the ER with a sudden episode of intense fear, chest pain, and a feeling of impending doom.",
            finalDiagnosis: "Panic Attack",
            iconName: "brain.head.profile"
        ),
        CaseTemplate(
            title: "Acute Manic Episode",
            specialty: "Psychiatry",
            difficulty: "Advanced",
            chiefComplaint: "A 22-year-old brought in by family for erratic behavior, not sleeping for 3 days, and pressured speech.",
            finalDiagnosis: "Bipolar I Disorder, current episode manic",
            iconName: "brain.head.profile"
        )
    ]
    
    // MARK: - Cardiology
    static let cardiologyCases: [CaseTemplate] = [
        CaseTemplate(
            title: "Acute Myocardial Infarction",
            specialty: "Cardiology",
            difficulty: "Advanced",
            chiefComplaint: "58-year-old male with 2 hours of crushing, substernal chest pain radiating to his left arm.",
            finalDiagnosis: "ST-Elevation Myocardial Infarction (STEMI)",
            iconName: "heart.fill"
        ),
        CaseTemplate(
            title: "Pericarditis",
            specialty: "Cardiology",
            difficulty: "Intermediate",
            chiefComplaint: "35-year-old male with sharp chest pain that is worse when lying down and better when leaning forward.",
            finalDiagnosis: "Acute Pericarditis",
            iconName: "heart.fill"
        ),
        CaseTemplate(
            title: "Hypertensive Emergency",
            specialty: "Cardiology",
            difficulty: "Advanced",
            chiefComplaint: "60-year-old with a headache, blurry vision, and a blood pressure of 220/130 mmHg.",
            finalDiagnosis: "Hypertensive Emergency",
            iconName: "heart.fill"
        ),
        CaseTemplate(
            title: "Aortic Dissection",
            specialty: "Cardiology",
            difficulty: "Advanced",
            chiefComplaint: "65-year-old male with sudden onset of a severe 'tearing' chest pain that radiates to his back.",
            finalDiagnosis: "Stanford Type A Aortic Dissection",
            iconName: "heart.fill"
        )
    ]

    // MARK: - Neurology
    static let neurologyCases: [CaseTemplate] = [
        CaseTemplate(
            title: "Meningitis",
            specialty: "Neurology",
            difficulty: "Intermediate",
            chiefComplaint: "19-year-old college student with high fever, severe headache, and neck stiffness.",
            finalDiagnosis: "Bacterial Meningitis",
            iconName: "brain"
        ),
        CaseTemplate(
            title: "Subarachnoid Hemorrhage",
            specialty: "Neurology",
            difficulty: "Advanced",
            chiefComplaint: "48-year-old female presents with a sudden, explosive headache described as the 'worst headache of my life'.",
            finalDiagnosis: "Subarachnoid Hemorrhage (SAH)",
            iconName: "brain"
        ),
        CaseTemplate(
            title: "Status Epilepticus",
            specialty: "Neurology",
            difficulty: "Advanced",
            chiefComplaint: "A 30-year-old with a known seizure disorder has been actively seizing for over 5 minutes.",
            finalDiagnosis: "Status Epilepticus",
            iconName: "brain"
        ),
         CaseTemplate(
            title: "Migraine with Aura",
            specialty: "Neurology",
            difficulty: "Beginner",
            chiefComplaint: "A 29-year-old female reports a history of throbbing unilateral headaches preceded by seeing flashing lights.",
            finalDiagnosis: "Migraine with Aura",
            iconName: "brain"
        )
    ]
}
