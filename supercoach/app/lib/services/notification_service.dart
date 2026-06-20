import 'package:firebase_messaging/firebase_messaging.dart';

/// Handles FCM permission + token. The actual scheduling of meal/workout
/// nudges happens server-side (Cloud Scheduler + Functions) so the coach can
/// reach the user even when the app is closed.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> init() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    // Foreground display options (iOS).
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  /// Returns the device FCM token so it can be saved to the user's profile.
  Future<String?> getToken() => _messaging.getToken();

  /// Token can rotate; callers should persist updates.
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;
}
