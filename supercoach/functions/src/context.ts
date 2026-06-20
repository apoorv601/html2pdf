import { getFirestore, Timestamp } from "firebase-admin/firestore";

export interface TodayStats {
  caloriesIn: number;
  caloriesOut: number;
  calorieTarget: number;
  mealsLogged: string[];
  hasWorkout: boolean;
}

/// Loads a user's profile document as a plain object.
export async function loadProfile(
  uid: string
): Promise<Record<string, unknown>> {
  const snap = await getFirestore().doc(`users/${uid}`).get();
  return snap.data() ?? {};
}

/// Aggregates today's meals + workouts for coaching context / nudges.
export async function loadTodayStats(uid: string): Promise<TodayStats> {
  const db = getFirestore();
  const now = new Date();
  const start = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const end = new Date(start.getTime() + 24 * 60 * 60 * 1000);

  const [profileSnap, mealsSnap, workoutsSnap] = await Promise.all([
    db.doc(`users/${uid}`).get(),
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

  let caloriesIn = 0;
  const mealsLogged: string[] = [];
  for (const doc of mealsSnap.docs) {
    const d = doc.data();
    caloriesIn += (d.totalCalories as number) ?? 0;
    if (d.type) mealsLogged.push(d.type as string);
  }

  let caloriesOut = 0;
  for (const doc of workoutsSnap.docs) {
    caloriesOut += (doc.data().caloriesBurned as number) ?? 0;
  }

  return {
    caloriesIn,
    caloriesOut,
    calorieTarget: (profileSnap.data()?.dailyCalorieTarget as number) ?? 2000,
    mealsLogged,
    hasWorkout: !workoutsSnap.empty,
  };
}
