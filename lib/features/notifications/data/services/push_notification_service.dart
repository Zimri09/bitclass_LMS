import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/environment.dart';
import '../repositories/notification_repository.dart';
import 'push_topic_planner.dart';

const String _notificationChannelId = 'bitclass_updates';
const String _notificationChannelName = 'BitClass updates';
const String _pushBoxName = 'push_notifications';
const String _storedTopicsKey = 'fcm_topics';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

/// Initializes the native Firebase app before Flutter builds its widget tree.
Future<bool> initializeFirebaseMessaging() async {
  if (EnvironmentConfig.isDemoMode ||
      kIsWeb ||
      (defaultTargetPlatform != TargetPlatform.android &&
          defaultTargetPlatform != TargetPlatform.iOS)) {
    return false;
  }

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    return true;
  } catch (error, stackTrace) {
    debugPrint('Firebase Messaging initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
    return false;
  }
}

/// Owns FCM permissions, token persistence, topics, and message presentation.
class PushNotificationService with WidgetsBindingObserver {
  final NotificationRepository _notificationRepository;
  final SupabaseClient? _supabase;
  final FirebaseMessaging? _providedMessaging;
  final FlutterLocalNotificationsPlugin _localNotifications;
  final bool firebaseAvailable;
  final void Function(String location) onOpenLocation;

  Box<dynamic>? _box;
  String? _userId;
  String? _role;
  bool _initialized = false;
  bool _syncing = false;
  bool _syncRequested = false;
  RealtimeChannel? _membershipChannel;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedAppSubscription;

  PushNotificationService({
    required NotificationRepository notificationRepository,
    required this.firebaseAvailable,
    required this.onOpenLocation,
    SupabaseClient? supabase,
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _notificationRepository = notificationRepository,
       _supabase = EnvironmentConfig.isDemoMode
           ? null
           : (supabase ?? Supabase.instance.client),
       _providedMessaging = messaging,
       _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin();

  bool get isAvailable => firebaseAvailable && !EnvironmentConfig.isDemoMode;
  FirebaseMessaging get _messaging =>
      _providedMessaging ?? FirebaseMessaging.instance;

  Future<void> initialize() async {
    if (_initialized || !isAvailable) {
      return;
    }
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
    _box = await Hive.openBox<dynamic>(_pushBoxName);

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        final location = response.payload;
        if (location != null && location.startsWith('/')) {
          onOpenLocation(location);
        }
      },
    );

    const channel = AndroidNotificationChannel(
      _notificationChannelId,
      _notificationChannelName,
      description: 'Lessons, assignments, discussions, and course updates.',
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      _showForegroundNotification,
    );
    _openedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _openMessage,
    );
    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen(
      _handleTokenRefresh,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('FCM token refresh failed: $error');
      },
    );

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      scheduleMicrotask(() => _openMessage(initialMessage));
    }
  }

  Future<bool> requestPermission() async {
    if (!isAvailable) {
      return false;
    }
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<void> activateUser({
    required String userId,
    required String role,
  }) async {
    if (!isAvailable) {
      return;
    }
    await initialize();

    if (_userId != null && _userId != userId) {
      await deactivateUser(deleteFirebaseToken: false);
    }
    _userId = userId;
    _role = role;
    await _watchMembershipChanges(userId);
    await synchronize();
  }

  Future<void> synchronize() async {
    if (!isAvailable || _userId == null || _role == null) {
      return;
    }
    if (_syncing) {
      _syncRequested = true;
      return;
    }

    _syncing = true;
    try {
      do {
        _syncRequested = false;
        await _synchronizeOnce();
      } while (_syncRequested);
    } finally {
      _syncing = false;
    }
  }

  Future<void> _synchronizeOnce() async {
    final userId = _userId;
    final role = _role;
    if (userId == null || role == null) {
      return;
    }

    final settings = await _notificationRepository.getSettings(userId);
    final permissionGranted = settings.pushEnabled
        ? await requestPermission()
        : false;

    if (settings.pushEnabled && permissionGranted) {
      await _messaging.setAutoInitEnabled(true);
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _registerToken(token);
      }
    }

    final courseIds = settings.pushEnabled && permissionGranted
        ? await _loadCourseIds(userId, role)
        : const <String>[];
    final desiredTopics = permissionGranted
        ? PushTopicPlanner.topicsFor(
            role: role,
            courseIds: courseIds,
            settings: settings,
          )
        : const <String>{};
    await _reconcileTopics(desiredTopics);
  }

  Future<List<String>> _loadCourseIds(String userId, String role) async {
    if (_supabase == null) {
      return const <String>[];
    }

    if (role == 'student') {
      final rows = await _supabase
          .from('enrollments')
          .select('course_id')
          .eq('user_id', userId);
      return (rows as List<dynamic>)
          .map((row) => (row as Map<String, dynamic>)['course_id'] as String)
          .toList();
    }

    if (role == 'instructor' || role == 'admin') {
      final rows = await _supabase
          .from('courses')
          .select('id')
          .eq('instructor_id', userId);
      return (rows as List<dynamic>)
          .map((row) => (row as Map<String, dynamic>)['id'] as String)
          .toList();
    }

    return const <String>[];
  }

  Future<void> _registerToken(String token) async {
    if (_userId == null) {
      return;
    }

    await _notificationRepository.registerDeviceToken(
      token: token,
      platform: _platformName,
      timezoneOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
    );
  }

  Future<void> _handleTokenRefresh(String token) async {
    if (_userId == null) {
      return;
    }
    await _registerToken(token);
    // A new app registration needs its topic set restored.
    await _reconcileTopics(const <String>{}, clearStoredFirst: true);
    await synchronize();
  }

  Future<void> _reconcileTopics(
    Set<String> desiredTopics, {
    bool clearStoredFirst = false,
  }) async {
    final stored = clearStoredFirst
        ? <String>{}
        : ((_box?.get(_storedTopicsKey) as List<dynamic>?) ?? const [])
              .cast<String>()
              .toSet();

    for (final topic in stored.difference(desiredTopics)) {
      await _messaging.unsubscribeFromTopic(topic);
    }
    for (final topic in desiredTopics.difference(stored)) {
      await _messaging.subscribeToTopic(topic);
    }
    await _box?.put(_storedTopicsKey, desiredTopics.toList()..sort());
  }

  Future<void> _watchMembershipChanges(String userId) async {
    final existingChannel = _membershipChannel;
    if (existingChannel != null) {
      await _supabase?.removeChannel(existingChannel);
    }
    if (_supabase == null) {
      return;
    }

    _membershipChannel = _supabase
        .channel('push-memberships-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'enrollments',
          callback: (_) => _synchronizeSafely(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'courses',
          callback: (_) => _synchronizeSafely(),
        )
        .subscribe();
  }

  Future<void> deactivateUser({bool deleteFirebaseToken = true}) async {
    if (!isAvailable) {
      return;
    }

    // Reset in-memory ownership before any Firebase or network call can wait.
    _userId = null;
    _role = null;
    _syncRequested = false;

    final channel = _membershipChannel;
    _membershipChannel = null;
    final topics = ((_box?.get(_storedTopicsKey) as List<dynamic>?) ?? const [])
        .cast<String>();
    final token = await _messaging.getToken();

    if (channel != null) {
      await _supabase?.removeChannel(channel);
    }

    for (final topic in topics) {
      await _messaging.unsubscribeFromTopic(topic);
    }
    await _box?.put(_storedTopicsKey, <String>[]);

    if (token != null) {
      try {
        await _notificationRepository.unregisterDeviceToken(token);
      } catch (error) {
        debugPrint('Could not remove the signed-out device token: $error');
      }
    }
    if (deleteFirebaseToken) {
      await _messaging.deleteToken();
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title']?.toString();
    final body = notification?.body ?? message.data['body']?.toString();
    if (title == null && body == null) {
      return;
    }

    await _localNotifications.show(
      id:
          (message.messageId ?? message.hashCode.toString()).hashCode &
          0x7fffffff,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _notificationChannelId,
          _notificationChannelName,
          channelDescription:
              'Lessons, assignments, discussions, and course updates.',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: _messageLocation(message),
    );
  }

  void _openMessage(RemoteMessage message) {
    final location = _messageLocation(message);
    if (location != null && location.startsWith('/')) {
      onOpenLocation(location);
    }
  }

  String? _messageLocation(RemoteMessage message) {
    return message.data['action_url']?.toString() ??
        message.data['actionUrl']?.toString();
  }

  String get _platformName {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'android';
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'ios';
    }
    return 'unknown';
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _synchronizeSafely();
    }
  }

  void _synchronizeSafely() {
    unawaited(
      synchronize().catchError((Object error, StackTrace stackTrace) {
        debugPrint('Push synchronization failed: $error');
      }),
    );
  }

  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    await _tokenRefreshSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _openedAppSubscription?.cancel();
    final channel = _membershipChannel;
    if (channel != null) {
      await _supabase?.removeChannel(channel);
    }
  }
}
