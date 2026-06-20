import { GoogleGenAI, Part } from "@google/genai";
import { defineSecret } from "firebase-functions/params";

/// Gemini API key, stored in Secret Manager. Set it with:
///   firebase functions:secrets:set GEMINI_API_KEY
export const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

/// The model to use. The user requested "Gemini 3.5 Flash"; override via the
/// GEMINI_MODEL env var / function config if your project uses a different id.
export const MODEL = process.env.GEMINI_MODEL || "gemini-2.5-flash";

let client: GoogleGenAI | null = null;
function ai(): GoogleGenAI {
  client ??= new GoogleGenAI({ apiKey: GEMINI_API_KEY.value() });
  return client;
}

/// Generate a JSON object constrained to `schema`. Returns the parsed object.
export async function generateJson<T>(opts: {
  system: string;
  parts: Part[];
  // A Gemini responseSchema (OpenAPI-subset). `any` to avoid pulling the full type.
  schema: unknown;
}): Promise<T> {
  const res = await ai().models.generateContent({
    model: MODEL,
    contents: [{ role: "user", parts: opts.parts }],
    config: {
      systemInstruction: opts.system,
      responseMimeType: "application/json",
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      responseSchema: opts.schema as any,
      temperature: 0.4,
    },
  });
  const text = res.text ?? "{}";
  return JSON.parse(text) as T;
}

/// Free-form text generation (used for coaching chat).
export async function generateText(opts: {
  system: string;
  // Conversation turns: { role: "user" | "model", text }
  history: { role: "user" | "model"; text: string }[];
  temperature?: number;
}): Promise<string> {
  const res = await ai().models.generateContent({
    model: MODEL,
    contents: opts.history.map((h) => ({
      role: h.role,
      parts: [{ text: h.text }],
    })),
    config: {
      systemInstruction: opts.system,
      temperature: opts.temperature ?? 0.8,
    },
  });
  return res.text ?? "";
}

/// Fetch an image URL (e.g. a Cloud Storage download URL) and return it as an
/// inlineData Gemini part so the model can "see" the meal photo.
export async function imageUrlToPart(url: string): Promise<Part> {
  const resp = await fetch(url);
  if (!resp.ok) throw new Error(`Failed to fetch image: ${resp.status}`);
  const contentType = resp.headers.get("content-type") || "image/jpeg";
  const buf = Buffer.from(await resp.arrayBuffer());
  return {
    inlineData: {
      mimeType: contentType,
      data: buf.toString("base64"),
    },
  };
}
