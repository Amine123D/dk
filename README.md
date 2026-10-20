# Lendly

A private lending library for neighbors. People in the same building, street, school, or club can share items for free or with an optional thank-you tip. No payments, no public marketplace, and no in-app chat.

## Milestones 1–2: Authentication, groups, and home shell
- Email/password account creation and login
- Password reset
- Google sign-in wiring (requires Android/Firebase configuration)
- Create a group and display an invite code
- Join a group with a six-character code (prototype flow; server-side invite validation is still required)
- Home screen shell with group switcher, search UI, category chips, available-only filter, sort menu, and four-tab navigation
- Material 3 light theme, green primary color (#2E7D32)

This is an in-progress starter, not the complete app. The feed is currently an empty-state UI; item listings, photos, borrowing, ratings, notifications, and reminders will be added in later steps. The source has not yet been built or tested with Flutter in this environment.

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


## Milestone 3 — Share items and browse the group feed

The app now includes an item creation form and a live Firestore feed for the selected group:
- Add a title, category, condition, description, optional borrowing notes, and a 1–30 day maximum loan period.
- Choose up to four photos; images upload to Firebase Storage.
- Browse group listings, open item details, search by title/description, filter by category/availability, and sort newest or title A–Z.
- Item reads are restricted in the Firestore rules to members of the listing's group.

### Additional Firebase setup for item photos
1. In Firebase Console, open **Storage** and choose **Get started**.
2. Choose a storage location and finish setup.
3. Publish the repository's `storage.rules` rules from the Storage > Rules page.
4. Publish `firestore.rules` from Firestore Database > Rules.
5. From your local Flutter project, run `flutter pub get` so `image_picker` is installed.

**Important:** These are development rules and still need a complete security review and emulator tests before public launch. The app's invite-code join flow is still a prototype and must be moved to a trusted Cloud Function before launch. We have not run a Flutter build or device test in this environment.
