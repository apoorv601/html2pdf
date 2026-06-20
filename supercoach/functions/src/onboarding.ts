import { onCall, HttpsError } from "firebase-functions/v2/https";
import { Type } from "@google/genai";

import { GEMINI_API_KEY, generateJson } from "./gemini";
import { COACH_PERSONA, ONBOARDING_INSTRUCTIONS } from "./prompts";

interface OnboardingResult {
  reply: string;
  done: boolean;
  profilePatch: Record<string, unknown> | null;
}

const TIME_WINDOW = {
  type: Type.OBJECT,
  properties: {
    label: { type: Type.STRING },
    time: { type: Type.STRING }, // "HH:mm"
  },
  required: ["label", "time"],
};

const SCHEMA = {
  type: Type.OBJECT,
  properties: {
    reply: { type: Type.STRING },
    done: { type: Type.BOOLEAN },
    profilePatch: {
      type: Type.OBJECT,
      nullable: true,
      properties: {
        goal: {
          type: Type.STRING,
          enum: ["loseFat", "buildMuscle", "stayFit", "improveStamina"],
        },
        fitnessLevel: {
          type: Type.STRING,
          enum: ["beginner", "intermediate", "advanced"],
        },
        age: { type: Type.INTEGER },
        sex: { type: Type.STRING },
        heightCm: { type: Type.NUMBER },
        weightKg: { type: Type.NUMBER },
        targetWeightKg: { type: Type.NUMBER },
        dailyCalorieTarget: { type: Type.INTEGER },
        equipment: { type: Type.STRING },
        notes: { type: Type.STRING },
        workoutDays: { type: Type.ARRAY, items: { type: Type.STRING } },
        dietaryRestrictions: {
          type: Type.ARRAY,
          items: { type: Type.STRING },
        },
        mealWindows: { type: Type.ARRAY, items: TIME_WINDOW },
        workoutWindow: { ...TIME_WINDOW, nullable: true },
      },
    },
  },
  required: ["reply", "done"],
};

export const onboardingTurn = onCall(
  { secrets: [GEMINI_API_KEY] },
  async (request): Promise<OnboardingResult> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    const transcript =
      (request.data?.transcript as { role: string; text: string }[]) ?? [];

    const convo = transcript
      .map((t) => `${t.role === "user" ? "User" : "Coach"}: ${t.text}`)
      .join("\n");

    const system = [COACH_PERSONA, ONBOARDING_INSTRUCTIONS].join("\n\n");

    try {
      const result = await generateJson<OnboardingResult>({
        system,
        parts: [
          {
            text: `Conversation so far:\n${convo}\n\nProduce the next coach turn as JSON.`,
          },
        ],
        schema: SCHEMA,
      });
      result.reply ||= "Tell me a bit more!";
      result.done ??= false;
      if (!result.done) result.profilePatch = null;
      return result;
    } catch (e) {
      throw new HttpsError("internal", `Onboarding failed: ${e}`);
    }
  }
);
