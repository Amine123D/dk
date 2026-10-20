# Lendly

Lendly is a private, group-based lending library for neighbors. The app is Flutter/Dart with Material 3 and a green theme.

## Current features
- Email/password signup, login, logout, and password reset through Supabase Auth.
- Create a private group or join with a 6-character invite code.
- Group membership is checked by PostgreSQL Row Level Security (RLS).
- Add items with category, condition, description, borrowing notes, maximum loan period, and up to four photos.
- Browse a group's listings, search, filter by category/availability, sort by title, and view item details.
- Private item-photo storage with group-member access policies.

The My Items, Requests, and Profile tabs are placeholders for upcoming milestones. Borrowing requests, overlap checks, ratings, notifications, and scheduled reminders are not implemented yet.

## Free-tier setup

The current connected Supabase project is on the **Free** plan. Lendly uses a publishable client key (not a service-role key); authorization is enforced by database RLS and private Storage policies. Free plans have usage limits and may pause inactive projects, so keep an eye on the Supabase dashboard.

Lendly's tables are namespaced with `lendly_` to avoid touching unrelated tables already in the connected project. The database schema and private `lendly-item-photos` bucket have been created in that project.

### Run locally
1. Install Flutter (stable) on a computer.
2. From the repository root, run:
   ```sh
   flutter create --platforms=android --project-name lendly --org com.lendly .
   flutter pub get
   flutter run
   ```
3. The app has a development default for the connected Supabase URL and **publishable** key in `lib/main.dart`. For your own Supabase project, override them with:
   ```sh
   flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
   ```
4. In Supabase Dashboard > Authentication > Providers, enable Email. If email confirmation is on, users must confirm their email before they can sign in.
5. To build a release APK locally:
   ```sh
   flutter build apk --release
   ```

### Build APK using GitHub Actions
The workflow `.github/workflows/build-apk.yml` generates Android scaffolding in the runner, builds the release APK, and uploads it as a workflow artifact. It does not commit generated Android files back into the repository.

## Data and security notes
- RLS is enabled on all Lendly tables.
- Group invite codes are resolved by a restricted authenticated RPC, not by exposing all group rows.
- Item photos are in a private bucket. Only a group member can create signed photo URLs for that group's objects; users can upload only under their own user-ID folder.
- Never put a Supabase **secret/service-role** key in Flutter or GitHub source. The publishable key is designed for client apps, but must always be paired with correct RLS policies.
- This is an in-progress prototype. Review policies and test with two separate accounts before sharing it publicly. The connected project's pre-existing tables were left unchanged.
