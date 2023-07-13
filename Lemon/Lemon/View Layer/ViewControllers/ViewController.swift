//
//  ViewController.swift
//  Lemon
//
//  Created by Andre Pham on 10/6/2023.
//

import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController, CaptureDelegate, HandDetectionDelegate, TagmataDetectionDelegate, LiveSpeechToTextDelegate {
    
    private var predictionInterval = 2
    private let captureSession = CaptureSession()
    private let synthesizer = SpeechSynthesizer()
    private let recognizer = SpeechRecognizer()
    private var tagmataDetector: DetectsTagmata = TagmataQuadrantDetector()
    private let detectionCompiler = DetectionCompiler()
    private let handDetector = HandDetector()
    private var activeHandDetection = HandDetectionOutcome()
    @WrapsToZero(threshold: 600) private var currentFrameID = 0
    private var overlayFrameSyncRequired = true
    private var isRecordingAudio = false
    
    private var root: LemonView { return LemonView(self.view) }
    private var image = LemonImage()
    private var predictionOverlay = PredictionBoxView()
    private var jointPositionsOverlay = JointPositionsView()
    private var proximityOverlay = ProximityView()
    private var anglesOverlay = AnglesView()
    private let stack = LemonVStack()
    private let buttonRowStack = LemonHStack()
    private let optionsStack = LemonVStack()
    private let speakButton = LemonIconButton()
    private let recordButton = LemonIconButton()
    private let flipButton = LemonIconButton()
    private let interruptButton = LemonIconButton()
    private let intervalSlider = LemonLabelledSlider()
    private let detectorSwitch = LemonLabelledSwitch()
    private let test = LemonIconButton()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupSubviews()
        self.setupObjectDetection()
        self.setupHandDetection()
        self.setupSpeechRecognition()
        self.setupSpeechSynthesizer()
        self.setupAndBeginCapturingVideoFrames()
        // Stop the device automatically sleeping
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    func setupSubviews() {
        // Video view
        self.root.addSubview(self.image)
        self.image.setFrame(to: self.root.frame)
        
        // Overlays
        self.image.addSubview(self.predictionOverlay)
        self.image.addSubview(self.anglesOverlay)
        self.image.addSubview(self.jointPositionsOverlay)
        self.image.addSubview(self.proximityOverlay)
        
        // Stack
        self.root.addSubview(self.stack)
        self.stack
            .constrainHorizontal()
            .constrainTop(padding: Environment.inst.topSafeAreaHeight)
            .constrainBottom(padding: Environment.inst.bottomSafeAreaHeight)
            .addView(self.buttonRowStack)
            .addView(self.optionsStack)
            .addSpacer()
            
        // Options stack
        self.stack.addSubview(self.optionsStack)
        self.optionsStack
            .constrainHorizontal(padding: 24)
            .setBackgroundColor(to: UIColor.white.withAlphaComponent(0.6))
            .setCornerRadius(to: 20)
            .setPaddingVertical(to: 16)
            .setSpacing(to: 8)
            .addView(self.buttonRowStack)
            .addView(self.intervalSlider)
            .addView(self.detectorSwitch)
        
        // Button row stack
        self.buttonRowStack
            .constrainHorizontal(padding: 24)
            .setDistribution(to: .equalSpacing)
            .addView(self.speakButton)
            .addView(self.recordButton)
            .addView(self.flipButton)
            .addView(self.interruptButton)
        
        // Speak button
        self.speakButton
            .setIcon(to: "waveform")
            .setOnTap({
                self.synthesizer.speak("Hello Lemon! Filler text is text that shares some characteristics of a real written text, but is random or otherwise generated. It may be used to display a sample of fonts, generate text for testing, or to spoof an e-mail spam filter.")
            })
        
        // Record button
        self.recordButton
            .setIcon(to: "record.circle")
            .setOnTap({
                self.toggleAudioRecording()
            })
        
        // Flip button
        self.flipButton
            .setIcon(to: "arrow.clockwise.circle")
            .setOnTap({
                self.flipCamera()
            })
        
        // Interrupt button
        self.interruptButton
            .setIcon(to: "xmark.circle.fill")
            .setOnTap({
                self.synthesizer.stopSpeaking()
            })
            .setAccessibilityLabel(to: "STOP")
        
        // Interval slider
        self.intervalSlider
            .constrainHorizontal(padding: 24)
            .setPadding(top: 8)
        self.intervalSlider.stack
            .setSpacing(to: 16)
        self.intervalSlider.labelText
            .setText(to: "Interval")
            .setPadding(right: 30)
        self.intervalSlider.slider
            .setValues(minimumValue: 1, maximumValue: 60, value: self.predictionInterval)
            .setRoundToNearest(1)
            .setOnDrag({ value in
                self.predictionInterval = Int(value)
            })
        
        // Detector switch
        self.detectorSwitch
            .constrainHorizontal(padding: 24)
        self.detectorSwitch.labelText
            .setText(to: "Alternate Model")
        self.detectorSwitch.switchView
            .setOnFlick({ isOn in
                if isOn {
                    self.tagmataDetector = TagmataDetector()
                } else {
                    self.tagmataDetector = TagmataQuadrantDetector()
                }
                self.setupObjectDetection()
            })
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.captureSession.stopCapturing {
            super.viewWillDisappear(animated)
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        // React to change in device orientation
        self.setupAndBeginCapturingVideoFrames()
        self.overlayFrameSyncRequired = true
    }
    
    override func viewDidLayoutSubviews() {
        self.overlayFrameSyncRequired = true
    }
    
    private func setVideoImage(to image: CGImage) {
        self.image.setImage(image)
        if self.overlayFrameSyncRequired {
            self.matchOverlayFrame()
            self.overlayFrameSyncRequired = false
        }
    }
    
    private func matchOverlayFrame() {
        let overlaySize = self.image.imageSize
        var overlayFrame = CGRect(origin: CGPoint(), size: overlaySize).scale(toAspectFillSize: self.image.frame.size)
        // Align overlay frame center to view center
        overlayFrame.origin.x += self.image.frame.center.x - overlayFrame.center.x
        overlayFrame.origin.y += self.image.frame.center.y - overlayFrame.center.y
        self.predictionOverlay.setFrame(to: overlayFrame)
        self.jointPositionsOverlay.setFrame(to: overlayFrame)
        self.proximityOverlay.setFrame(to: overlayFrame)
        self.anglesOverlay.setFrame(to: overlayFrame)
    }
    
    private func setupAndBeginCapturingVideoFrames() {
        self.captureSession.setUpAVCapture { error in
            if let error {
                assertionFailure("Failed to setup camera: \(error)")
                return
            }
            
            self.captureSession.captureDelegate = self
            self.captureSession.startCapturing()
        }
    }
    
    private func setupObjectDetection() {
        self.tagmataDetector.objectDetectionDelegate = self
    }
    
    private func setupHandDetection() {
        self.handDetector.handDetectionDelegate = self
    }
    
    private func setupSpeechRecognition() {
        self.recognizer.liveSpeechToTextDelegate = self
    }
    
    private func setupSpeechSynthesizer() {
        self.synthesizer.didFinishDelegate = {
//            self.recognizer.startTranscribing() // FLIP
        }
    }
    
    private func toggleAudioRecording() {
        self.isRecordingAudio.toggle()
        if self.isRecordingAudio {
            self.recordButton.setIcon(to: "record.circle.fill")
            self.recognizer.resetTranscript()
            self.recognizer.startTranscribing()
        } else {
            self.recordButton.setIcon(to: "record.circle")
            self.recognizer.stopTranscribing()
            print(self.recognizer.transcript)
        }
    }
    
    private func flipCamera() {
        self.captureSession.flipCamera { error in
            if let error {
                assertionFailure("Failed to flip camera: \(error)")
                return
            }
        }
    }
    
    func onCapture(session: CaptureSession, frame: CGImage?) {
        if let frame {
            self.handDetector.makePrediction(on: frame)
            if self.currentFrameID%self.predictionInterval == 0 {
                self.tagmataDetector.makePrediction(on: frame)
            }
            
            self.setVideoImage(to: frame)
            
            self.currentFrameID += 1
        }
    }
    
    func onTagmataDetection(outcome: TagmataDetectionOutcome?) {
        if let outcome {
            self.predictionOverlay.drawBoxes(for: outcome)
            self.proximityOverlay.drawProximityJoints(tagmataDetectionOutcome: outcome, handDetectionOutcome: self.activeHandDetection)
            self.anglesOverlay.drawOverlay(for: outcome)
            self.detectionCompiler.addOutcome(outcome, handOutcome: self.activeHandDetection)
        }
        if self.detectionCompiler.newResultsReady {
            let results = self.detectionCompiler.retrieveResults()
            self.handleDetectionResults(results)
        }
    }
    
    func onHandDetection(outcome: HandDetectionOutcome?) {
        if let outcome {
            self.jointPositionsOverlay.drawJointPositions(for: outcome)
        }
        self.activeHandDetection = outcome ?? HandDetectionOutcome()
    }
    
    func onWordRecognition(currentTranscription: SpeechText) {
        if currentTranscription.contains("name") {
            self.loadedCommand = "name"
//            self.recognizer.stopTranscribing() // FLIP
            self.recognizer.resetTranscript()
        } else if currentTranscription.contains("information") {
            self.loadedCommand = "information"
//            self.recognizer.stopTranscribing() // FLIP
            self.recognizer.resetTranscript()
        }
//        if currentTranscription.contains("STOP") {
//            self.synthesizer.stopSpeaking()
//            self.recognizer.resetTranscript()
//        }
    }
    
    private var loadedCommand = ""
    
    func handleDetectionResults(_ results: CompiledResults) {
        if let tagmata = results.heldTagmata.first {
            if self.loadedCommand == "name" {
                self.loadedCommand = ""
                self.synthesizer.speak(tagmata.name)
            } else if self.loadedCommand == "information" {
                self.loadedCommand = ""
                self.synthesizer.speak(tagmata.description)
            }
        }
    }

}

