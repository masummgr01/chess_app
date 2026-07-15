import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

class CallService {
  // TODO: Replace with your actual Agora App ID from console.agora.io
  static const String appId = "23d561f01c1e48df80f1fc086960cf4f";

  RtcEngine? _engine;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    // Request permissions required for Agora
    final statuses = await [
      Permission.microphone,
      Permission.camera,
      Permission.bluetoothConnect,
    ].request();

    if (statuses[Permission.microphone] != PermissionStatus.granted ||
        statuses[Permission.camera] != PermissionStatus.granted) {
      throw Exception("Microphone and Camera permissions are required for video calls.");
    }

    // Check Bluetooth Connect permission for Android 12+ (API 31+)
    if (statuses[Permission.bluetoothConnect] != PermissionStatus.granted) {
      debugPrint("Warning: BluetoothConnect permission not granted. Call audio might not route to headsets.");
    }

    debugPrint("Initializing Agora RTC engine...");
    if (_engine == null) {
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(const RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));
    }

    // Enable video and start local preview
    await _engine!.enableVideo();
    await _engine!.startPreview();

    _isInitialized = true;
  }

  RtcEngine get engine {
    if (_engine == null) throw Exception("CallService not initialized");
    return _engine!;
  }

  Future<void> joinChannel(String channelName, int uid) async {
    await init();
    await _engine!.joinChannel(
      token: '', // Use a temporary token or keep empty for testing (if enabled in Agora console)
      channelId: channelName,
      uid: uid,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishCameraTrack: true,
        publishMicrophoneTrack: true,
      ),
    );
  }

  Future<void> leaveChannel() async {
    if (!_isInitialized) return;
    await _engine?.leaveChannel();
    await _engine?.stopPreview();
    _isInitialized = false;
  }

  Future<void> dispose() async {
    _isInitialized = false;
    await _engine?.release();
    _engine = null;
  }
}
