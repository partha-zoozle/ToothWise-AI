import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:voice_to_text/app/widgets/native_speech.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:path_provider/path_provider.dart';

final supabase = Supabase.instance.client;

class VoiceController extends GetxController {
  final RxBool isListening = false.obs;
  final RxString recognizedText = ''.obs;
  final RxBool isLoading = false.obs;
  final RxBool isWaitingForBot = false.obs;
  final RxBool isBotAudioPlaying = false.obs;

  WebSocketChannel? _channel;
  final RxList<Map<String, dynamic>> chatMessages = <Map<String, dynamic>>[].obs;
  String _lastSentUserText = "";

  final AudioPlayer _audioPlayer = AudioPlayer();
  String _currentBotMessageBuffer = "";
  List<Uint8List> _audioQueue = []; // Queue for audio chunks
  bool _isPlayingQueue = false; // Flag to track if we're currently playing the queue

  @override
  void onInit() {
    super.onInit();
    _configureAudioPlayer();
    _requestMicrophonePermission();
    _initWebSocket();
    NativeSpeech.setResultHandler((text) {
      if (text.isEmpty) return;

      recognizedText.value = text;
      if (kDebugMode) {
        print("FlutterVoiceController - Received text: $text");
      }
      if (text != _lastSentUserText) {
        _sendMessage(text);
        _lastSentUserText = text;
      } else {
        if (kDebugMode) {
          print("FlutterVoiceController - Duplicate text received, not sending: $text");
        }
      }
    });

    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      if (kDebugMode) print("AudioPlayer state CHANGED to: $state. Current isBotAudioPlaying: ${isBotAudioPlaying.value}, isListening: ${isListening.value}");
      final bool oldIsBotAudioPlaying = isBotAudioPlaying.value;

      if (state == PlayerState.playing) {
        isBotAudioPlaying.value = true;
      } else if (state == PlayerState.completed) {
        isBotAudioPlaying.value = false;
        _isPlayingQueue = false;
        _playNextInQueue(); // Try to play next audio in queue
      } else {
        isBotAudioPlaying.value = false;
      }

      if (oldIsBotAudioPlaying != isBotAudioPlaying.value) {
         if (kDebugMode) print("isBotAudioPlaying changed from $oldIsBotAudioPlaying to ${isBotAudioPlaying.value}. Triggering UI/mic updates.");
         _manageNativeSpeechBasedOnStates();
      }
      
      if ((state == PlayerState.completed || state == PlayerState.stopped) && isListening.value && !isBotAudioPlaying.value) {
          if (kDebugMode) print("Audio playback ended (state: $state), user is listening. Re-evaluating mic.");
          _manageNativeSpeechBasedOnStates();
      }
    });

    _audioPlayer.onLog.listen((log) {
      if (kDebugMode) {
        print("AudioPlayer Internal Log: $log");
      }
    });

    _audioPlayer.onDurationChanged.listen((Duration duration) {
      if (kDebugMode) {
        print("AudioPlayer: Duration changed to $duration. Current player state: ${_audioPlayer.state}");
      }
    });

    ever(isListening, (_) => _manageNativeSpeechBasedOnStates());
    ever(isBotAudioPlaying, (_) => _manageNativeSpeechBasedOnStates());
  }

  void _configureAudioPlayer() {
    _audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);
    AudioContext audioContext = AudioContext(
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playAndRecord,
        options: {
          AVAudioSessionOptions.mixWithOthers,
          AVAudioSessionOptions.defaultToSpeaker,
        },
      ),
      android: AudioContextAndroid(
        isSpeakerphoneOn: true,
        stayAwake: true,
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.media,
        audioFocus: AndroidAudioFocus.gain,
      ),
    );
    _audioPlayer.setAudioContext(audioContext);
    if (kDebugMode) print("AudioPlayer configured with custom AudioContext and mediaPlayer mode for speaker output.");
  }

  Future<void> _playNextInQueue() async {
    if (_audioQueue.isEmpty || _isPlayingQueue) {
      return;
    }

    _isPlayingQueue = true;
    final audioBytes = _audioQueue.removeAt(0);
    
    try {
      await _audioPlayer.play(BytesSource(audioBytes));
      if (kDebugMode) print("Playing next audio chunk from queue. Remaining chunks: ${_audioQueue.length}");
    } catch (e) {
      if (kDebugMode) print("Error playing audio from queue: $e");
      _isPlayingQueue = false;
      _playNextInQueue(); // Try next chunk if current one fails
    }
  }

  void _addToAudioQueue(Uint8List audioBytes) {
    _audioQueue.add(audioBytes);
    if (kDebugMode) print("Added audio chunk to queue. Queue length: ${_audioQueue.length}");
    
    if (!_isPlayingQueue) {
      _playNextInQueue();
    }
  }

  void _manageNativeSpeechBasedOnStates() {
    if (kDebugMode) print("Attempting to manage native speech: isListening=${isListening.value}, isBotAudioPlaying=${isBotAudioPlaying.value}");
    if (isListening.value) {
      if (isBotAudioPlaying.value) {
        if (kDebugMode) print("ManageNativeSpeech: User wants mic ON, Bot audio PLAYING. Stopping NativeSpeech.");
        NativeSpeech.stopListening();
      } else {
        if (kDebugMode) print("ManageNativeSpeech: User wants mic ON, Bot audio NOT playing. Attempting to start NativeSpeech.");
        NativeSpeech.stopListening(); 
        Future.delayed(const Duration(milliseconds: 300), () { // Slightly longer delay for robustness
          if(isListening.value && !isBotAudioPlaying.value) { 
             if (kDebugMode) print("ManageNativeSpeech: DELAYED check PASSED. Starting NativeSpeech.");
            NativeSpeech.startListening(); 
          } else {
            if (kDebugMode) print("ManageNativeSpeech: DELAYED check FAILED. Not starting. (isListening: ${isListening.value}, isBotAudioPlaying: ${isBotAudioPlaying.value})");
          }
        });
      }
    } else {
      if (kDebugMode) print("ManageNativeSpeech: User wants mic OFF. Stopping NativeSpeech.");
      NativeSpeech.stopListening();
    }
  }

  Future<void> _initWebSocket() async {
    final String? userId = supabase.auth.currentUser?.id;
    final String? accessToken = supabase.auth.currentSession?.accessToken;

    if (userId == null || accessToken == null) {
      if (kDebugMode) {
        print("WebSocket: User ID or Access Token is null. Cannot connect.");
      }
      return;
    }

    final url = 'ws://192.168.0.57:8001/ws/$userId?authorization=$accessToken';
    //final url = 'ws://dockrec.zoozle.dev/ws/$userId?authorization=$accessToken';
    if (kDebugMode) {
      print("Connecting to WebSocket: $url");
    }

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));

      final String greetingMessage = jsonEncode({
        "type": "message", 
        "content": "Client connected. Waiting for greeting."
      });
      _channel?.sink.add(greetingMessage);
      if (kDebugMode) print("WebSocket: Sent initial greeting message: $greetingMessage");

      _channel?.stream.listen(
        (message) {
          if (kDebugMode) {
            print('WebSocket: Raw Received message: $message');
          }
          try {
            final decodedJson = jsonDecode(message);
            if (decodedJson is! Map<String, dynamic>) {
              if (kDebugMode) print('WebSocket: Decoded message is not a Map');
              return;
            }

            final Map<String, dynamic> serverMessage = decodedJson;

            if (serverMessage.containsKey('end_call') && serverMessage['end_call'] == true) {
              Future.delayed(const Duration(milliseconds: 5000), () {
                if (kDebugMode) print("WebSocket: Received end_call instruction. Clearing chat and stopping session.");
                chatMessages.clear();
                _currentBotMessageBuffer = "";
                _audioQueue.clear();
                _isPlayingQueue = false;
                isListening.value = false;
                isWaitingForBot.value = false;
                if (_audioPlayer.state == PlayerState.playing) _audioPlayer.stop();
              });
            }

            if (chatMessages.isNotEmpty && 
                chatMessages.last['sender'] == 'system' && 
                chatMessages.last['text'] == 'Connecting to assistant...') {
                if(serverMessage.containsKey('message') || serverMessage.containsKey('audio')) {
                    chatMessages.removeLast();
                }
            }

            bool isBotMessagePartReceived = false;
            if (serverMessage.containsKey('message') && serverMessage['message'] is String) {
              _currentBotMessageBuffer += "${serverMessage['message'] as String} ";
              isBotMessagePartReceived = true;
            }

            if (serverMessage.containsKey('audio') && serverMessage['audio'] is String) {
              try {
                final String base64Audio = serverMessage['audio'] as String;
                if (base64Audio.isNotEmpty) {
                    final Uint8List decodedBytes = base64Decode(base64Audio);
                    if (decodedBytes.isNotEmpty) {
                        _addToAudioQueue(decodedBytes);
                        if (kDebugMode) print("Audio chunk added. Length: ${decodedBytes.length}, Total chunks: ${_audioQueue.length}. Start of data (hex): ${decodedBytes.sublist(0, (decodedBytes.length > 16 ? 16 : decodedBytes.length)).map((b) => b.toRadixString(16).padLeft(2, '0')).join()}");
                    } else {
                        if (kDebugMode) print("Decoded audio chunk empty.");
                    }
                } else {
                    if (kDebugMode) print("Received empty base64 audio.");
                }
              } catch (e) {
                if (kDebugMode) print("Error decoding audio: $e");
              }
              isBotMessagePartReceived = true;
            }
            
            if(isBotMessagePartReceived && isWaitingForBot.value){
            }

            if (serverMessage.containsKey('turn_complete') && serverMessage['turn_complete'] == true) {
              if (kDebugMode) print("Turn complete received. Buffered text: '${_currentBotMessageBuffer.trim()}', Buffered audio chunks: ${_audioQueue.length}");
              if (_currentBotMessageBuffer.trim().isNotEmpty) {
                chatMessages.add({
                  'sender': 'bot',
                  'text': _currentBotMessageBuffer.trim(),
                  'timestamp': DateTime.now()
                });
              }
              _currentBotMessageBuffer = ""; 
              isWaitingForBot.value = false;
              
              if (_audioQueue.isNotEmpty) {
                final bytesBuilder = BytesBuilder(copy: false);
                for (var buffer in _audioQueue) {
                  bytesBuilder.add(buffer);
                }
                final Uint8List consolidatedAudioBytes = bytesBuilder.toBytes();
                if (kDebugMode) print("CONSOLIDATED audio for playback. Total length: ${consolidatedAudioBytes.length}");
                _addToAudioQueue(consolidatedAudioBytes);
              } else {
                if (kDebugMode) print("Turn complete, but no audio was buffered for this turn.");
                _manageNativeSpeechBasedOnStates();
              }
            } else if (!serverMessage.containsKey('message') && 
                       !serverMessage.containsKey('audio') && 
                       !serverMessage.containsKey('turn_complete') &&
                       !serverMessage.containsKey('end_call')
                       ) {
                if (kDebugMode) {
                    print("WebSocket: Received message in unknown/other format: $serverMessage");
                }
            }
          } catch (e) {
            if (kDebugMode) print('WebSocket: Error decoding/processing: $e. Message: $message');
            isWaitingForBot.value = false;
          }
        },
        onError: (error) {
          if (kDebugMode) {
            print('WebSocket: Error: $error');
          }
          _channel = null; 
          isWaitingForBot.value = false;
          if(isBotAudioPlaying.value) isBotAudioPlaying.value = false; 
        },
        onDone: () {
          if (kDebugMode) {
            print('WebSocket: Connection closed.');
          }
          if (_currentBotMessageBuffer.trim().isNotEmpty) {
            chatMessages.add({
              'sender': 'bot',
              'text': '[Fragmented Text] ${_currentBotMessageBuffer.trim()}',
              'timestamp': DateTime.now()
            });
            _currentBotMessageBuffer = "";
          }
          _audioQueue.clear();
          _isPlayingQueue = false;
          _channel = null; 
          isWaitingForBot.value = false;
          if(isBotAudioPlaying.value) isBotAudioPlaying.value = false; 
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('WebSocket: Connection error: $e');
      }
       _channel = null;
       isWaitingForBot.value = false;
       if(isBotAudioPlaying.value) isBotAudioPlaying.value = false; 
    }
  }

  void _sendMessage(String text) {
    if (text.isEmpty) return;

    chatMessages.add({
      'sender': 'user',
      'text': text,
      'timestamp': DateTime.now()
    });
    _lastSentUserText = text;
    isWaitingForBot.value = true;

    if (_channel != null) {
      final message = jsonEncode({
        "type": "message",
        "content": text,
      });
      if (kDebugMode) {
        print('WebSocket: Sending message: $message');
      }
      _channel?.sink.add(message);
    } else {
      if (kDebugMode) {
        print('WebSocket: Channel not available. Message not sent.');
        isWaitingForBot.value = false;
        if (_channel == null) _initWebSocket(); 
      }
    }
  }

  Future<bool> _requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    if (kDebugMode) print("Microphone permission status: $status");
    return status.isGranted;
  }

  void startListening() {
    if (kDebugMode) print("User explicitly clicked start listening.");
    if (_channel == null) {
      if (kDebugMode) print('WebSocket: Channel not initialized. Attempting to initialize now.');
      _initWebSocket(); 
    } else {
      _currentBotMessageBuffer = "";
      _audioQueue.clear();
      _isPlayingQueue = false;
    }
    isListening.value = true;
    isWaitingForBot.value = false;
    _lastSentUserText = ""; 
    if (kDebugMode) print("NativeSpeech.startListening() called. isListening: ${isListening.value}");
  }

  void stopListening() {
    if (kDebugMode) print("User explicitly clicked stop listening.");
    isListening.value = false;
    isWaitingForBot.value = false;
    isBotAudioPlaying.value = false;
    _audioPlayer.stop();
    _currentBotMessageBuffer = ""; 
    _audioQueue.clear();
    _isPlayingQueue = false;
    if (kDebugMode) print("NativeSpeech.stopListening() called. isListening: ${isListening.value}");
  }

  @override
  void onClose() {
    _channel?.sink.close(); 
    _audioPlayer.dispose();
    super.onClose();
  }
} 

