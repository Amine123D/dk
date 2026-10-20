# Lendly

A private lending library for neighbors. People in the same building, street, school, or club can share items for free or with an optional thank-you tip. No payments, no public marketplace, and no in-app chat.

## Milestone 1: Authentication and groups
- Email/password account creation and login
- Password reset
- Google sign-in wiring (requires Android/Firebase configuration)
- Create a group and display an invite code
- Join a group with a six-character code
- Material 3 light theme, green primary color (#2E7D32)

This is the first starter milestone, not the complete app. Item listings, photos, borrowing, ratings, notifications, and reminders will be added in later steps.

## Structure
- `lib/main.dart` — login, sign-up, group create/join
- `pubspec.yaml` — Flutter packages
- `firestore.rules` — initial rules draft

## Firebase setup (Android)
1. Open https://console.firebase.google.com/ and create a project named **Lendly**.
2. In the project overview choose **Add app → Android**.
3. Use package name `com.example.lendly` for this starter. Keep it consistent with the Android package name in your Flutter project.
4. Download `google-services.json` and place it at `android/app/google-services.json`.
5. Go to **Build → Authentication → Get started → Sign-in method**. Enable **Email/Password** and **Google**.
6. For Google sign-in, add your Android SHA-1/SHA-256 fingerprints under **Project settings → Your apps**.
7. Go to **Build → Firestore Database → Create database** and choose a region.
8. Publish rules only after reviewing and emulator-testing them. The rules file is a draft, not production-ready.
9. Storage and Cloud Messaging are dependencies for later milestones. Scheduled reminders require Cloud Functions deployment; check current Firebase plan requirements before enabling billing.
10. This repo currently contains Flutter source, not the generated Android Gradle wrapper or Firebase config. Build an APK only after creating/opening a Flutter project, adding these files, and completing Firebase setup.

## Important limitations before real users
- Group invite lookup must be moved to a trusted callable Cloud Function to keep private group details private.
- The current join screen's direct invite lookup is a prototype and is not compatible with strict group-read rules until that function is added.
- Google sign-in requires OAuth setup and SHA fingerprints.
- The current rules need further hardening and tests before production.
- Never commit service-account keys or other secrets.
