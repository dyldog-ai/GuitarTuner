//
//  GuitarTunerShared.swift
//  Shared SwiftUI views and models for GuitarTuner
//

import SwiftUI
import Combine
import AVFoundation

// MARK: - Tuning Model

/// Represents a guitar string tuning
struct GuitarString: Identifiable, Hashable {
    let id = UUID()
    let note: String
    let frequency: Double
    let stringNumber: Int
    
    static let standardTuning: [GuitarString] = [
        GuitarString(note: "E", frequency: 82.41, stringNumber: 6),   // Low E
        GuitarString(note: "A", frequency: 110.00, stringNumber: 5),  // A
        GuitarString(note: "D", frequency: 146.83, stringNumber: 4),  // D
        GuitarString(note: "G", frequency: 196.00, stringNumber: 3),  // G
        GuitarString(note: "B", frequency: 246.94, stringNumber: 2),  // B
        GuitarString(note: "E", frequency: 329.63, stringNumber: 1),  // High E
    ]
    
    static let dropD: [GuitarString] = [
        GuitarString(note: "D", frequency: 73.42, stringNumber: 6),
        GuitarString(note: "A", frequency: 110.00, stringNumber: 5),
        GuitarString(note: "D", frequency: 146.83, stringNumber: 4),
        GuitarString(note: "G", frequency: 196.00, stringNumber: 3),
        GuitarString(note: "B", frequency: 246.94, stringNumber: 2),
        GuitarString(note: "E", frequency: 329.63, stringNumber: 1),
    ]
}

/// Tuning presets
enum TuningPreset: String, CaseIterable, Identifiable {
    case standard = "Standard (EADGBE)"
    case dropD = "Drop D (DADGBE)"
    case dropC = "Drop C (CGCFAD)"
    case openG = "Open G (DGDGBD)"
    case openD = "Open D (DADF#AD)"
    case dadgad = "DADGAD"
    case halfStepDown = "Half Step Down (Eb Ab Db Gb Bb Eb)"
    
    var id: String { rawValue }
    
    var strings: [GuitarString] {
        switch self {
        case .standard: return GuitarString.standardTuning
        case .dropD: return GuitarString.dropD
        case .dropC: return [
            GuitarString(note: "C", frequency: 65.41, stringNumber: 6),
            GuitarString(note: "G", frequency: 98.00, stringNumber: 5),
            GuitarString(note: "C", frequency: 130.81, stringNumber: 4),
            GuitarString(note: "F", frequency: 174.61, stringNumber: 3),
            GuitarString(note: "A", frequency: 220.00, stringNumber: 2),
            GuitarString(note: "D", frequency: 293.66, stringNumber: 1),
        ]
        case .openG: return [
            GuitarString(note: "D", frequency: 73.42, stringNumber: 6),
            GuitarString(note: "G", frequency: 98.00, stringNumber: 5),
            GuitarString(note: "D", frequency: 146.83, stringNumber: 4),
            GuitarString(note: "G", frequency: 196.00, stringNumber: 3),
            GuitarString(note: "B", frequency: 246.94, stringNumber: 2),
            GuitarString(note: "D", frequency: 293.66, stringNumber: 1),
        ]
        case .openD: return [
            GuitarString(note: "D", frequency: 73.42, stringNumber: 6),
            GuitarString(note: "A", frequency: 110.00, stringNumber: 5),
            GuitarString(note: "D", frequency: 146.83, stringNumber: 4),
            GuitarString(note: "F#", frequency: 185.00, stringNumber: 3),
            GuitarString(note: "A", frequency: 220.00, stringNumber: 2),
            GuitarString(note: "D", frequency: 293.66, stringNumber: 1),
        ]
        case .dadgad: return [
            GuitarString(note: "D", frequency: 73.42, stringNumber: 6),
            GuitarString(note: "A", frequency: 110.00, stringNumber: 5),
            GuitarString(note: "D", frequency: 146.83, stringNumber: 4),
            GuitarString(note: "G", frequency: 196.00, stringNumber: 3),
            GuitarString(note: "A", frequency: 220.00, stringNumber: 2),
            GuitarString(note: "D", frequency: 293.66, stringNumber: 1),
        ]
        case .halfStepDown: return [
            GuitarString(note: "Eb", frequency: 77.78, stringNumber: 6),
            GuitarString(note: "Ab", frequency: 103.83, stringNumber: 5),
            GuitarString(note: "Db", frequency: 138.59, stringNumber: 4),
            GuitarString(note: "Gb", frequency: 185.00, stringNumber: 3),
            GuitarString(note: "Bb", frequency: 233.08, stringNumber: 2),
            GuitarString(note: "Eb", frequency: 311.13, stringNumber: 1),
        ]
        }
    }
}

// MARK: - Tuner Engine

/// Protocol for audio input and pitch detection
protocol TunerEngineDelegate: AnyObject {
    func tunerEngine(_ engine: TunerEngine, didDetectPitch frequency: Double, amplitude: Float)
    func tunerEngine(_ engine: TunerEngine, didUpdateState state: TunerEngine.State)
    func tunerEngine(_ engine: TunerEngine, didEncounterError error: Error)
}

/// Audio engine for real-time pitch detection using AVAudioEngine
@MainActor
final class TunerEngine: ObservableObject {
    enum State: Equatable {
        case idle
        case requestingPermission
        case listening
        case error(String)
    }
    
    @Published private(set) var state: State = .idle
    @Published private(set) var detectedFrequency: Double = 0
    @Published private(set) var amplitude: Float = 0
    @Published private(set) var closestNote: String = "--"
    @Published private(set) var centsOff: Double = 0
    @Published private(set) var isInTune: Bool = false
    
    weak var delegate: TunerEngineDelegate?
    
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var pitchDetector: PitchDetector?
    
    // Audio settings
    private let sampleRate: Double = 44100
    private let bufferSize: AVAudioFrameCount = 4096
    
    // Pitch detection parameters
    private let minFrequency: Double = 50.0
    private let maxFrequency: Double = 500.0
    private let minAmplitude: Float = 0.02
    
    // Reference A4 = 440Hz
    private let a4Frequency: Double = 440.0
    
    init() {
        setupAudioSession()
    }
    
    deinit {
        stopListening()
    }
    
    private func setupAudioSession() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers, .allowBluetooth])
            try session.setActive(true)
        } catch {
            state = .error("Audio session setup failed: \(error.localizedDescription)")
            delegate?.tunerEngine(self, didEncounterError: error)
        }
        #elseif os(macOS)
        // macOS doesn't require explicit audio session setup
        #endif
    }
    
    func startListening() {
        guard state != .listening else { return }
        
        #if os(iOS)
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            Task { @MainActor in
                if granted {
                    self?.startAudioEngine()
                } else {
                    self?.state = .error("Microphone permission denied")
                    self?.delegate?.tunerEngine(self!, didEncounterError: NSError(domain: "TunerEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: "Microphone permission denied"]))
                }
            }
        }
        state = .requestingPermission
        #elseif os(macOS)
        startAudioEngine()
        #endif
    }
    
    private func startAudioEngine() {
        audioEngine = AVAudioEngine()
        inputNode = audioEngine?.inputNode
        
        guard let audioEngine = audioEngine,
              let inputNode = inputNode else {
            state = .error("Failed to create audio engine")
            return
        }
        
        let format = inputNode.outputFormat(forBus: 0)
        
        pitchDetector = PitchDetector(sampleRate: sampleRate, bufferSize: bufferSize)
        
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            state = .listening
            delegate?.tunerEngine(self, didUpdateState: .listening)
        } catch {
            state = .error("Failed to start audio engine: \(error.localizedDescription)")
            delegate?.tunerEngine(self, didEncounterError: error)
        }
    }
    
    func stopListening() {
        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)
        audioEngine = nil
        inputNode = nil
        pitchDetector = nil
        
        detectedFrequency = 0
        amplitude = 0
        closestNote = "--"
        centsOff = 0
        isInTune = false
        
        if state != .idle {
            state = .idle
            delegate?.tunerEngine(self, didUpdateState: .idle)
        }
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let pitchDetector = pitchDetector,
              let channelData = buffer.floatChannelData?[0] else { return }
        
        let frameLength = Int(buffer.frameLength)
        let amplitude = calculateRMS(channelData, frameLength: frameLength)
        
        guard amplitude > minAmplitude else {
            DispatchQueue.main.async { [weak self] in
                self?.amplitude = amplitude
                self?.detectedFrequency = 0
                self?.closestNote = "--"
                self?.centsOff = 0
                self?.isInTune = false
            }
            return
        }
        
        let frequency = pitchDetector.detectPitch(channelData, frameLength: frameLength)
        
        guard frequency >= minFrequency && frequency <= maxFrequency else {
            DispatchQueue.main.async { [weak self] in
                self?.amplitude = amplitude
            }
            return
        }
        
        let (note, cents) = frequencyToNote(frequency)
        let inTune = abs(cents) < 5.0 // Within 5 cents is "in tune"
        
        DispatchQueue.main.async { [weak self] in
            self?.detectedFrequency = frequency
            self?.amplitude = amplitude
            self?.closestNote = note
            self?.centsOff = cents
            self?.isInTune = inTune
            self?.delegate?.tunerEngine(self!, didDetectPitch: frequency, amplitude: amplitude)
        }
    }
    
    private func calculateRMS(_ data: UnsafeMutablePointer<Float>, frameLength: Int) -> Float {
        var sum: Float = 0
        for i in 0..<frameLength {
            sum += data[i] * data[i]
        }
        return sqrt(sum / Float(frameLength))
    }
    
    private func frequencyToNote(_ frequency: Double) -> (String, Double) {
        // A4 = 440Hz = MIDI note 69
        let midiNote = 69 + 12 * log2(frequency / a4Frequency)
        let roundedMidiNote = round(midiNote)
        let centsOff = (midiNote - roundedMidiNote) * 100
        
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let noteIndex = Int(roundedMidiNote) % 12
        let octave = Int(roundedMidiNote) / 12 - 1
        
        let noteName = "\(noteNames[noteIndex])\(octave)"
        return (noteName, centsOff)
    }
    
    // Get the target frequency for a given string
    func targetFrequency(for string: GuitarString) -> Double {
        return string.frequency
    }
    
    // Calculate cents difference from target
    func centsFromTarget(_ targetFrequency: Double) -> Double {
        guard detectedFrequency > 0 else { return 0 }
        return 1200 * log2(detectedFrequency / targetFrequency)
    }
}

// MARK: - Pitch Detector (Autocorrelation-based)

/// Simple autocorrelation-based pitch detector
final class PitchDetector {
    private let sampleRate: Double
    private let bufferSize: Int
    private var buffer: [Float]
    
    init(sampleRate: Double, bufferSize: Int) {
        self.sampleRate = sampleRate
        self.bufferSize = bufferSize
        self.buffer = Array(repeating: 0, count: bufferSize)
    }
    
    func detectPitch(_ data: UnsafeMutablePointer<Float>, frameLength: Int) -> Double {
        // Copy data to buffer
        for i in 0..<min(frameLength, bufferSize) {
            buffer[i] = data[i]
        }
        
        // Apply window function (Hanning)
        for i in 0..<bufferSize {
            let window = 0.5 * (1 - cos(2 * Double.pi * Double(i) / Double(bufferSize - 1)))
            buffer[i] *= Float(window)
        }
        
        // Autocorrelation
        var maxCorrelation: Float = 0
        var bestLag = 0
        
        let minLag = Int(sampleRate / 500.0)  // 500 Hz max
        let maxLag = Int(sampleRate / 50.0)   // 50 Hz min
        
        for lag in minLag...min(maxLag, bufferSize - 1) {
            var correlation: Float = 0
            let count = bufferSize - lag
            
            for i in 0..<count {
                correlation += buffer[i] * buffer[i + lag]
            }
            
            correlation /= Float(count)
            
            if correlation > maxCorrelation {
                maxCorrelation = correlation
                bestLag = lag
            }
        }
        
        // Parabolic interpolation for better accuracy
        if bestLag > 0 && bestLag < bufferSize - 1 {
            let y1 = autocorrelation(at: bestLag - 1)
            let y2 = autocorrelation(at: bestLag)
            let y3 = autocorrelation(at: bestLag + 1)
            
            let delta = (y3 - y1) / (2 * (2 * y2 - y1 - y3))
            let interpolatedLag = Double(bestLag) + delta
            
            if interpolatedLag > 0 {
                return sampleRate / interpolatedLag
            }
        }
        
        if bestLag > 0 {
            return sampleRate / Double(bestLag)
        }
        
        return 0
    }
    
    private func autocorrelation(at lag: Int) -> Float {
        guard lag < bufferSize else { return 0 }
        var sum: Float = 0
        let count = bufferSize - lag
        
        for i in 0..<count {
            sum += buffer[i] * buffer[i + lag]
        }
        
        return sum / Float(count)
    }
}

// MARK: - Tuner View Model

/// View model for the tuner UI
@MainActor
final class TunerViewModel: ObservableObject {
    @Published var engine = TunerEngine()
    @Published var selectedTuning: TuningPreset = .standard
    @Published var selectedStringIndex: Int = 0
    @Published var calibration: Double = 440.0 // A4 reference
    
    var currentString: GuitarString {
        selectedTuning.strings[selectedStringIndex]
    }
    
    var strings: [GuitarString] {
        selectedTuning.strings
    }
    
    var centsOff: Double {
        engine.centsFromTarget(currentString.frequency)
    }
    
    var isInTune: Bool {
        engine.isInTune && abs(centsOff) < 5.0
    }
    
    var isListening: Bool {
        engine.state == .listening
    }
    
    init() {
        engine.delegate = self
    }
    
    func toggleListening() {
        if engine.state == .listening {
            engine.stopListening()
        } else {
            engine.startListening()
        }
    }
    
    func selectString(_ index: Int) {
        selectedStringIndex = index
    }
    
    func setTuning(_ tuning: TuningPreset) {
        selectedTuning = tuning
    }
    
    func setCalibration(_ hz: Double) {
        calibration = hz
        engine.calibration = hz
    }
}

extension TunerViewModel: TunerEngineDelegate {
    func tunerEngine(_ engine: TunerEngine, didDetectPitch frequency: Double, amplitude: Float) {}
    
    func tunerEngine(_ engine: TunerEngine, didUpdateState state: TunerEngine.State) {
        objectWillChange.send()
    }
    
    func tunerEngine(_ engine: TunerEngine, didEncounterError error: Error) {
        // Error handling handled by published state
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Tuner View Components

/// Circular tuner display showing pitch accuracy
struct TunerDialView: View {
    let centsOff: Double
    let isInTune: Bool
    let targetNote: String
    let detectedNote: String
    let amplitude: Float
    
    private let maxCents: Double = 50
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: size / 2, y: size / 2)
            let radius = size * 0.4
            
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 4)
                    .frame(width: radius * 2, height: radius * 2)
                
                // Center marker
                Circle()
                    .fill(isInTune ? Color.green : Color.white.opacity(0.3))
                    .frame(width: 12, height: 12)
                    .position(center)
                
                // Needle indicator
                NeedleShape()
                    .fill(isInTune ? Color.green : (abs(centsOff) < 15 ? Color.yellow : Color.red))
                    .frame(width: 4, height: radius * 0.8)
                    .offset(y: -radius * 0.4)
                    .rotationEffect(.degrees(needleAngle))
                    .position(center)
                    .animation(.spring(response: 0.15, dampingFraction: 0.8), value: centsOff)
                
                // Center dot
                Circle()
                    .fill(Color.white)
                    .frame(width: 8, height: 8)
                    .position(center)
                
                // Note labels
                VStack(spacing: 4) {
                    Text(detectedNote)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(targetNote)
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                    Text("\(centsOff >= 0 ? "+" : "")\(Int(centsOff))¢")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(centsColor)
                        .monospacedDigit()
                }
                .position(x: center.x, y: center.y + radius * 1.3)
                
                // Tick marks
                ForEach(-50...50, id: \.self) { cent in
                    if cent % 10 == 0 {
                        TickMark(cent: cent, maxCents: maxCents, radius: radius)
                    }
                }
            }
            .frame(width: size, height: size)
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    private var needleAngle: Double {
        let clamped = max(-maxCents, min(maxCents, centsOff))
        return (clamped / maxCents) * 45 // ±45 degrees
    }
    
    private var centsColor: Color {
        if isInTune { return .green }
        if abs(centsOff) < 15 { return .yellow }
        return .red
    }
}

struct TickMark: View {
    let cent: Int
    let maxCents: Double
    let radius: CGFloat
    
    var body: some View {
        let angle = (Double(cent) / maxCents) * 45 // degrees
        let isMajor = cent % 50 == 0
        let length = isMajor ? 16.0 : 8.0
        let width = isMajor ? 2.0 : 1.0
        let color = cent == 0 ? Color.white : Color.white.opacity(0.3)
        
        Rectangle()
            .fill(color)
            .frame(width: width, height: length)
            .offset(y: -radius - length / 2)
            .rotationEffect(.degrees(angle))
    }
}

struct NeedleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        
        path.move(to: CGPoint(x: width / 2, y: 0))
        path.addLine(to: CGPoint(x: width / 2 - width / 2, y: height))
        path.addLine(to: CGPoint(x: width / 2 + width / 2, y: height))
        path.closeSubpath()
        
        return path
    }
}

/// String selector view
struct StringSelectorView: View {
    @Binding var selectedIndex: Int
    let strings: [GuitarString]
    let onSelect: (Int) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(strings.enumerated()), id: \.element.id) { index, string in
                    Button {
                        onSelect(index)
                    } label: {
                        VStack(spacing: 4) {
                            Text("\(string.stringNumber)")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.5))
                            Text(string.note)
                                .font(.title2.bold())
                                .foregroundStyle(selectedIndex == index ? .white : .white.opacity(0.7))
                            Text(String(format: "%.1f Hz", string.frequency))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedIndex == index ? Color.white.opacity(0.15) : Color.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedIndex == index ? Color.green.opacity(0.5) : Color.clear, lineWidth: 2)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }
}

/// Tuning preset picker
struct TuningPickerView: View {
    @Binding var selectedTuning: TuningPreset
    
    var body: some View {
        Menu {
            ForEach(TuningPreset.allCases) { preset in
                Button {
                    selectedTuning = preset
                } label: {
                    HStack {
                        Text(preset.rawValue)
                        if selectedTuning == preset {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "tuningfork")
                Text(selectedTuning.rawValue)
                    .font(.subheadline.weight(.medium))
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.08))
            )
            .foregroundStyle(.white)
        }
        .menuStyle(.borderlessButton)
    }
}

/// Main tuner content view
struct TunerView: View {
    @StateObject private var viewModel = TunerViewModel()
    
    private let gradient = LinearGradient(
        colors: [Color(hex: "#6C5CE7"), Color(hex: "#00CEC9")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var body: some View {
        ZStack {
            // Background
            Color(hex: "#0F1020")
                .overlay(gradient.opacity(0.1))
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header
                headerView
                
                // Tuning picker
                TuningPickerView(selectedTuning: $viewModel.selectedTuning)
                
                // String selector
                StringSelectorView(
                    selectedIndex: $viewModel.selectedStringIndex,
                    strings: viewModel.strings,
                    onSelect: viewModel.selectString
                )
                
                // Main tuner dial
                TunerDialView(
                    centsOff: viewModel.centsOff,
                    isInTune: viewModel.isInTune,
                    targetNote: viewModel.currentString.note,
                    detectedNote: viewModel.engine.closestNote,
                    amplitude: viewModel.engine.amplitude
                )
                .frame(maxWidth: 300, maxHeight: 300)
                .padding(.vertical, 20)
                
                // Status indicators
                statusView
                
                // Listen button
                listenButton
                
                // Calibration
                calibrationView
            }
            .padding(24)
        }
        .onDisappear {
            viewModel.engine.stopListening()
        }
    }
    
    private var headerView: some View {
        HStack {
            Image(systemName: "tuningfork")
                .font(.system(size: 32))
                .foregroundStyle(gradient)
            VStack(alignment: .leading, spacing: 2) {
                Text("GuitarTuner")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                Text("Precision Guitar Tuner")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
        }
    }
    
    private var statusView: some View {
        HStack(spacing: 24) {
            StatusItem(
                label: "Frequency",
                value: viewModel.engine.detectedFrequency > 0 ? 
                    String(format: "%.1f Hz", viewModel.engine.detectedFrequency) : "--",
                color: viewModel.engine.detectedFrequency > 0 ? .white : .white.opacity(0.4)
            )
            
            StatusItem(
                label: "Amplitude",
                value: String(format: "%.3f", viewModel.engine.amplitude),
                color: viewModel.engine.amplitude > 0.02 ? .green : .white.opacity(0.4)
            )
            
            StatusItem(
                label: "Status",
                value: viewModel.engine.state == .listening ? "Listening" : "Idle",
                color: viewModel.engine.state == .listening ? .green : .white.opacity(0.6)
            )
        }
    }
    
    private var listenButton: some View {
        Button {
            viewModel.toggleListening()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: viewModel.isListening ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 28))
                Text(viewModel.isListening ? "Stop Listening" : "Start Listening")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(viewModel.isListening ? Color.red.opacity(0.8) : gradient)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: (viewModel.isListening ? Color.red : Color(hex: "#6C5CE7")).opacity(0.4), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.engine.state == .requestingPermission)
    }
    
    private var calibrationView: some View {
        VStack(spacing: 8) {
            Text("Calibration: A4 = \(Int(viewModel.calibration)) Hz")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
            
            Slider(value: $viewModel.calibration, in: 415...466, step: 1) { _ in
                viewModel.setCalibration(viewModel.calibration)
            }
            .tint(gradient)
            .padding(.horizontal, 40)
        }
    }
}

struct StatusItem: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
    }
}

// MARK: - Previews

#Preview("Tuner View - Light") {
    TunerView()
        .preferredColorScheme(.light)
}

#Preview("Tuner View - Dark") {
    TunerView()
        .preferredColorScheme(.dark)
}

#Preview("String Selector") {
    StringSelectorView(
        selectedIndex: .constant(0),
        strings: GuitarString.standardTuning,
        onSelect: { _ in }
    )
    .padding()
    .background(Color(hex: "#0F1020"))
}

#Preview("Tuner Dial - In Tune") {
    TunerDialView(
        centsOff: 2,
        isInTune: true,
        targetNote: "E2",
        detectedNote: "E2",
        amplitude: 0.5
    )
    .frame(width: 300, height: 400)
    .padding()
    .background(Color(hex: "#0F1020"))
}

#Preview("Tuner Dial - Sharp") {
    TunerDialView(
        centsOff: 25,
        isInTune: false,
        targetNote: "A2",
        detectedNote: "A#2",
        amplitude: 0.3
    )
    .frame(width: 300, height: 400)
    .padding()
    .background(Color(hex: "#0F1020"))
}

#Preview("Tuner Dial - Flat") {
    TunerDialView(
        centsOff: -30,
        isInTune: false,
        targetNote: "D3",
        detectedNote: "C#3",
        amplitude: 0.4
    )
    .frame(width: 300, height: 400)
    .padding()
    .background(Color(hex: "#0F1020"))
}