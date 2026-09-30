import Foundation
import Combine
import Speech
import AVFoundation

@MainActor
final class SpeechRecognitionService: ObservableObject {
    @Published var isRecording = false
    @Published var recognizedText = ""
    @Published var errorMessage: String?

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ru_RU"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    var isAvailable: Bool {
        speechRecognizer?.isAvailable == true
    }

    func requestPermissions() async -> Bool {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        let microphoneGranted = await AVAudioSession.sharedInstance().requestRecordPermissionAsync()

        if speechStatus != .authorized {
            errorMessage = "Нет доступа к распознаванию речи. Разрешите доступ в настройках iPhone."
            return false
        }

        if !microphoneGranted {
            errorMessage = "Нет доступа к микрофону. Разрешите доступ в настройках iPhone."
            return false
        }

        return true
    }

    func startRecording() async {
        errorMessage = nil
        recognizedText = ""

        guard await requestPermissions() else {
            return
        }

        guard let speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Голосовой ввод сейчас недоступен."
            return
        }

        stopRecording()

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let recognitionRequest else {
            errorMessage = "Не удалось создать запрос распознавания речи."
            return
        }

        recognitionRequest.shouldReportPartialResults = true

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            inputNode.removeTap(onBus: 0)
            inputNode.installTap(
                onBus: 0,
                bufferSize: 1024,
                format: recordingFormat
            ) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()

            isRecording = true

            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                Task { @MainActor in
                    guard let self else {
                        return
                    }

                    if let result {
                        self.recognizedText = result.bestTranscription.formattedString
                    }

                    if let error {
                        self.errorMessage = "Ошибка голосового ввода: \(error.localizedDescription)"
                        self.stopRecording()
                    }

                    if result?.isFinal == true {
                        self.stopRecording()
                    }
                }
            }
        } catch {
            errorMessage = "Не удалось включить микрофон: \(error.localizedDescription)"
            stopRecording()
        }
    }

    func stopRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }

        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        isRecording = false

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func toggleRecording() async {
        if isRecording {
            stopRecording()
        } else {
            await startRecording()
        }
    }
}

private extension AVAudioSession {
    func requestRecordPermissionAsync() async -> Bool {
        await withCheckedContinuation { continuation in
            requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}