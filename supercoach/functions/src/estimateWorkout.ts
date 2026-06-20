import { onCall, HttpsError } from "firebase-functions/v2/https";
import { Type } from "@google/genai";

import { GEMINI_API_KEY, generateJson } from "./gemini";
import { loadProfile } from "./context";

interface WorkoutEstimate {
  activity: string;
  durationMin: number;
  caloriesBurned: number;
}

const SCHEMA = {
  type: Type.OBJECT,
  properties: {
    activity: { type: Type.STRING },
    durationMin: { type: Type.INTEGER },
    caloriesBurned: { type: Type.INTEGER },
  },
  required: ["activity", "durationMin", "caloriesBurned"],
};

export const estimateWorkout = onCall(
  { secrets: [GEMINI_API_KEY] },
  async (request): Promise<WorkoutEstimate> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    const text = (request.data?.text as string | undefined)?.trim();
    if (!text) {
      throw new HttpsError("invalid-argument", "Describe the workout.");
    }

    const profile = await loadProfile(request.auth.uid);
    const weight = (profile.weightKg as number) ?? 70;

    const system = `
You estimate exercise from a short description. Output the activity name, the
duration in minutes, and calories burned. Assume the user weighs about ${weight} kg.
Use standard MET-based estimates. If duration isn't stated, infer a reasonable one.
`.trim();

    try {
      const result = await generateJson<WorkoutEstimate>({
        system,
        parts: [{ text }],
        schema: SCHEMA,
      });
      result.activity ||= "Workout";
      result.durationMin ||= 0;
      result.caloriesBurned ||= 0;
      return result;
    } catch (e) {
      throw new HttpsError("internal", `Estimation failed: ${e}`);
    }
  }
);
