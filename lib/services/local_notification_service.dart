import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as fln;
import 'package:logging/logging.dart';
import '../services/profile_metadata_service.dart';
import '../services/operator_icon_service.dart';
import '../utils/profile_tag_utils.dart';
import '../utils/iccid_formatter.dart';
import 'dart:math';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import '../utils/platform_adapter.dart';

class LocalNotificationService {
  static final LocalNotificationService _instance =
      LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final fln.FlutterLocalNotificationsPlugin _notificationsPlugin =
      fln.FlutterLocalNotificationsPlugin();
  final Logger _log = Logger('LocalNotificationService');
  bool _initialized = false;

  // Stream for notification taps
  final _payloadController = StreamController<String?>.broadcast();
  Stream<String?> get payloadStream => _payloadController.stream;

  // Stream for notifications received while in foreground
  final _foregroundNotificationController =
      StreamController<ForegroundNotification>.broadcast();
  Stream<ForegroundNotification> get foregroundNotificationStream =>
      _foregroundNotificationController.stream;

  Future<void> init() async {
    if (_initialized) return;

    const fln.AndroidInitializationSettings initializationSettingsAndroid =
        fln.AndroidInitializationSettings('@mipmap/ic_launcher');

    final fln.DarwinInitializationSettings initializationSettingsDarwin =
        fln.DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );

    // Required when targeting Windows, otherwise the plugin throws at runtime.
    //
    // Note: appUserModelId should be stable and match your app's identity.
    // guid can be any stable GUID (generate your own if you fork/rename).
    const fln.WindowsInitializationSettings initializationSettingsWindows =
        fln.WindowsInitializationSettings(
          appName: 'nlpa2',
          appUserModelId: 'ee.nekoko.nlpa2',
          guid: '5d6d4a8f-0b1f-4b8b-bd7b-8d7f9c9b5c2a',
        );

    // Harmless on Windows/macOS/iOS; useful if Linux desktop is enabled later.
    const fln.LinuxInitializationSettings initializationSettingsLinux =
        fln.LinuxInitializationSettings(defaultActionName: 'Open');

    final fln.InitializationSettings initializationSettings =
        fln.InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
          macOS: initializationSettingsDarwin,
          windows: initializationSettingsWindows,
          linux: initializationSettingsLinux,
        );

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        _log.info('Notification clicked: ${details.payload}');
        _payloadController.add(details.payload);
      },
    );

    _initialized = true;
    _log.info('LocalNotificationService initialized');
  }

  Future<bool> checkPermission() async {
    if (kIsWeb) return false;
    if (PlatformX.isIOS) {
      // Use permission_handler for status check first as it is more reliable for just checking
      final status = await Permission.notification.status;
      if (status.isGranted || status.isProvisional) {
        return true;
      }

      // Fallback: If not definitively granted, try requesting via the plugin
      if (PlatformX.isIOS) {
        final res = await _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              fln.IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
        return res ?? false;
      } else {
        final res = await _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              fln.MacOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
        return res ?? false;
      }
    } else if (PlatformX.isAndroid) {
      return await _notificationsPlugin
              .resolvePlatformSpecificImplementation<
                fln.AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    return true;
  }

  Future<void> scheduleTestReminder() async {
    try {
      if (!_initialized) await init();

      final profiles = await ProfileMetadataService.getInstance().then(
        (s) => s.getAllProfiles(),
      );
      if (profiles.isEmpty) {
        _log.warning('No profiles found for test reminder');
        return;
      }

      // Pick random profile
      final random = Random();
      final profile = profiles[random.nextInt(profiles.length)];

      // Find DateTag
      String content = "No date tag found";
      DateTag? dateTag;

      for (final tagStr in profile.tags) {
        final tag = ProfileTag.parse(tagStr);
        if (tag is DateTag) {
          dateTag = tag;
          content = tag.note ?? "Expiry Date: ${tag.displayDate}";
          break;
        }
      }

      // If no date tag, maybe fallback to text tag or generic
      if (dateTag == null) {
        for (final tagStr in profile.tags) {
          final tag = ProfileTag.parse(tagStr);
          if (tag is TextTag) {
            content = "Tag: ${tag.text}";
            break;
          }
        }
      }

      if (dateTag == null && content == "No date tag found") {
        content = "ICCID: ${IccidFormatter.forDisplay(profile.iccid)}";
      }

      // final scheduledTime = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5)); // Removed

      fln.AndroidNotificationDetails? androidDetails;

      // Fetch icon from OperatorIconService
      Uint8List? iconBytes;
      if (profile.mcc != null && profile.mnc != null) {
        final b64 = await OperatorIconService().getIcon(
          mcc: profile.mcc!,
          mnc: profile.mnc!,
          gid1: profile.gid1,
          gid2: profile.gid2,
        );
        if (b64 != null && b64.isNotEmpty) {
          try {
            iconBytes = base64Decode(b64);
          } catch (_) {}
        }
      }

      if (iconBytes != null) {
        final fln.ByteArrayAndroidBitmap largeIcon = fln.ByteArrayAndroidBitmap(
          iconBytes,
        );
        androidDetails = fln.AndroidNotificationDetails(
          'reminders_channel',
          'Tag Reminders',
          channelDescription: 'Reminders for eSIM expiry/events',
          importance: fln.Importance.max,
          priority: fln.Priority.high,
          largeIcon: largeIcon,
          styleInformation: fln.BigTextStyleInformation(content),
        );
      } else {
        androidDetails = fln.AndroidNotificationDetails(
          'reminders_channel',
          'Tag Reminders',
          channelDescription: 'Reminders for eSIM expiry/events',
          importance: fln.Importance.max,
          priority: fln.Priority.high,
          styleInformation: fln.BigTextStyleInformation(content),
        );
      }

      const fln.DarwinNotificationDetails iosDetails =
          fln.DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          );

      final fln.NotificationDetails platformDetails = fln.NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
        macOS: iosDetails,
      );

      // Use Future.delayed + show instead of zonedSchedule to avoid timezone dependency
      Future.delayed(const Duration(seconds: 5), () async {
        try {
          await _notificationsPlugin.show(
            id: random.nextInt(100000), // ID
            title: profile.displayName,
            body: content,
            notificationDetails: platformDetails,
            payload: jsonEncode({
              'iccid': profile.iccid,
              'eid': profile.eid ?? '',
            }),
          );
          _log.info('Showing test reminder for ${profile.displayName}');

          // Notify listeners for in-app display (foreground)
          _foregroundNotificationController.add(
            ForegroundNotification(
              title: profile.displayName,
              body: content,
              payload: jsonEncode({
                'iccid': profile.iccid,
                'eid': profile.eid ?? '',
              }),
            ),
          );
        } catch (e) {
          _log.severe('Failed to show delayed test reminder: $e');
        }
      });

      _log.info('Scheduled test reminder for ${profile.displayName} in 5s');
    } catch (e) {
      _log.severe('Failed to schedule test reminder: $e');
    }
  }

  void close() {
    _payloadController.close();
    _foregroundNotificationController.close();
  }
}

class ForegroundNotification {
  final String? title;
  final String? body;
  final String? payload;

  ForegroundNotification({this.title, this.body, this.payload});
}
