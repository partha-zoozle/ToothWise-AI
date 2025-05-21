import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:voice_to_text/app/data/models/appointment_model.dart';
import 'package:voice_to_text/app/data/models/service_model.dart';
import 'package:voice_to_text/app/data/providers/api_provider.dart';
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
  bool _userClosed = false;

  WebSocketChannel? _channel;
  final RxList<Map<String, dynamic>> chatMessages = <Map<String, dynamic>>[].obs;
  String _lastSentUserText = "";
  final RxList<Service> _services = <Service>[].obs;

  final AudioPlayer _audioPlayer = AudioPlayer();
  String _currentBotMessageBuffer = "";
  List<Uint8List> _audioQueue = []; // Queue for audio chunks
  bool _isPlayingQueue = false; // Flag to track if we're currently playing the queue
  String? _currentTempFilePathForIOS; // New property

  final ApiProvider _apiProvider = ApiProvider();
  final RxList<Service> services = <Service>[].obs;
  final Rx<AppointmentResponse?> currentAppointment = Rx<AppointmentResponse?>(null);
  final Rx<AvailableSlotsResponse?> availableSlots = Rx<AvailableSlotsResponse?>(null);
  
  // Animation controllers
  final RxString currentAnimation = ''.obs;
  final RxBool isAnimating = false.obs;

  // Animation paths for different services
  final Map<String, String> serviceAnimations = {
    'Teeth Cleaning': 'assets/animations/teeth_cleaning.json',
    'Tooth Filling': 'assets/animations/tooth_filling.json',
    'Root Canal': 'assets/animations/teeth_whitening.json',
    'Tooth Extraction': 'assets/animations/teeth_whitening.json',
    'Teeth Whitening': 'assets/animations/teeth_whitening.json',
  };

  // Animation paths for appointment status
  final Map<String, String> appointmentAnimations = {
    'confirmed': 'assets/animations/appointment_confirmed.json',
    'cancelled': 'assets/animations/appointment_cancelled.json',
    'rescheduled': 'assets/animations/appointment_rescheduled.json',
  };

  // Animation paths for loading states
  final Map<String, String> loadingAnimations = {
    'default': 'assets/animations/loading.json',
  };

  final RxBool showServiceListInChat = false.obs;
  final RxBool showFullScreenStatusAnimation = false.obs;

  @override
  void onInit() {
    super.onInit();
    _configureAudioPlayer();
    _requestMicrophonePermission();
    _initWebSocket();
    _loadServices();
    NativeSpeech.setResultHandler((dynamic arg1, [dynamic arg2]) {
      String text;
      bool isFinal;

      if (kDebugMode) print("VoiceController - setResultHandler invoked with: arg1=$arg1, arg2=$arg2");

      if (arg1 is Map) {
        text = arg1['text'] as String? ?? '';
        isFinal = arg1['isFinal'] as bool? ?? true;
        if (kDebugMode) print("VoiceController - Parsed from Map: text='$text', isFinal=$isFinal");
      } else if (arg1 is String && arg2 is bool) {
        text = arg1;
        isFinal = arg2;
        if (kDebugMode) print("VoiceController - Parsed from String, Bool: text='$text', isFinal=$isFinal");
      } else if (arg1 is String) {
        text = arg1;
        isFinal = true;
        if (kDebugMode) print("VoiceController - Parsed from String (assumed final): text='$text'");
      } else {
        if (kDebugMode) print("VoiceController - setResultHandler: Unexpected argument structure. Skipping.");
        return;
      }

      if (text.isEmpty && !isFinal) {
        if (kDebugMode) print("VoiceController - Received empty partial text. Ignoring.");
        return;
      }

      recognizedText.value = text;
      if (kDebugMode) {
        print("FlutterVoiceController - Processed text: '$text' (isFinal: $isFinal)");
      }

      if (isFinal) {
        if (kDebugMode) print("VoiceController - Result is FINAL. Checking if text is new: '${text.trim()}' vs '${_lastSentUserText.trim()}'");
        if (text.trim().isNotEmpty && text.trim() != _lastSentUserText.trim()) {
          if (kDebugMode) print("VoiceController - Condition MET: Sending message to WebSocket.");
          _sendMessage(text.trim());
          _lastSentUserText = text.trim();
        } else if (text.trim().isEmpty && _lastSentUserText.isNotEmpty) {
          if (kDebugMode) print("VoiceController - Final text is empty, last sent was not. Not sending empty, but updating lastSentUserText to empty.");
          _lastSentUserText = "";
        } else {
          if (kDebugMode) print("VoiceController - Condition NOT MET: Final text is empty or same as last sent. Not sending.");
        }
      } else {
        if (kDebugMode) print("FlutterVoiceController - Partial result, not sending to WebSocket: '$text'");
      }
    });

    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      if (kDebugMode) print("AudioPlayer state CHANGED to: $state. Current isBotAudioPlaying: [38;5;10m${isBotAudioPlaying.value}, isListening: ${isListening.value}");
      final bool oldIsBotAudioPlaying = isBotAudioPlaying.value;

      if (state == PlayerState.playing) {
        isBotAudioPlaying.value = true;
      } else if (state == PlayerState.completed) {
        isBotAudioPlaying.value = false;
        _isPlayingQueue = false;
        _playNextInQueue(); // Try to play next audio in queue
      } else {
        isBotAudioPlaying.value = false; // Covers stopped, failed, paused
      }

      if (oldIsBotAudioPlaying != isBotAudioPlaying.value) {
         if (kDebugMode) print("isBotAudioPlaying changed from $oldIsBotAudioPlaying to ${isBotAudioPlaying.value}. Triggering UI/mic updates.");
         _manageNativeSpeechBasedOnStates();
      }
      
      // If playback has finished (completed or stopped) and the bot is not currently playing audio
      if ((state == PlayerState.completed || state == PlayerState.stopped) && !isBotAudioPlaying.value) {
          if (kDebugMode) print("Audio playback ended, re-enabling listening if not user closed.");
          // Only restart listening if the user hasn't explicitly closed the session
          if (!_userClosed && !isListening.value) {
            isListening.value = true;
            if (kDebugMode) print("isListening set to true after audio playback, user did not close.");
          } else if (_userClosed) {
            if (kDebugMode) print("User has closed the session, not restarting listening.");
          }
          _manageNativeSpeechBasedOnStates();
      }
    });

    // SINGLE onPlayerComplete listener
    _audioPlayer.onPlayerComplete.listen((_) {
      if (kDebugMode) print("AudioPlayer - onPlayerComplete triggered.");
      if (Platform.isIOS && _currentTempFilePathForIOS != null) {
        final fileToDelete = File(_currentTempFilePathForIOS!);
        if (kDebugMode) print("AudioPlayer - Attempting to delete iOS temp file: ${fileToDelete.path}");
        fileToDelete.exists().then((exists) {
          if (exists) {
            fileToDelete.delete().then((_) {
              if (kDebugMode) print("AudioPlayer - Successfully deleted iOS temp file: ${fileToDelete.path}");
            }).catchError((e) {
              if (kDebugMode) print("AudioPlayer - Error deleting temp file AFTER existence check: $e");
              return null; // Handle Future error
            });
          } else {
            if (kDebugMode) print("AudioPlayer - iOS temp file no longer exists, skipping deletion: ${fileToDelete.path}");
          }
        }).catchError((e) {
            if (kDebugMode) print("AudioPlayer - Error checking file existence: $e");
            return null; // Handle Future error
        });
        _currentTempFilePathForIOS = null; // Clear the path after attempting deletion
      }
      // _isPlayingQueue is already set to false in onPlayerStateChanged for PlayerState.completed
      // _playNextInQueue() is also called from there.
      // We might still want to call _manageNativeSpeechBasedOnStates() here if the queue is now empty
      // and onPlayerStateChanged for 'completed' hasn't robustly handled it.
      if (_audioQueue.isEmpty && !_isPlayingQueue) {
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
          AVAudioSessionOptions.defaultToSpeaker,
          AVAudioSessionOptions.allowBluetooth,
          AVAudioSessionOptions.mixWithOthers,
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
      _manageNativeSpeechBasedOnStates(); // Ensure mic state is correct if queue is empty now
      return;
    }

    _isPlayingQueue = true;
    final audioBytes = _audioQueue.removeAt(0);
    _currentTempFilePathForIOS = null; // Reset before playing next

    try {
      if (Platform.isIOS) {
        final tempDir = await getTemporaryDirectory();
        // Use a consistent naming scheme or ensure uniqueness if truly needed,
        // but for playback, a single rotating temp file name is often fine.
        // For simplicity and to avoid conflicts with previous incomplete deletions:
        final tempFile = File('${tempDir.path}/current_ios_playback.wav'); 
        _currentTempFilePathForIOS = tempFile.path; // Store path

        await tempFile.writeAsBytes(audioBytes);
        await _audioPlayer.play(DeviceFileSource(tempFile.path));
        if (kDebugMode) print("Playing next audio chunk from queue (iOS file: ${tempFile.path}). Remaining chunks: ${_audioQueue.length}");
        // DO NOT add onPlayerComplete listener here anymore
      } else {
        // Android: play from bytes directly
        await _audioPlayer.play(BytesSource(audioBytes));
        if (kDebugMode) print("Playing next audio chunk from queue (Android bytes). Remaining chunks: ${_audioQueue.length}");
      }
    } catch (e) {
      if (kDebugMode) print("Error playing audio from queue: $e");
      _isPlayingQueue = false;
      _currentTempFilePathForIOS = null; // Reset on error
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

    final url = 'ws://dockrec.zoozle.dev/ws/$userId?authorization=$accessToken';
    //final url = 'ws:///ws/$userId?authorization=$accessToken';
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
              
              // Process the buffered text to replace newlines and trim
              String processedText = _currentBotMessageBuffer.replaceAll('\n', ' ').trim();

              if (processedText.isNotEmpty) {
                chatMessages.add({
                  'sender': 'bot',
                  'text': processedText,
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
                
                // Handle appointment status updates
                if (serverMessage.containsKey('appointment_status')) {
                  final status = serverMessage['appointment_status'] as String;
                  final details = serverMessage['appointment_details'] as Map<String, dynamic>;
                  
                  // Update current appointment
                  currentAppointment.value = AppointmentResponse(
                    appointmentStatus: status,
                    appointmentDetails: AppointmentDetails(
                      appointmentId: details['appointment_id'],
                      slotStart: DateTime.parse(details['slot_start']),
                      slotEnd: DateTime.parse(details['slot_end']),
                      notes: details['notes'],
                      price: details['price'].toDouble(),
                      service: Service(
                        id: details['service']['service_id'],
                        name: details['service']['name'],
                        duration: details['service']['duration'],
                        price: details['service']['price'].toDouble(),
                        description: details['service']['description'],
                      ),
                    ),
                  );
                  
                  // Play the appropriate animation
                  playAppointmentStatusAnimation(status);
                }
            }

            if (serverMessage.containsKey('user_asked_to_list_services') && 
                serverMessage['user_asked_to_list_services'] == true) {
              print("hi inside this");
              showServiceListInChat.value = true;

              // If backend sends services, update; otherwise, use local or previously loaded services
              if (serverMessage.containsKey('services') && serverMessage['services'] is List) {
                _services.value = (serverMessage['services'] as List)
                    .map((service) => Service(
                          id: service['id'],
                          name: service['name'],
                          description: service['description'],
                          price: service['price'].toDouble(),
                          duration: service['duration'],
                        ))
                    .toList();
                services.value = _services; // keep in sync
              } else if (_services.isNotEmpty) {
                services.value = _services;
              } // else, you may want to load from API or show a fallback

              // Always add the chat message with showServices: true
              chatMessages.add({
                'sender': 'bot',
                'text': 'Here are our available services:',
                'timestamp': DateTime.now(),
                'showServices': true,
              });
            }

            if (serverMessage.containsKey('slots_available') && 
                serverMessage['slots_available'] is List &&
                (serverMessage['slots_available'] as List).isNotEmpty) {
              chatMessages.add({
                'sender': 'bot',
                'text': 'Here are the available time slots:',
                'timestamp': DateTime.now(),
                'showSlots': true,
                'slots': serverMessage['slots_available'],
              });
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
          
          // Process the buffered text to replace newlines and trim
          String processedText = _currentBotMessageBuffer.replaceAll('\n', ' ').trim();

          if (processedText.isNotEmpty) {
            chatMessages.add({
              'sender': 'bot',
              'text': '[Fragmented Text] $processedText',
              'timestamp': DateTime.now()
            });
          }
          _currentBotMessageBuffer = "";
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
    if (text.isEmpty) {
      if (kDebugMode) print("VoiceController - _sendMessage: Text is empty, not sending.");
      return;
    }

    if (kDebugMode) print("VoiceController - _sendMessage: Preparing to send text: '$text'");

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
      if (kDebugMode) print("VoiceController - _sendMessage: Message ADDED to WebSocket sink.");
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
    _userClosed = false; // Reset userClosed flag when starting to listen
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
    if (kDebugMode) print("User explicitly clicked stop/close.");
    _userClosed = true; // Set userClosed flag
    isListening.value = false;
    isWaitingForBot.value = false;
    isBotAudioPlaying.value = false;
    _audioPlayer.stop();
    _currentBotMessageBuffer = ""; 
    _audioQueue.clear();
    _isPlayingQueue = false;
    NativeSpeech.stopListening(); // Ensure native speech is told to stop
    if (kDebugMode) print("NativeSpeech.stopListening() called by stopListening(). isListening: ${isListening.value}");
  }

  @override
  void onClose() {
    _channel?.sink.close(); 
    _audioPlayer.dispose();
    super.onClose();
  }

  Future<void> _loadServices() async {
    try {
      final response = await _apiProvider.getServices();
      services.value = response.services;
      if (kDebugMode) print('Services loaded: ${services.length}');
    } catch (e) {
      if (kDebugMode) print('Error loading services: $e');
    }
  }

  void playServiceAnimation(String serviceName) {
    final animationPath = serviceAnimations[serviceName];
    if (animationPath != null) {
      _playAnimationWithTransition(animationPath);
    }
  }

  void playAppointmentStatusAnimation(String status) {
    final animationPath = appointmentAnimations[status];
    if (animationPath != null) {
      showFullScreenStatusAnimation.value = true;
      currentAnimation.value = animationPath;
      isAnimating.value = true;
      isLoading.value = false;

      // Hide after 4 seconds
      Future.delayed(const Duration(seconds: 4), () {
        showFullScreenStatusAnimation.value = false;
        isAnimating.value = false;
      });
    }
  }

  void _playAnimationWithTransition(String animationPath) {
    currentAnimation.value = loadingAnimations['default']!;
    isAnimating.value = true;
    isLoading.value = true;

    // After a short delay, show the actual animation
    Future.delayed(const Duration(milliseconds: 500), () {
      currentAnimation.value = animationPath;
      isLoading.value = false;

      // Hide animation after it completes
      Future.delayed(const Duration(seconds: 3), () {
        isAnimating.value = false;
      });
    });
  }

  Future<void> checkAppointmentStatus() async {
    try {
      isLoading.value = true;
      final response = await _apiProvider.getAppointmentStatus();
      currentAppointment.value = response;
      playAppointmentStatusAnimation(response.appointmentStatus);
    } catch (e) {
      if (kDebugMode) print('Error checking appointment status: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> getAvailableSlots({
    required String date,
    required String time,
    required int serviceId,
  }) async {
    try {
      isLoading.value = true;
      final response = await _apiProvider.getAvailableSlots(
        date: date,
        time: time,
        serviceId: serviceId,
      );
      availableSlots.value = response;
      // Play animation for the selected service
      final service = services.firstWhere((s) => s.id == serviceId);
      playServiceAnimation(service.name);
    } catch (e) {
      if (kDebugMode) print('Error getting available slots: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void sendBookingMessage({required String serviceName, required DateTime startTime, required DateTime endTime}) {
    final formattedTime = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')} - '
        '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
    final message = 'I want to book $serviceName at $formattedTime';
    _sendMessage(message);
  }
} 

