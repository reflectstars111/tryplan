import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

enum AsrEngineType {
  none,
  localDevice,
}

class ASRService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechInitialized = false;
  String _localRecognizedText = '';
  AsrEngineType _activeEngine = AsrEngineType.none;
  String? _lastError;

  AsrEngineType get activeEngine => _activeEngine;
  String? get lastError => _lastError;

  Future<bool> hasPermission() async {
    return Permission.microphone.isGranted;
  }

  Future<bool> startListening() async {
    _lastError = null;
    final granted = await _ensureMicPermission();
    if (!granted) {
      _lastError = '麦克风权限未授予';
      return false;
    }
    _localRecognizedText = '';

    final localStarted = await _startLocalEngine();
    if (localStarted) {
      _activeEngine = AsrEngineType.localDevice;
      return true;
    }
    _activeEngine = AsrEngineType.none;
    return false;
  }

  Future<String?> stopAndRecognize() async {
    if (_activeEngine == AsrEngineType.localDevice) {
      try {
        await _speech.stop();
      } catch (_) {}
      final text = _localRecognizedText.trim();
      _activeEngine = AsrEngineType.none;
      return text.isEmpty ? null : text;
    }

    return null;
  }

  Future<bool> _startLocalEngine() async {
    try {
      if (_speech.isListening) {
        _activeEngine = AsrEngineType.localDevice;
        return true;
      }

      if (!_speechInitialized) {
        _speechInitialized = await _speech.initialize(
          onStatus: (status) {
            debugPrint('Local speech status: $status');
          },
          onError: (error) {
            debugPrint('Local speech error: ${error.errorMsg}');
            _lastError = '本地识别错误: ${error.errorMsg}';
          },
        );
      }

      if (!_speechInitialized) {
        _lastError = '本地识别初始化失败';
        return false;
      }

      if (_speech.isListening) {
        try {
          await _speech.stop();
        } catch (_) {}
      }

      await _speech.listen(
        localeId: 'zh_CN',
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          listenMode: stt.ListenMode.dictation,
        ),
        onResult: (result) {
          _localRecognizedText = result.recognizedWords;
        },
      );

      await Future.delayed(const Duration(milliseconds: 120));
      return _speech.isListening;
    } catch (e) {
      debugPrint('Error starting local speech: $e');
      _lastError = '本地识别启动失败: $e';
      return false;
    }
  }

  Future<bool> _ensureMicPermission() async {
    try {
      var status = await Permission.microphone.status;
      if (status.isGranted) return true;
      status = await Permission.microphone.request();
      if (status.isGranted) {
        await Future.delayed(const Duration(milliseconds: 120));
        return true;
      }
      return await hasPermission();
    } catch (_) {
      return await hasPermission();
    }
  }

  void dispose() {
    try {
      _speech.stop();
    } catch (_) {}
  }
}
