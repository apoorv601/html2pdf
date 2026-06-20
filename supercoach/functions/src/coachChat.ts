import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, Timestamp } from "firebase-admin/firestore";

import { GEMINI_API_KEY, generateText } from "./gemini";
import { loadProfile, loadTodayStats } from "./context";
import {
  COACH_PERSONA,
  userContextBlock,
  todayContextBlock,
} from "./prompts";

export const coachChat = onCall(
  { secrets: [GEMINI_API_KEY] },
  async (request): Promise<{ reply: string }> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    const uid = request.auth.uid;
    const message = (request.data?.message as string | undefined)?.trim();
    if (!message) {
      throw new HttpsError("invalid-argument", "Empty message.");
    }

    const db = getFirestore();
    const [profile, stats, historySnap] = await Promise.all([
      loadProfile(uid),
      loadTodayStats(uid),
      db
        .collection(`users/${uid}/chat`)
        .orderBy("timestamp", "desc")
        .limit(20)
        .get(),
    ]);

    // Recent history in chronological order (excludes the just-sent message,
    // which the client may or may not have written yet — we append it below).
    const history = historySnap.docs
      .reverse()
      .map((d) => ({
        role: (d.data().role === "user" ? "user" : "model") as
          | "user"
          | "model",
        text: (d.data().text as string) ?? "",
      }))
      .filter((h) => h.text);

    // Ensure the current message is the last user turn.
    if (history.length === 0 || history[history.length - 1].text !== message) {
      history.push({ role: "user", text: message });
    }

    const system = [
      COACH_PERSONA,
      userContextBlock(profile),
      todayContextBlock(stats),
    ].join("\n\n");

    let reply: string;
    try {
      reply = await generateText({ system, history });
    } catch (e) {
      throw new HttpsError("internal", `Coach unavailable: ${e}`);
    }
    reply = reply.trim() || "I'm here for you — tell me more.";

    // Persist the coach's reply so the app's chat stream picks it up.
    await db.collection(`users/${uid}/chat`).add({
      role: "coach",
      text: reply,
      timestamp: Timestamp.now(),
    });

    return { reply };
  }
);
