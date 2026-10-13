//
//  LegalDocsContent.swift
//  NoFap
//

import Foundation

struct LegalDocs {
    static let privacyPolicyLastUpdated = "October 4, 2026"
    static let termsLastUpdated = "October 4, 2026"
    static let supportEmail = "support@spartanapp.com"
    static let appleStandardEULAURL = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"

    static let privacyPolicyText = """
    Last updated: October 4, 2026

    This Privacy Policy describes how the Spartan Discipline & Streak Tracker application (“the App”, “we”, “us”, or “our”) collects, uses, and safeguards your information.

    1. Information We Collect
    We adhere to data minimization principles. We do not require your real name, phone number, or contacts to use the App.

    - Account Identifiers: When cloud synchronization is enabled, the App generates a cryptographically secure random user identifier (User UUID) and a unique 6-character profile invite code. If you register via email, your email address is securely stored for authentication purposes only.
    - Habit and Streak Metrics: The App stores your streak counters, milestone achievements, daily check-in timestamps, target duration selections (7, 21, 45, or 90 days), and relapse timestamps if recorded.
    - Journal and Mood Logs: Self-reflection notes, urge ratings, and mood check-ins you choose to submit are stored encrypted alongside your User UUID solely for your personal review.
    - Social and Accountability Features:
      - Buddy & Squad Pairing: When you sync with a buddy or squad via code, we store the relationship link between the respective User UUIDs.
      - In-App Chat: Messages exchanged within the 1-on-1 buddy chat are processed and stored via secure real-time backend channels solely to deliver conversations to the intended participants.
      - SOS Notifications: If you trigger the SOS alert feature, a device notification token (APNs token) is used to dispatch an urgent push alert to your designated buddy.
    - Purchase Data: All financial transactions are processed directly by Apple via the App Store. We do not store or have access to your credit card or financial details. We collect anonymous receipt identifiers via RevenueCat to verify active Pro access.

    2. How We Use Information
    We process your data strictly to provide and maintain the App's core functionality:
    - Tracking and displaying your recovery streaks and avatar rank progression.
    - Facilitating synchronized accountability with your chosen buddy and squad.
    - Delivering real-time chat messages and SOS emergency push notifications.
    - Validating subscription entitlement status.

    We do NOT sell personal data. We do NOT use third-party advertising SDKs, cross-app tracking, or data brokers.

    3. Data Storage, Security, and Retention
    - Transmission and Encryption: All network communication occurs strictly over HTTPS/TLS encryption. Data is stored on secure cloud database servers with strict Row-Level Security (RLS) policies ensuring users can only read and write their own authorized records.
    - Authentication tokens are preserved within the secure iOS Keychain.
    - Retention: Data is retained for the lifetime of your active profile. Inactive guest profiles without recorded activity for 12 months may be automatically purged.

    4. Account and Data Deletion (App Store Guideline 5.1.1(v))
    You maintain absolute control over your records. You may permanently delete your data through either method:
    - In-App Self-Service: Navigate to Settings → tap "Delete Account and Data". This immediately and permanently purges your profile, streak records, journal logs, buddy connections, and chat history from our servers.
    - Email Request: Send an email to support@spartanapp.com with your profile invite code. We will execute complete deletion within 30 days.

    5. Children’s Privacy
    The App is strictly not directed to children under 13 (or under 16 in the European Union). We do not knowingly collect personal information from minors.

    6. Changes to This Policy
    We may update this policy periodically. Revisions will be published on this page with an updated "Last updated" date.

    7. Contact Us
    If you have questions regarding this Privacy Policy or data protection, contact:
    Email: support@spartanapp.com
    """

    static let termsOfUseText = """
    Last updated: October 4, 2026

    These Terms of Use (“Terms”) constitute a binding agreement between you and the Spartan Discipline team regarding your use of the Spartan Discipline & Streak Tracker application (“the App”). By downloading, accessing, or using the App, you agree to these Terms. If you do not agree, do not use the App.

    1. Medical and Healthcare Disclaimer (Not Medical Advice)
    THE APP IS A SELF-DIRECTED HABIT-TRACKING AND EDUCATIONAL DISCIPLINE TOOL. IT IS NOT A MEDICAL DEVICE, DOES NOT PROVIDE MEDICAL, PSYCHIATRIC, OR CLINICAL ADVICE, AND DOES NOT DIAGNOSE, TREAT, CURE, OR PREVENT ANY CLINICAL ADDICTION OR HEALTH CONDITION.

    Information and scientific facts within the App are for general informational and educational purposes only. Always consult a qualified physician, psychologist, or healthcare provider regarding any mental health crisis or medical condition. If you are experiencing an acute emergency or thoughts of self-harm, immediately contact your local emergency services or a crisis helpline.

    2. License and Intellectual Property
    We grant you a revocable, non-exclusive, non-transferable, personal license to download, install, and operate the App on Apple-branded devices that you own or control, subject to the App Store Terms of Service and Apple’s Licensed Application End User License Agreement (Standard EULA).

    All graphics, avatar designs, Spartan rank artwork, daily texts, software code, and UI elements remain our exclusive proprietary property. You may not decompile, reverse engineer, extract, modify, or resell any portion of the App.

    3. User Content and Code of Conduct (Guideline 1.2)
    When participating in the Buddy Chat, Squads, or journal notes:
    - You remain solely responsible for the content you transmit.
    - You agree not to send harassing, threatening, sexually explicit, abusive, or unlawful messages to your accountability partner.
    - We reserve the right to revoke chat access or terminate accounts that violate community safety standards.

    4. Spartan Pro Access
    Some features are marked Spartan Pro. The App shows whether that access is active for the email account you sign in with. The same account can be used on your other devices. The App does not sell access and does not show prices.

    5. Disclaimer of Warranties and Limitation of Liability
    The App is provided on an “AS IS” and “AS AVAILABLE” basis without warranties of any kind, whether express or implied. We do not guarantee that habit tracking will produce specific behavioural or physiological outcomes for every user.

    To the maximum extent permitted by applicable law, in no event shall we be liable for indirect, incidental, punitive, or consequential damages resulting from your use of or inability to use the App.

    6. Apple Standard EULA Reference
    These Terms incorporate by reference Apple’s standard Licensed Application End User License Agreement:
    https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

    7. Contact Information
    For technical inquiries, bug reports, or legal notices:
    Email: support@spartanapp.com
    """

    static func text(for resource: String) -> String {
        resource == "terms" ? termsOfUseText : privacyPolicyText
    }
}
