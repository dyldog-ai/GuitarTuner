//
//  GuitarTunerShared.swift
//  Shared SwiftUI views and models for GuitarTuner
//
//  Styled after a 19th-century parlour instrument: mahogany, brass and
//  a galvanometer-style needle gauge.
//

import SwiftUI
import Combine
import Accelerate
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
        GuitarString(note: "A", frequency: 110.00, stringNumber: 5),
        GuitarString(note: "D", frequency: 146.83, stringNumber: 4),
        GuitarString(note: "G", frequency: 196.00, stringNumber: 3),
        GuitarString(note: "B", frequency: 246.94, stringNumber: 2),
        GuitarString(note: "E", frequency: 329.63, stringNumber: 1),  // High E
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
        case .dropD: return [
            GuitarString(note: "D", frequency: 73.42, stringNumber: 6),
            GuitarString(note: "A", frequency: 110.00, stringNumber: 5),
            GuitarString(note: "D", frequency: 146.83, stringNumber: 4),
            GuitarString(note: "G", frequency: 196.00, stringNumber: 3),
            GuitarString(note: "B", frequency: 246.94, stringNumber: 2),
            GuitarString(note: "E", frequency: 329.63, stringNumber: 1),
        ]
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

// MARK: - Pitch Detector (McLeod Pitch Method)

/// Result of analysing one audio buffer. Safe to pass across threads.
struct PitchReading {
    let frequency: Double?  // nil when no confident pitch was found
    let amplitude: Float
}

/// Pitch detector using the McLeod Pitch Method (normalized square
/// difference function + key-maximum picking). Far more resistant to
/// octave errors than raw autocorrelation, which matters for the strong
/// harmonics of plucked strings.
///
/// All methods are called on the audio render thread only.
final class PitchDetector {
    private let sampleRate: Double
    private let minFrequency: Double
    private let maxFrequency: Double
    private let minAmplitude: Float
    private let clarityThreshold: Float = 0.82

    private var samples: [Float]

    init(sampleRate: Double,
         minFrequency: Double = 55.0,
         maxFrequency: Double = 500.0,
         minAmplitude: Float = 0.015) {
        self.sampleRate = sampleRate
        self.minFrequency = minFrequency
        self.maxFrequency = maxFrequency
        self.minAmplitude = minAmplitude
        self.samples = []
    }

    func process(buffer: AVAudioPCMBuffer) -> PitchReading {
        guard let channelData = buffer.floatChannelData?[0] else {
            return PitchReading(frequency: nil, amplitude: 0)
        }
        let n = Int(buffer.frameLength)
        guard n > 0 else { return PitchReading(frequency: nil, amplitude: 0) }

        samples = Array(UnsafeBufferPointer(start: channelData, count: n))

        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(n))
        guard rms > minAmplitude else {
            return PitchReading(frequency: nil, amplitude: rms)
        }

        return PitchReading(frequency: detectPitch(), amplitude: rms)
    }

    private func detectPitch() -> Double? {
        let n = samples.count
        let minLag = max(2, Int(sampleRate / maxFrequency))
        let maxLag = min(Int(sampleRate / minFrequency), n - 2)
        guard maxLag > minLag else { return nil }

        // Prefix sums of squared samples so m'(lag) is O(1) per lag.
        var squared = [Float](repeating: 0, count: n)
        vDSP_vsq(samples, 1, &squared, 1, vDSP_Length(n))
        var prefix = [Float](repeating: 0, count: n + 1)
        for i in 0..<n { prefix[i + 1] = prefix[i] + squared[i] }

        // NSDF: n'(lag) = 2 * acf(lag) / (energy(0..n-lag) + energy(lag..n))
        var nsdf = [Float](repeating: 0, count: maxLag + 1)
        samples.withUnsafeBufferPointer { ptr in
            guard let base = ptr.baseAddress else { return }
            for lag in minLag...maxLag {
                var acf: Float = 0
                vDSP_dotpr(base, 1, base + lag, 1, &acf, vDSP_Length(n - lag))
                let m = (prefix[n - lag] - prefix[0]) + (prefix[n] - prefix[lag])
                nsdf[lag] = m > 0 ? 2 * acf / m : 0
            }
        }

        // Key maximum picking: collect the highest point of each region
        // between positive-going and negative-going zero crossings.
        var keyMaxima: [(lag: Int, value: Float)] = []
        var inPeak = false
        var peakLag = 0
        var peakValue: Float = 0
        for lag in minLag...maxLag {
            let value = nsdf[lag]
            if value > 0 {
                if !inPeak {
                    inPeak = true
                    peakLag = lag
                    peakValue = value
                } else if value > peakValue {
                    peakValue = value
                    peakLag = lag
                }
            } else if inPeak {
                inPeak = false
                keyMaxima.append((peakLag, peakValue))
            }
        }
        if inPeak { keyMaxima.append((peakLag, peakValue)) }
        guard let highest = keyMaxima.map(\.value).max(),
              highest >= clarityThreshold else { return nil }

        // First key maximum above k * highest is the fundamental.
        let threshold = highest * 0.9
        guard let chosen = keyMaxima.first(where: { $0.value >= threshold }) else { return nil }

        // Parabolic interpolation around the chosen lag.
        let lag = chosen.lag
        var refinedLag = Double(lag)
        if lag > minLag && lag < maxLag {
            let y1 = Double(nsdf[lag - 1])
            let y2 = Double(nsdf[lag])
            let y3 = Double(nsdf[lag + 1])
            let denominator = 2 * (2 * y2 - y1 - y3)
            if abs(denominator) > 1e-9 {
                refinedLag += (y3 - y1) / denominator
            }
        }
        guard refinedLag > 0 else { return nil }

        let frequency = sampleRate / refinedLag
        guard frequency >= minFrequency && frequency <= maxFrequency else { return nil }
        return frequency
    }
}

// MARK: - Tuner Engine

/// Audio engine for real-time pitch detection using AVAudioEngine.
/// Publishes a smoothed, briefly-held pitch so the display doesn't
/// flicker between buffers.
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

    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?

    private let bufferSize: AVAudioFrameCount = 4096

    // Smoothing over recent readings, plus a short hold after silence.
    private var recentFrequencies: [Double] = []
    private var lastPitchDate: Date = .distantPast
    private let holdInterval: TimeInterval = 0.9

    deinit {
        // Tear down audio directly; stopListening() is main-actor isolated and
        // can't be called from the nonisolated deinit.
        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)
    }

    func startListening() {
        guard state != .listening && state != .requestingPermission else { return }

        #if os(iOS)
        state = .requestingPermission
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            Task { @MainActor in
                guard let self else { return }
                if granted {
                    self.startAudioEngine()
                } else {
                    self.state = .error("Microphone permission denied")
                }
            }
        }
        #elseif os(macOS)
        startAudioEngine()
        #endif
    }

    private func startAudioEngine() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers, .allowBluetoothHFP])
            try session.setActive(true)
        } catch {
            state = .error("Audio session setup failed: \(error.localizedDescription)")
            return
        }
        #endif

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else {
            state = .error("No audio input available")
            return
        }

        // The detector must use the hardware sample rate, not an assumed
        // one — a 44.1k assumption on 48k hardware reads ~9% sharp.
        let detector = PitchDetector(sampleRate: format.sampleRate)

        input.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, _ in
            let reading = detector.process(buffer: buffer)
            DispatchQueue.main.async {
                self?.apply(reading)
            }
        }

        engine.prepare()
        do {
            try engine.start()
            audioEngine = engine
            inputNode = input
            state = .listening
        } catch {
            input.removeTap(onBus: 0)
            state = .error("Failed to start audio engine: \(error.localizedDescription)")
        }
    }

    func stopListening() {
        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)
        audioEngine = nil
        inputNode = nil

        detectedFrequency = 0
        amplitude = 0
        recentFrequencies = []
        lastPitchDate = .distantPast

        if state != .idle {
            state = .idle
        }
    }

    private func apply(_ reading: PitchReading) {
        guard state == .listening else { return }
        amplitude = reading.amplitude

        guard let frequency = reading.frequency else {
            // Hold the last reading briefly so the needle doesn't snap
            // to zero between plucks.
            if Date().timeIntervalSince(lastPitchDate) > holdInterval {
                detectedFrequency = 0
                recentFrequencies = []
            }
            return
        }

        lastPitchDate = Date()

        // If the note jumped (new string plucked), restart smoothing.
        if let last = recentFrequencies.last, abs(frequency - last) / last > 0.06 {
            recentFrequencies = []
        }
        recentFrequencies.append(frequency)
        if recentFrequencies.count > 5 { recentFrequencies.removeFirst() }

        let sorted = recentFrequencies.sorted()
        detectedFrequency = sorted[sorted.count / 2]
    }
}

// MARK: - Tuner View Model

/// View model: maps the detected pitch onto the nearest string of the
/// selected tuning (automatic string detection — no manual selection).
@MainActor
final class TunerViewModel: ObservableObject {
    let engine = TunerEngine()

    @Published var selectedTuning: TuningPreset = .standard

    private var cancellables: Set<AnyCancellable> = []

    init() {
        engine.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    var strings: [GuitarString] { selectedTuning.strings }

    var hasPitch: Bool { engine.detectedFrequency > 0 }

    /// Index of the string nearest to the detected pitch, or nil in silence.
    var detectedStringIndex: Int? {
        guard hasPitch else { return nil }
        let frequency = engine.detectedFrequency
        return strings.indices.min { a, b in
            abs(log2(frequency / strings[a].frequency)) < abs(log2(frequency / strings[b].frequency))
        }
    }

    var detectedString: GuitarString? {
        detectedStringIndex.map { strings[$0] }
    }

    /// Cents deviation from the auto-detected string's target pitch.
    var centsOff: Double {
        guard hasPitch, let target = detectedString else { return 0 }
        return 1200 * log2(engine.detectedFrequency / target.frequency)
    }

    var isInTune: Bool {
        hasPitch && abs(centsOff) <= 5
    }

    var isListening: Bool {
        engine.state == .listening
    }

    var tuningAdvice: String {
        guard hasPitch else { return isListening ? "Sound a string" : "At rest" }
        if isInTune { return "In tune" }
        return centsOff > 0 ? "Slacken the string" : "Wind the string tighter"
    }

    func toggleListening() {
        if engine.state == .listening {
            engine.stopListening()
        } else {
            engine.startListening()
        }
    }
}

// MARK: - Parlour Palette

/// Colours of a 19th-century drawing-room instrument.
enum Parlour {
    static let mahoganyDark = Color(red: 0.14, green: 0.08, blue: 0.05)
    static let mahogany = Color(red: 0.24, green: 0.13, blue: 0.08)
    static let mahoganyLight = Color(red: 0.33, green: 0.19, blue: 0.11)
    static let brass = Color(red: 0.72, green: 0.56, blue: 0.30)
    static let brassBright = Color(red: 0.93, green: 0.80, blue: 0.52)
    static let brassDark = Color(red: 0.42, green: 0.30, blue: 0.14)
    static let parchment = Color(red: 0.94, green: 0.89, blue: 0.76)
    static let parchmentShade = Color(red: 0.85, green: 0.77, blue: 0.60)
    static let ink = Color(red: 0.16, green: 0.13, blue: 0.10)
    static let inkFaint = Color(red: 0.16, green: 0.13, blue: 0.10).opacity(0.55)
    static let bluedSteel = Color(red: 0.16, green: 0.19, blue: 0.26)
    static let lampGreen = Color(red: 0.30, green: 0.62, blue: 0.36)
    static let lampOff = Color(red: 0.20, green: 0.26, blue: 0.20)

    static let brassGradient = LinearGradient(
        colors: [brassDark, brass, brassBright, brass, brassDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let bezelGradient = AngularGradient(
        colors: [brassDark, brassBright, brass, brassDark, brass, brassBright, brassDark],
        center: .center
    )
}

// MARK: - Background

/// Polished mahogany panel with subtle grain and a vignette.
struct MahoganyBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Parlour.mahoganyLight, Parlour.mahogany, Parlour.mahoganyDark],
                startPoint: .top,
                endPoint: .bottom
            )

            // Wood grain: deterministic pseudo-random wavering streaks.
            Canvas { context, size in
                var seed: UInt64 = 0x5EED
                func random() -> Double {
                    seed = seed &* 6364136223846793005 &+ 1442695040888963407
                    return Double(seed >> 33) / Double(UInt32.max)
                }
                let streaks = 46
                for i in 0..<streaks {
                    let x = size.width * Double(i) / Double(streaks) + random() * 14 - 7
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: -10))
                    var y: Double = 0
                    var drift = x
                    while y < size.height + 10 {
                        y += 26 + random() * 30
                        drift += random() * 10 - 5
                        path.addQuadCurve(
                            to: CGPoint(x: drift, y: y),
                            control: CGPoint(x: drift + random() * 12 - 6, y: y - 15)
                        )
                    }
                    context.stroke(
                        path,
                        with: .color(.black.opacity(0.05 + random() * 0.07)),
                        lineWidth: 0.7 + random() * 1.6
                    )
                }
            }

            RadialGradient(
                colors: [.clear, .black.opacity(0.45)],
                center: .center,
                startRadius: 120,
                endRadius: 620
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Brass Fittings

/// A small brass screw head, for fastening plaques to the cabinet.
struct BrassScrew: View {
    var angle: Angle = .degrees(38)

    var body: some View {
        ZStack {
            Circle()
                .fill(Parlour.brassGradient)
                .overlay(Circle().stroke(Parlour.brassDark, lineWidth: 0.6))
            Rectangle()
                .fill(Parlour.brassDark.opacity(0.9))
                .frame(height: 1.2)
                .padding(.horizontal, 1.5)
                .rotationEffect(angle)
        }
        .frame(width: 7, height: 7)
        .shadow(color: .black.opacity(0.5), radius: 1, y: 1)
    }
}

/// An engraved brass plate with screws in the corners.
struct BrassPlaque<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Parlour.brassGradient)
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Parlour.brassDark.opacity(0.8), lineWidth: 1)
                        .padding(2.5)
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Parlour.brassBright.opacity(0.9), Parlour.brassDark],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.2
                        )
                }
            )
            .overlay(alignment: .topLeading) { BrassScrew(angle: .degrees(30)).padding(4) }
            .overlay(alignment: .topTrailing) { BrassScrew(angle: .degrees(80)).padding(4) }
            .overlay(alignment: .bottomLeading) { BrassScrew(angle: .degrees(120)).padding(4) }
            .overlay(alignment: .bottomTrailing) { BrassScrew(angle: .degrees(55)).padding(4) }
            .shadow(color: .black.opacity(0.55), radius: 5, y: 3)
    }
}

// MARK: - The Gauge

/// Galvanometer-style needle gauge: brass bezel, parchment face,
/// blued-steel needle sweeping ±50 cents.
struct ParlourGaugeView: View {
    let centsOff: Double
    let hasPitch: Bool
    let isInTune: Bool
    let noteName: String
    let frequency: Double

    private let maxCents: Double = 50
    private let sweep: Double = 55 // degrees each side of vertical

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: size / 2, y: size / 2)
            let faceRadius = size * 0.44

            ZStack {
                bezel(radius: size * 0.5, center: center)
                face(radius: faceRadius, center: center)
                scale(radius: faceRadius, center: center)
                faceText(radius: faceRadius, center: center)
                needle(radius: faceRadius, center: center)
                hub(center: center)
            }
            .frame(width: size, height: size)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var needleAngle: Double {
        guard hasPitch else { return -sweep }
        let clamped = max(-maxCents, min(maxCents, centsOff))
        return (clamped / maxCents) * sweep
    }

    private func bezel(radius: CGFloat, center: CGPoint) -> some View {
        ZStack {
            Circle()
                .fill(Parlour.bezelGradient)
                .frame(width: radius * 2, height: radius * 2)
                .shadow(color: .black.opacity(0.6), radius: 10, y: 6)
            Circle()
                .stroke(Parlour.brassDark, lineWidth: 1.5)
                .frame(width: radius * 2, height: radius * 2)
            Circle()
                .stroke(Parlour.brassDark.opacity(0.8), lineWidth: 2)
                .frame(width: radius * 1.79, height: radius * 1.79)
        }
        .position(center)
    }

    private func face(radius: CGFloat, center: CGPoint) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Parlour.parchment, Parlour.parchmentShade],
                    center: .center,
                    startRadius: radius * 0.2,
                    endRadius: radius
                )
            )
            .overlay(
                Circle().stroke(Parlour.ink.opacity(0.35), lineWidth: 1)
            )
            .frame(width: radius * 2, height: radius * 2)
            .position(center)
    }

    private func scale(radius: CGFloat, center: CGPoint) -> some View {
        let tickRadius = radius * 0.88
        return ZStack {
            // Arc under the ticks; trim 0.25 sits at the bottom of the
            // circle, so rotate 180° to centre the arc at the top.
            Circle()
                .trim(from: 0.25 - sweep / 360, to: 0.25 + sweep / 360)
                .stroke(Parlour.ink.opacity(0.7), lineWidth: 1.2)
                .frame(width: tickRadius * 2, height: tickRadius * 2)
                .rotationEffect(.degrees(180))
                .position(center)

            // Ticks every 5 cents; heavier every 25
            ForEach(Array(stride(from: -50, through: 50, by: 5)), id: \.self) { cent in
                let isMajor = cent % 25 == 0
                let length: CGFloat = isMajor ? radius * 0.11 : radius * 0.055
                Rectangle()
                    .fill(Parlour.ink.opacity(isMajor ? 0.9 : 0.6))
                    .frame(width: isMajor ? 1.8 : 1, height: length)
                    .offset(y: -tickRadius + length / 2)
                    .rotationEffect(.degrees(Double(cent) / maxCents * sweep))
                    .position(center)
            }

            // Numerals at the majors
            ForEach([-50, -25, 0, 25, 50], id: \.self) { cent in
                let angle = Double(cent) / maxCents * sweep * .pi / 180
                let numeralRadius = radius * 0.70
                Text(cent == 0 ? "0" : "\(abs(cent))")
                    .font(.system(size: radius * 0.09, weight: .medium, design: .serif))
                    .foregroundStyle(Parlour.ink)
                    .position(
                        x: center.x + numeralRadius * sin(angle),
                        y: center.y - numeralRadius * cos(angle)
                    )
            }

            // In-tune diamond at the top
            Diamond()
                .fill(isInTune ? Parlour.lampGreen : Parlour.ink.opacity(0.8))
                .frame(width: radius * 0.05, height: radius * 0.08)
                .position(x: center.x, y: center.y - radius * 0.945)
        }
    }

    private func faceText(radius: CGFloat, center: CGPoint) -> some View {
        ZStack {
            Text("FLAT")
                .font(.system(size: radius * 0.085, weight: .semibold, design: .serif).smallCaps())
                .foregroundStyle(Parlour.inkFaint)
                .position(x: center.x - radius * 0.52, y: center.y - radius * 0.28)
            Text("SHARP")
                .font(.system(size: radius * 0.085, weight: .semibold, design: .serif).smallCaps())
                .foregroundStyle(Parlour.inkFaint)
                .position(x: center.x + radius * 0.52, y: center.y - radius * 0.28)

            // The sounded note, engraved large beneath the pivot
            Text(hasPitch ? noteName : "—")
                .font(.system(size: radius * 0.42, weight: .bold, design: .serif))
                .foregroundStyle(Parlour.ink)
                .shadow(color: .white.opacity(0.5), radius: 0.5, x: 0, y: 0.7)
                .position(x: center.x, y: center.y + radius * 0.42)

            // Frequency register window
            Text(hasPitch ? String(format: "%.1f ᴴᶻ", frequency) : "· · ·")
                .font(.system(size: radius * 0.085, weight: .medium, design: .serif))
                .monospacedDigit()
                .foregroundStyle(Parlour.ink.opacity(0.85))
                .padding(.horizontal, radius * 0.07)
                .padding(.vertical, radius * 0.025)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Parlour.parchmentShade.opacity(0.7))
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Parlour.ink.opacity(0.4), lineWidth: 0.8))
                )
                .position(x: center.x, y: center.y + radius * 0.73)

            Text("CENTS OF A SEMITONE")
                .font(.system(size: radius * 0.052, weight: .regular, design: .serif).smallCaps())
                .foregroundStyle(Parlour.inkFaint)
                .position(x: center.x, y: center.y - radius * 0.48)
        }
    }

    private func needle(radius: CGFloat, center: CGPoint) -> some View {
        NeedleShape()
            .fill(
                LinearGradient(
                    colors: [Parlour.bluedSteel, Color(red: 0.30, green: 0.35, blue: 0.45), Parlour.bluedSteel],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: radius * 0.045, height: radius * 0.86)
            .offset(y: -radius * 0.36)
            .rotationEffect(.degrees(needleAngle))
            .position(center)
            .shadow(color: .black.opacity(0.35), radius: 2, y: 2)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: needleAngle)
    }

    private func hub(center: CGPoint) -> some View {
        ZStack {
            Circle()
                .fill(Parlour.bezelGradient)
                .frame(width: 26, height: 26)
                .overlay(Circle().stroke(Parlour.brassDark, lineWidth: 1))
            Circle()
                .fill(Parlour.bluedSteel)
                .frame(width: 8, height: 8)
        }
        .position(center)
        .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
    }
}

struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

/// Tapered needle with a counterweight tail.
struct NeedleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        // Slim triangle: point at top, widening slightly toward the pivot
        path.move(to: CGPoint(x: w / 2, y: 0))
        path.addLine(to: CGPoint(x: w * 0.15, y: h * 0.82))
        path.addLine(to: CGPoint(x: w * 0.85, y: h * 0.82))
        path.closeSubpath()
        // Counterweight tail below the pivot
        path.addEllipse(in: CGRect(x: w * 0.1, y: h * 0.86, width: w * 0.8, height: w * 0.8))
        return path
    }
}

// MARK: - String Indicators

/// Six brass "tuning pegs", one per string. The peg matching the
/// sounded string lights up of its own accord — no tapping required.
struct StringPegsView: View {
    let strings: [GuitarString]
    let activeIndex: Int?
    let isInTune: Bool

    var body: some View {
        HStack(spacing: 14) {
            ForEach(Array(strings.enumerated()), id: \.element.id) { index, string in
                let isActive = index == activeIndex
                VStack(spacing: 5) {
                    ZStack {
                        Circle()
                            .fill(Parlour.brassGradient)
                            .overlay(
                                Circle().stroke(
                                    isActive
                                        ? (isInTune ? Parlour.lampGreen : Parlour.brassBright)
                                        : Parlour.brassDark,
                                    lineWidth: isActive ? 2.5 : 1
                                )
                            )
                            .shadow(
                                color: isActive
                                    ? (isInTune ? Parlour.lampGreen : Parlour.brassBright).opacity(0.8)
                                    : .black.opacity(0.5),
                                radius: isActive ? 8 : 2,
                                y: isActive ? 0 : 2
                            )
                        Text(string.note)
                            .font(.system(size: 19, weight: .bold, design: .serif))
                            .foregroundStyle(isActive ? Parlour.ink : Parlour.ink.opacity(0.65))
                            .shadow(color: Parlour.brassBright.opacity(0.6), radius: 0.5, y: 0.7)
                    }
                    .frame(width: 46, height: 46)
                    .scaleEffect(isActive ? 1.12 : 1.0)

                    Text(romanNumeral(string.stringNumber))
                        .font(.system(size: 11, weight: .medium, design: .serif))
                        .foregroundStyle(Parlour.brass.opacity(isActive ? 1 : 0.55))
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: activeIndex)
            }
        }
    }

    private func romanNumeral(_ n: Int) -> String {
        ["I", "II", "III", "IV", "V", "VI"][min(max(n - 1, 0), 5)]
    }
}

// MARK: - Tuning Selector

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
                    .font(.system(size: 12))
                Text(selectedTuning.rawValue)
                    .font(.system(size: 13, weight: .semibold, design: .serif).smallCaps())
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(Parlour.brassBright)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Parlour.mahoganyDark.opacity(0.75))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Parlour.brass.opacity(0.7), lineWidth: 1)
                    )
            )
        }
        .menuStyle(.borderlessButton)
        .buttonStyle(.plain)
        .fixedSize()
    }
}

// MARK: - Listen Button

/// A round brass push-button, as on an electric parlour bell.
struct ListenButton: View {
    let isListening: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Parlour.bezelGradient)
                        .frame(width: 64, height: 64)
                        .shadow(color: .black.opacity(0.6), radius: 6, y: 4)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: isListening
                                    ? [Color(red: 0.75, green: 0.28, blue: 0.20), Color(red: 0.45, green: 0.13, blue: 0.09)]
                                    : [Parlour.brassBright, Parlour.brass],
                                center: .init(x: 0.35, y: 0.3),
                                startRadius: 2,
                                endRadius: 34
                            )
                        )
                        .frame(width: 46, height: 46)
                        .overlay(Circle().stroke(Parlour.brassDark, lineWidth: 1))
                    Image(systemName: isListening ? "stop.fill" : "ear")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(isListening ? Parlour.parchment : Parlour.ink.opacity(0.8))
                }
                Text(isListening ? "SILENCE" : "LISTEN")
                    .font(.system(size: 12, weight: .semibold, design: .serif).smallCaps())
                    .tracking(2)
                    .foregroundStyle(Parlour.brassBright)
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
    }
}

// MARK: - Main View

struct TunerView: View {
    @StateObject private var viewModel = TunerViewModel()

    var body: some View {
        ZStack {
            MahoganyBackground()

            VStack(spacing: 18) {
                // Maker's plaque
                BrassPlaque {
                    VStack(spacing: 2) {
                        Text("THE  PARLOUR  TUNER")
                            .font(.system(size: 19, weight: .bold, design: .serif).smallCaps())
                            .tracking(3)
                        Text("Patent Chromatic Pitch Indicator · No. 6")
                            .font(.system(size: 10, weight: .regular, design: .serif).italic())
                            .tracking(1)
                    }
                    .foregroundStyle(Parlour.ink)
                    .shadow(color: Parlour.brassBright.opacity(0.7), radius: 0.5, y: 0.8)
                }

                TuningPickerView(selectedTuning: $viewModel.selectedTuning)

                ParlourGaugeView(
                    centsOff: viewModel.centsOff,
                    hasPitch: viewModel.hasPitch,
                    isInTune: viewModel.isInTune,
                    noteName: viewModel.detectedString?.note ?? "—",
                    frequency: viewModel.engine.detectedFrequency
                )
                .frame(maxWidth: 340, maxHeight: 340)

                // Instruction line, engraved on the cabinet
                Text(viewModel.tuningAdvice)
                    .font(.system(size: 15, weight: .medium, design: .serif).italic())
                    .foregroundStyle(viewModel.isInTune ? Parlour.lampGreen : Parlour.brassBright.opacity(0.85))
                    .animation(.easeInOut(duration: 0.2), value: viewModel.tuningAdvice)

                StringPegsView(
                    strings: viewModel.strings,
                    activeIndex: viewModel.detectedStringIndex,
                    isInTune: viewModel.isInTune
                )

                ListenButton(
                    isListening: viewModel.isListening,
                    isDisabled: viewModel.engine.state == .requestingPermission,
                    action: viewModel.toggleListening
                )

                if case .error(let message) = viewModel.engine.state {
                    Text(message)
                        .font(.system(size: 12, design: .serif).italic())
                        .foregroundStyle(Color(red: 0.85, green: 0.5, blue: 0.4))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(24)
        }
        .onDisappear {
            viewModel.engine.stopListening()
        }
    }
}

// MARK: - Previews

#Preview("Parlour Tuner") {
    TunerView()
}

#Preview("Gauge — In Tune") {
    ParlourGaugeView(centsOff: 1.5, hasPitch: true, isInTune: true, noteName: "A", frequency: 110.05)
        .frame(width: 340, height: 340)
        .padding()
        .background(MahoganyBackground())
}

#Preview("Gauge — Sharp") {
    ParlourGaugeView(centsOff: 28, hasPitch: true, isInTune: false, noteName: "E", frequency: 84.1)
        .frame(width: 340, height: 340)
        .padding()
        .background(MahoganyBackground())
}

#Preview("Gauge — Silent") {
    ParlourGaugeView(centsOff: 0, hasPitch: false, isInTune: false, noteName: "—", frequency: 0)
        .frame(width: 340, height: 340)
        .padding()
        .background(MahoganyBackground())
}

#Preview("String Pegs") {
    StringPegsView(strings: GuitarString.standardTuning, activeIndex: 2, isInTune: false)
        .padding()
        .background(MahoganyBackground())
}
