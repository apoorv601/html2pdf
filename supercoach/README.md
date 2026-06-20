# SuperCoach 💪 — AI Personal Fitness & Life Coach

A proactive AI fitness coach: it nudges you to log meals (photo / voice / text),
auto-estimates calories with **Gemini**, tracks workouts, shows a daily
dashboard, and chats with you like a real trainer.

This is the **Phase-1 MVP** described in [`docs/SUPERCOACH_PLAN.md`](../docs/SUPERCOACH_PLAN.md).

```
supercoach/
├── app/         Flutter mobile app (iOS + Android)
├── functions/   Firebase Cloud Functions (TypeScript) — all Gemini calls
└── firebase/    Firestore + Storage security rules, emulator config
```

## What's implemented (MVP)

- **Auth** — email/password + Google sign-in (`app/lib/features/auth`).
- **Conversational onboarding** — the coach interviews you and writes a
  structured profile (`app/lib/features/onboarding`, `functions/src/onboarding.ts`).
- **Food logging** — photo, voice-to-text, or text → Gemini estimates
  calories + macros → review/edit → save
  (`app/lib/features/logging/log_meal_screen.dart`, `functions/src/estimateMeal.ts`).
- **Workout logging** — "ran 3km in 25 min" → Gemini estimates calories burned
  (`functions/src/estimateWorkout.ts`).
- **Dashboard** — calorie ring, macros, meal/workout status
  (`app/lib/features/dashboard`).
- **Coach chat** — context-aware, persistent (`functions/src/coachChat.ts`).
- **Proactive nudges** — hourly Cloud Scheduler fans out meal/workout/missed-log
  push notifications via FCM (`functions/src/scheduler.ts`).

> ⚠️ The app **never** calls Gemini directly — every AI call goes through Cloud
> Functions so the API key stays server-side.

## Prerequisites

- Flutter SDK (3.4+), Dart, Android Studio / Xcode
- Node.js 20 (for Cloud Functions)
- Firebase CLI (`npm i -g firebase-tools`)
- A Firebase project (Blaze plan — required for Cloud Functions + outbound calls)
- A Gemini API key from Google AI Studio

## Setup

### 1. Firebase project
```bash
firebase login
# from supercoach/firebase
firebase use --add            # select your project
firebase deploy --only firestore:rules,storage
```
Enable in the Firebase console: **Authentication** (Email + Google),
**Firestore**, **Storage**, **Cloud Messaging**, and **Functions**.

### 2. Cloud Functions
```bash
cd functions
npm install
firebase functions:secrets:set GEMINI_API_KEY     # paste your AI Studio key
# Optional: choose the model (defaults to gemini-2.5-flash)
# Set GEMINI_MODEL in the function env to your preferred Flash model.
npm run build
firebase deploy --only functions
```

### 3. Flutter app
```bash
cd app
# Generate the native android/ + ios/ platform folders (keeps existing lib/):
flutter create --org com.example --project-name supercoach .
dart pub global activate flutterfire_cli
flutterfire configure          # regenerates lib/firebase_options.dart for YOUR project
flutter pub get
flutter run
```
> This repo ships the Dart source (`lib/`), `pubspec.yaml`, and analysis config.
> The platform folders are generated locally by `flutter create` so they match
> your Flutter version and bundle id.
Add platform config: `android/app/google-services.json` and
`ios/Runner/GoogleService-Info.plist` (downloaded from the Firebase console).

For push notifications on iOS you'll also need an APNs key uploaded to Firebase.

## Local development (emulators)
```bash
cd firebase
firebase emulators:start        # auth, firestore, functions, storage
```
Point the app at the emulators by adding `useEmulator` calls in `main.dart`
during development (see Firebase docs).

## Data model (Firestore)
```
users/{uid}                      profile, goals, schedule, prefs, fcmToken
users/{uid}/meals/{id}           type, items[], totalCalories, photoUrl, ...
users/{uid}/workouts/{id}        activity, durationMin, caloriesBurned
users/{uid}/chat/{id}            role (user|coach), text, timestamp
```

## Verification checklist
1. Sign up → user doc created.
2. Complete onboarding → `onboardingComplete: true`, profile fields populated.
3. Log a meal by photo → calories appear, dashboard ring updates.
4. Log a meal by voice/text → parsed correctly.
5. Log a workout → burned calories show on dashboard.
6. Chat with the coach → context-aware reply, persists across restarts.
7. Set a meal window to the current hour, leave it unlogged → nudge arrives
   (trigger `sendCoachNudges` manually from the console to test).

## Roadmap
Phase 2 (adaptive plans, sentiment-aware coaching, charts, health sync) and
Phase 3 (full voice coach, predictive nudges) are detailed in
[`docs/SUPERCOACH_PLAN.md`](../docs/SUPERCOACH_PLAN.md).
