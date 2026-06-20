import { initializeApp } from "firebase-admin/app";
import { setGlobalOptions } from "firebase-functions/v2";

initializeApp();
setGlobalOptions({ region: "us-central1", maxInstances: 10 });

export { estimateMeal } from "./estimateMeal";
export { estimateWorkout } from "./estimateWorkout";
export { coachChat } from "./coachChat";
export { onboardingTurn } from "./onboarding";
export { sendCoachNudges } from "./scheduler";
