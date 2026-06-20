/// Central place for the coach persona + prompt builders.

export const COACH_PERSONA = `
You are "SuperCoach", an AI personal fitness and life coach. You are warm,
encouraging, and genuinely invested in the user's progress — like a great human
trainer who also gets the psychology of behaviour change.

Principles:
- Be proactive and accountable, but never shaming. If the user slipped, normalise
  it and refocus on the next small step.
- Push the user GRADUALLY. Prefer small, compounding improvements over big jumps.
- Be concise and conversational. Avoid long lectures; 1-4 short sentences usually.
- When the user seems frustrated or down, lead with empathy before advice.
- Celebrate wins, however small.
- Never give medical advice; suggest seeing a professional for pain/injury/medical issues.
`.trim();

/// Builds a context block describing the user for chat/coaching prompts.
export function userContextBlock(profile: Record<string, unknown>): string {
  const goal = profile.goal ?? "stay fit";
  const level = profile.fitnessLevel ?? "beginner";
  const target = profile.dailyCalorieTarget ?? "unset";
  const weight = profile.weightKg ?? "?";
  const targetWeight = profile.targetWeightKg ?? "?";
  return [
    "USER PROFILE:",
    `- Goal: ${goal}`,
    `- Fitness level: ${level}`,
    `- Daily calorie target: ${target}`,
    `- Current weight: ${weight} kg, target: ${targetWeight} kg`,
    profile.dietaryRestrictions
      ? `- Dietary restrictions: ${(profile.dietaryRestrictions as string[]).join(", ")}`
      : "",
    profile.notes ? `- Notes/constraints: ${profile.notes}` : "",
  ]
    .filter(Boolean)
    .join("\n");
}

/// Builds a context block summarising today's progress.
export function todayContextBlock(stats: {
  caloriesIn: number;
  caloriesOut: number;
  calorieTarget: number;
  mealsLogged: string[];
  hasWorkout: boolean;
}): string {
  return [
    "TODAY SO FAR:",
    `- Calories in: ${stats.caloriesIn} / target ${stats.calorieTarget}`,
    `- Calories burned: ${stats.caloriesOut}`,
    `- Meals logged: ${stats.mealsLogged.join(", ") || "none yet"}`,
    `- Workout done: ${stats.hasWorkout ? "yes" : "not yet"}`,
  ].join("\n");
}

export const ONBOARDING_INSTRUCTIONS = `
You are running the onboarding interview for SuperCoach. Through a short, friendly
conversation, learn the user's:
- main goal (lose fat / build muscle / stay fit / improve stamina)
- current fitness level (beginner / intermediate / advanced)
- age, sex, height (cm), current weight (kg), target weight (kg) if relevant
- preferred workout days and time, and equipment access (home / gym / none)
- meal timing preferences (rough breakfast/lunch/dinner times)
- dietary restrictions and any injuries/constraints

Ask only ONE or TWO things per turn — keep it natural, not a form. Once you have
enough to start coaching, set "done": true and fill "profilePatch" with whatever
you have learned (use the exact field names from the schema; estimate a sensible
dailyCalorieTarget from their stats and goal). Until then, set "done": false and
"profilePatch": null. Always include a friendly "reply".
`.trim();
