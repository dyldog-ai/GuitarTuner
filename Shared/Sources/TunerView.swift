//
//  TunerView.swift
//  Main tuner view shared between iOS and macOS
//

import SwiftUI

struct TunerView: View {
    @StateObject private var viewModel = TunerViewModel()
    @Environment(\.colorScheme) private var colorScheme
    
    // Gradient for UI accents
    private let accentGradient = LinearGradient(
        colors: [Color(hex: "#6C5CE7"), Color(hex: "#00CEC9")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Dark background
    private let backgroundColor = Color(hex: "#0F1020")
    
    var body: some View {
        ZStack {
            backgroundColor
                .overlay(accentGradient.opacity(0.08))
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerView
                    
                    // Tuning selector
                    tuningSelectorView
                    
                    // Main tuner display
                    mainTunerView
                    
                    // String indicators
                    stringIndicatorsView
                    
                    // Control button
                    controlButtonView
                    
                    // Info footer
                    infoFooter
                }
                .padding(24)
            }
        }
        .onAppear {
            viewModel.engine.startListening()
        }
        .onDisappear {
            viewModel.engine.stopListening()
        }
        .preferredColorScheme(.dark)
    }
    
    private var headerView: some View {
        HStack(spacing: 16) {
            Image(systemName: "tuningfork")
                .font(.system(size: 36))
                .foregroundStyle(accentGradient)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("GuitarTuner")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                Text("Precision Guitar Tuner")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            Spacer()
            
            // Engine state indicator
            engineStateIndicator
        }
    }
    
    private var engineStateIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(stateColor)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(stateColor.opacity(0.5), lineWidth: 2)
                        .scaleEffect(viewModel.engine.state == .listening ? 2 : 1)
                        .opacity(viewModel.engine.state == .listening ? 0 : 1)
                        .animation(.easeOut(duration: 1).repeatForever(autoreverses: false), value: viewModel.engine.state == .listening)
                )
            
            Text(stateText)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(.white.opacity(0.08)))
    }
    
    private var stateColor: Color {
        switch viewModel.engine.state {
        case .idle: return .gray
        case .requestingPermission: return .orange
        case .listening: return .green
        case .error: return .red
        }
    }
    
    private var stateText: String {
        switch viewModel.engine.state {
        case .idle: return "Idle"
        case .requestingPermission: return "Requesting Mic..."
        case .listening: return "Listening"
        case .error(let msg): return "Error: \(msg)"
        }
    }
    
    private var tuningSelectorView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tuning")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.5))
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(TuningPreset.allCases) { preset in
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                viewModel.selectedTuning = preset
                            }
                        } label: {
                            Text(preset.rawValue.replacingOccurrences(of: " \\(.*\\)", with: "", options: .regularExpression))
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule().fill(
                                        viewModel.selectedTuning == preset ?
                                        AnyShapeStyle(accentGradient) :
                                        AnyShapeStyle(Color.white.opacity(0.08))
                                    )
                                )
                                .foregroundStyle(
                                    viewModel.selectedTuning == preset ? .white : .white.opacity(0.7)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.05)))
    }
    
    private var mainTunerView: some View {
        VStack(spacing: 20) {
            // Detected note
            VStack(spacing: 8) {
                Text(viewModel.engine.closestNote)
                    .font(.system(size: 96, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3), value: viewModel.engine.closestNote)
                
                // Frequency display
                if viewModel.engine.detectedFrequency > 0 {
                    Text(String(format: "%.1f Hz", viewModel.engine.detectedFrequency))
                        .font(.system(.title2, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                        .monospacedDigit()
                }
            }
            
            // Tuning needle / meter
            TuningMeterView(
                centsOff: viewModel.engine.centsOff,
                isInTune: viewModel.engine.isInTune,
                amplitude: viewModel.engine.amplitude,
                gradient: accentGradient
            )
            .frame(height: 60)
            
            // Cents display
            HStack(spacing: 16) {
                centsDisplay("¢", value: viewModel.engine.centsOff, color: viewModel.engine.isInTune ? .green : .orange)
                
                if viewModel.engine.isInTune && viewModel.engine.detectedFrequency > 0 {
                    Text("IN TUNE")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.green)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            viewModel.engine.isInTune && viewModel.engine.detectedFrequency > 0 ?
                            Color.green.opacity(0.5) : Color.white.opacity(0.08),
                            lineWidth: 2
                        )
                )
        )
    }
    
    private func centsDisplay(_ label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
            Text(String(format: "%+.0f", value))
                .font(.system(.title, design: .monospaced).weight(.bold))
                .foregroundStyle(color)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
    }
    
    private var stringIndicatorsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Strings")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.5))
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(viewModel.selectedTuning.strings.reversed()) { string in
                    StringIndicatorView(
                        string: string,
                        detectedFrequency: viewModel.engine.detectedFrequency,
                        targetFrequency: string.frequency,
                        isInTune: viewModel.engine.isInTune && abs(viewModel.engine.centsFromTarget(string.frequency)) < 10,
                        centsOff: viewModel.engine.centsFromTarget(string.frequency),
                        gradient: accentGradient
                    )
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.05)))
    }
    
    private var controlButtonView: some View {
        Button {
            if viewModel.engine.state == .listening {
                viewModel.engine.stopListening()
            } else {
                viewModel.engine.startListening()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: viewModel.engine.state == .listening ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 24))
                Text(viewModel.engine.state == .listening ? "Stop Listening" : "Start Tuning")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                viewModel.engine.state == .listening ?
                AnyShapeStyle(Color.red.opacity(0.8)) :
                AnyShapeStyle(accentGradient)
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(
                color: (viewModel.engine.state == .listening ? Color.red : Color(hex: "#6C5CE7")).opacity(0.4),
                radius: 12, y: 6
            )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.engine.state == .requestingPermission)
    }
    
    private var infoFooter: some View {
        VStack(spacing: 8) {
            if viewModel.engine.state == .error(let message) {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            } else if viewModel.engine.amplitude < 0.02 && viewModel.engine.state == .listening {
                Text("Play a string to tune...")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.4))
            }
            
            Text("A4 = 440 Hz  •  Accurate within ±1¢")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.3))
        }
    }
}

// MARK: - Tuning Meter View

struct TuningMeterView: View {
    let centsOff: Double
    let isInTune: Bool
    let amplitude: Float
    let gradient: LinearGradient
    
    private let range: Double = 50 // ±50 cents
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let center = width / 2
            let maxOffset = center - 20
            let offset = min(max(-maxOffset, CGFloat(centsOff / range) * maxOffset), maxOffset)
            
            ZStack(alignment: .center) {
                // Background track
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 12)
                
                // Center line
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 2, height: 20)
                
                // In-tune zone
                if isInTune && amplitude > 0.02 {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.green.opacity(0.3))
                        .frame(width: 40, height: 12)
                }
                
                // Needle
                Triangle()
                    .fill(isInTune && amplitude > 0.02 ? Color.green : Color.white)
                    .frame(width: 16, height: 24)
                    .offset(x: offset)
                    .animation(.spring(response: 0.15, dampingFraction: 0.8), value: centsOff)
                
                // Tick marks
                HStack(spacing: 0) {
                    ForEach(-2...2, id: \.self) { i in
                        let tickCents = Double(i) * 25
                        VStack(spacing: 2) {
                            Rectangle()
                                .fill(Color.white.opacity(i == 0 ? 0.5 : 0.2))
                                .frame(width: 1, height: i == 0 ? 16 : 10)
                            if i != 0 {
                                Text("\(Int(tickCents))¢")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.3))
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .offset(y: 20)
            }
        }
        .frame(height: 50)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - String Indicator View

struct StringIndicatorView: View {
    let string: GuitarString
    let detectedFrequency: Double
    let targetFrequency: Double
    let isInTune: Bool
    let centsOff: Double
    let gradient: LinearGradient
    
    var body: some View {
        VStack(spacing: 8) {
            // String number and note
            HStack(spacing: 4) {
                Text("\(string.stringNumber)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.4))
                Text(string.note)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
            }
            
            // Mini meter
            MiniMeterView(centsOff: centsOff, isInTune: isInTune)
                .frame(height: 24)
            
            // Target frequency
            Text(String(format: "%.1f Hz", targetFrequency))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isInTune ? Color.green.opacity(0.15) : Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            isInTune ? Color.green.opacity(0.5) : Color.white.opacity(0.08),
                            lineWidth: 1.5
                        )
                )
        )
        .animation(.spring(response: 0.3), value: isInTune)
    }
}

struct MiniMeterView: View {
    let centsOff: Double
    let isInTune: Bool
    private let range: Double = 50
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let center = width / 2
            let maxOffset = center - 6
            let offset = min(max(-maxOffset, CGFloat(centsOff / range) * maxOffset), maxOffset)
            
            ZStack(alignment: .center) {
                // Track
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 6)
                
                // Center
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 1, height: 10)
                
                // In-tune zone
                if isInTune {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.green.opacity(0.4))
                        .frame(width: 20, height: 6)
                }
                
                // Needle
                Circle()
                    .fill(isInTune ? Color.green : Color.white)
                    .frame(width: 10, height: 10)
                    .offset(x: offset)
                    .animation(.spring(response: 0.15, dampingFraction: 0.8), value: centsOff)
            }
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        var string = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if string.hasPrefix("#") { string.removeFirst() }
        var rgb: UInt64 = 0
        Scanner(string: string).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8) & 0xFF) / 255
        let b = Double(rgb & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Extensions for TunerViewModel

extension TunerViewModel {
    // Helper to calculate cents from target
    func centsFromTarget(_ target: Double) -> Double {
        guard engine.detectedFrequency > 0 else { return 0 }
        return 1200 * log2(engine.detectedFrequency / target)
    }
}

extension TunerEngine {
    func centsFromTarget(_ target: Double) -> Double {
        guard detectedFrequency > 0 else { return 0 }
        return 1200 * log2(detectedFrequency / target)
    }
}

// MARK: - Preview

#Preview {
    TunerView()
        .preferredColorScheme(.dark)
}