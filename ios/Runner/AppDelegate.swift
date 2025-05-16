import UIKit
import Flutter
import Speech
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, SFSpeechRecognizerDelegate {
  private var speechRecognizer: SFSpeechRecognizer?
  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private var recognitionTask: SFSpeechRecognitionTask?
  private var audioEngine: AVAudioEngine?
  private var channel: FlutterMethodChannel?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as! FlutterViewController
    channel = FlutterMethodChannel(name: "native_speech", binaryMessenger: controller.binaryMessenger)
    
    channel?.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }
      
      switch call.method {
      case "startListening":
        self.startListening(result: result)
      case "stopListening":
        self.stopListening(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func startListening(result: @escaping FlutterResult) {
    // Request authorization
    SFSpeechRecognizer.requestAuthorization { [weak self] status in
      guard let self = self else { return }
      
      DispatchQueue.main.async {
        switch status {
        case .authorized:
          self.setupSpeechRecognition(result: result)
        case .denied:
          result(FlutterError(code: "PERMISSION_DENIED",
                            message: "Speech recognition permission denied",
                            details: nil))
        case .restricted:
          result(FlutterError(code: "PERMISSION_RESTRICTED",
                            message: "Speech recognition not available on this device",
                            details: nil))
        case .notDetermined:
          result(FlutterError(code: "PERMISSION_NOT_DETERMINED",
                            message: "Speech recognition permission not determined",
                            details: nil))
        @unknown default:
          result(FlutterError(code: "UNKNOWN_ERROR",
                            message: "Unknown authorization status",
                            details: nil))
        }
      }
    }
  }
  
  private func setupSpeechRecognition(result: @escaping FlutterResult) {
    // Cancel any existing task
    recognitionTask?.cancel()
    recognitionTask = nil
    
    // Create and configure the speech recognizer
    speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    guard let speechRecognizer = speechRecognizer else {
      result(FlutterError(code: "RECOGNIZER_NOT_AVAILABLE",
                         message: "Speech recognizer not available",
                         details: nil))
      return
    }
    
    // Create and configure the audio engine
    audioEngine = AVAudioEngine()
    guard let audioEngine = audioEngine else {
      result(FlutterError(code: "AUDIO_ENGINE_NOT_AVAILABLE",
                         message: "Audio engine not available",
                         details: nil))
      return
    }
    
    // Create and configure the recognition request
    recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
    guard let recognitionRequest = recognitionRequest else {
      result(FlutterError(code: "RECOGNITION_REQUEST_NOT_AVAILABLE",
                         message: "Recognition request not available",
                         details: nil))
      return
    }
    recognitionRequest.shouldReportPartialResults = true
    
    // Configure the audio session
    let audioSession = AVAudioSession.sharedInstance()
    do {
      try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
      try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    } catch {
      result(FlutterError(code: "AUDIO_SESSION_ERROR",
                         message: "Failed to set up audio session: \(error.localizedDescription)",
                         details: nil))
      return
    }
    
    // Start the recognition task
    recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] (result, error) in
      guard let self = self else { return }
      
      if let error = error {
        self.channel?.invokeMethod("onError", arguments: error.localizedDescription)
        return
      }
      
      if let result = result {
        let transcript = result.bestTranscription.formattedString
        self.channel?.invokeMethod("onResult", arguments: transcript)
        
        if result.isFinal {
          self.stopListening(result: nil)
        }
      }
    }
    
    // Configure the audio input
    let inputNode = audioEngine.inputNode
    let recordingFormat = inputNode.outputFormat(forBus: 0)
    
    inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
      self?.recognitionRequest?.append(buffer)
    }
    
    // Start the audio engine
    do {
      try audioEngine.start()
      result(nil)
    } catch {
      result(FlutterError(code: "AUDIO_ENGINE_START_ERROR",
                         message: "Failed to start audio engine: \(error.localizedDescription)",
                         details: nil))
    }
  }
  
  private func stopListening(result: FlutterResult?) {
    audioEngine?.stop()
    audioEngine?.inputNode.removeTap(onBus: 0)
    recognitionRequest?.endAudio()
    recognitionTask?.cancel()
    
    audioEngine = nil
    recognitionRequest = nil
    recognitionTask = nil
    
    result?(nil)
  }
}
