import { onCall, HttpsError } from "firebase-functions/v2/https";
import { Part, Type } from "@google/genai";

import { GEMINI_API_KEY, generateJson, imageUrlToPart } from "./gemini";

interface MealEstimate {
  items: {
    name: string;
    portion: string;
    calories: number;
    protein: number;
    carbs: number;
    fat: number;
  }[];
  confidence: number;
}

const SCHEMA = {
  type: Type.OBJECT,
  properties: {
    items: {
      type: Type.ARRAY,
      items: {
        type: Type.OBJECT,
        properties: {
          name: { type: Type.STRING },
          portion: { type: Type.STRING },
          calories: { type: Type.INTEGER },
          protein: { type: Type.NUMBER },
          carbs: { type: Type.NUMBER },
          fat: { type: Type.NUMBER },
        },
        required: ["name", "portion", "calories", "protein", "carbs", "fat"],
      },
    },
    confidence: { type: Type.NUMBER },
  },
  required: ["items", "confidence"],
};

const SYSTEM = `
You are a nutrition estimation engine. Given a meal photo and/or a text
description, identify the foods, estimate realistic portions, and estimate
calories and macros (protein/carbs/fat in grams) per item.
- Be realistic, not perfectionist; typical home portions unless stated.
- If a photo is ambiguous, make your best reasonable guess and lower "confidence".
- "confidence" is 0..1 reflecting how sure you are overall.
- Prefer fewer, sensible items over many tiny ones.
`.trim();

export const estimateMeal = onCall(
  { secrets: [GEMINI_API_KEY] },
  async (request): Promise<MealEstimate> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    const text = (request.data?.text as string | undefined)?.trim();
    const photoUrl = request.data?.photoUrl as string | undefined;

    if (!text && !photoUrl) {
      throw new HttpsError(
        "invalid-argument",
        "Provide a photo or a description."
      );
    }

    const parts: Part[] = [];
    if (photoUrl) {
      try {
        parts.push(await imageUrlToPart(photoUrl));
      } catch (e) {
        throw new HttpsError("internal", `Could not read photo: ${e}`);
      }
    }
    parts.push({
      text: text
        ? `Meal description: ${text}`
        : "Estimate this meal from the photo.",
    });

    try {
      const result = await generateJson<MealEstimate>({
        system: SYSTEM,
        parts,
        schema: SCHEMA,
      });
      // Defensive defaults.
      result.items ??= [];
      result.confidence ??= 0.5;
      return result;
    } catch (e) {
      throw new HttpsError("internal", `Estimation failed: ${e}`);
    }
  }
);
