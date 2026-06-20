import { onSchedule } from "firebase-functions/v2/scheduler";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";

import { GEMINI_API_KEY, generateText } from "./gemini";
import { loadTodayStats } from "./context";
import { COACH_PERSONA, userContextBlock, todayContextBlock } from "./prompts";

interface TimeWindow {
  label: string;
  time: string; // "HH:mm"
}

/// Returns the user's local hour/minute/weekday for a given IANA timezone.
function localNow(timezone: string): {
  hour: number;
  minute: number;
  weekday: string;
} {
  const fmt = new Intl.DateTimeFormat("en-US", {
    timeZone: timezone,
    hour: "2-digit",
    minute: "2-digit",
    weekday: "short",
    hour12: false,
  });
  const parts = fmt.formatToParts(new Date());
  const get = (t: string) => parts.find((p) => p.type === t)?.value ?? "";
  return {
    hour: parseInt(get("hour"), 10) % 24,
    minute: parseInt(get("minute"), 10),
    weekday: get("weekday"), // "Mon", "Tue", ...
  };
}

function withinQuietHours(
  hour: number,
  start: string,
  end: string
): boolean {
  const sh = parseInt(start.split(":")[0] ?? "22", 10);
  const eh = parseInt(end.split(":")[0] ?? "7", 10);
  // Quiet window may wrap past midnight (e.g. 22 -> 7).
  if (sh <= eh) return hour >= sh && hour < eh;
  return hour >= sh || hour < eh;
}

/// Generate a short, personalised nudge. Falls back to a template on error.
async function nudgeText(
  uid: string,
  profile: Record<string, unknown>,
  kind: "meal" | "workout" | "missed",
  label: string
): Promise<string> {
  const fallback =
    kind === "workout"
      ? `Time for your ${label}! A quick session beats none. 💪`
      : kind === "missed"
        ? `Don't forget to log your ${label} — I'm keeping track with you. 📝`
        : `${label} time! What are you having? Tap to log it. 🍽️`;
  try {
    const stats = await loadTodayStats(uid);
    const system = [
      COACH_PERSONA,
      userContextBlock(profile),
      todayContextBlock(stats),
    ].join("\n\n");
    const prompt =
      kind === "workout"
        ? `Write a 1-sentence push notification reminding the user about their ${label}. Motivating, warm, <120 chars.`
        : kind === "missed"
          ? `Write a 1-sentence push notification gently nudging the user to log their ${label}. Supportive, not naggy, <120 chars.`
          : `Write a 1-sentence push notification asking the user what they ate for ${label} and to log it. Friendly, <120 chars.`;
    const text = await generateText({
      system,
      history: [{ role: "user", text: prompt }],
      temperature: 0.9,
    });
    return text.trim().replace(/^["']|["']$/g, "") || fallback;
  } catch {
    return fallback;
  }
}

async function send(token: string, title: string, body: string, route: string) {
  await getMessaging().send({
    token,
    notification: { title, body },
    data: { route },
    android: { priority: "high" },
    apns: { payload: { aps: { sound: "default" } } },
  });
}

/// Runs hourly. Decides who needs a meal prompt, workout reminder, or
/// missed-log nudge, and sends it via FCM.
export const sendCoachNudges = onSchedule(
  { schedule: "every 60 minutes", secrets: [GEMINI_API_KEY] },
  async () => {
    const db = getFirestore();
    const usersSnap = await db
      .collection("users")
      .where("notificationsEnabled", "==", true)
      .get();

    const now = new Date();
    const start = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const end = new Date(start.getTime() + 24 * 60 * 60 * 1000);

    await Promise.all(
      usersSnap.docs.map(async (doc) => {
        const profile = doc.data();
        const token = profile.fcmToken as string | undefined;
        if (!token || !profile.onboardingComplete) return;

        const tz = (profile.timezone as string) || "UTC";
        const { hour, weekday } = localNow(tz);

        if (
          withinQuietHours(
            hour,
            (profile.quietHoursStart as string) || "22:00",
            (profile.quietHoursEnd as string) || "07:00"
          )
        ) {
          return;
        }

        const uid = doc.id;
        const mealWindows = (profile.mealWindows as TimeWindow[]) ?? [];
        const workoutWindow = profile.workoutWindow as TimeWindow | undefined;
        const workoutDays = (profile.workoutDays as string[]) ?? [];

        // What's already logged today?
        const [mealsSnap, workoutsSnap] = await Promise.all([
          db
            .collection(`users/${uid}/meals`)
            .where("timestamp", ">=", Timestamp.fromDate(start))
            .where("timestamp", "<", Timestamp.fromDate(end))
            .get(),
          db
            .collection(`users/${uid}/workouts`)
            .where("timestamp", ">=", Timestamp.fromDate(start))
            .where("timestamp", "<", Timestamp.fromDate(end))
            .get(),
        ]);
        const loggedMealLabels = new Set(
          mealsSnap.docs.map((d) => (d.data().type as string) ?? "")
        );

        // Meal prompts: when the current hour matches a meal window.
        for (const w of mealWindows) {
          const wh = parseInt(w.time.split(":")[0] ?? "-1", 10);
          if (wh !== hour) continue;
          const already = loggedMealLabels.has(w.label.toLowerCase());
          const body = await nudgeText(
            uid,
            profile,
            already ? "missed" : "meal",
            w.label
          );
          await send(token, "SuperCoach", body, "/log-meal");
        }

        // Workout reminder: matching day + hour, and nothing logged yet.
        if (
          workoutWindow &&
          workoutsSnap.empty &&
          (workoutDays.length === 0 || workoutDays.includes(weekday))
        ) {
          const wh = parseInt(workoutWindow.time.split(":")[0] ?? "-1", 10);
          if (wh === hour) {
            const body = await nudgeText(
              uid,
              profile,
              "workout",
              workoutWindow.label || "workout"
            );
            await send(token, "SuperCoach", body, "/log-workout");
          }
        }
      })
    );
  }
);
