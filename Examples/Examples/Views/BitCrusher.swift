import AudioKit
import AVFoundation
import SwiftUI

struct BitCrusherData {
    var bitDepth: AUValue = 8
    var sampleRate: AUValue = 10_000
    var rampDuration: AUValue = 0.02
    var balance: AUValue = 0.5
}

class BitCrusherConductor: ObservableObject, ProcessesPlayerInput {

    let engine = AKEngine()
    let player = AKPlayer()
    let bitcrusher: AKBitCrusher
    let dryWetMixer: AKDryWetMixer
    let playerPlot: AKNodeOutputPlot
    let bitcrusherPlot: AKNodeOutputPlot
    let mixPlot: AKNodeOutputPlot
    let buffer: AVAudioPCMBuffer

    init() {
        let url = Bundle.main.resourceURL?.appendingPathComponent("Samples/beat.aiff")
        let file = try! AVAudioFile(forReading: url!)
        buffer = try! AVAudioPCMBuffer(file: file)!

        bitcrusher = AKBitCrusher(player)
        dryWetMixer = AKDryWetMixer(player, bitcrusher)
        playerPlot = AKNodeOutputPlot(player)
        bitcrusherPlot = AKNodeOutputPlot(bitcrusher)
        mixPlot = AKNodeOutputPlot(dryWetMixer)
        engine.output = dryWetMixer

        playerPlot.plotType = .rolling
        playerPlot.shouldFill = true
        playerPlot.shouldMirror = true
        playerPlot.setRollingHistoryLength(128)
        bitcrusherPlot.plotType = .rolling
        bitcrusherPlot.color = .blue
        bitcrusherPlot.shouldFill = true
        bitcrusherPlot.shouldMirror = true
        bitcrusherPlot.setRollingHistoryLength(128)
        mixPlot.color = .purple
        mixPlot.shouldFill = true
        mixPlot.shouldMirror = true
        mixPlot.plotType = .rolling
        mixPlot.setRollingHistoryLength(128)
    }

    @Published var data = BitCrusherData() {
        didSet {
            bitcrusher.$bitDepth.ramp(to: data.bitDepth, duration: data.rampDuration)
            bitcrusher.$sampleRate.ramp(to: data.sampleRate, duration: data.rampDuration)
            dryWetMixer.balance = data.balance
        }
    }

    func start() {
        playerPlot.start()
        bitcrusherPlot.start()
        mixPlot.start()

        do {
            try engine.start()
            // player stuff has to be done after start
            player.scheduleBuffer(buffer, at: nil, options: .loops)
        } catch let err {
            AKLog(err)
        }
    }

    func stop() {
        engine.stop()
    }
}

struct BitCrusherView: View {
    @ObservedObject var conductor = BitCrusherConductor()

    var body: some View {
        ScrollView {
            PlayerControls(conductor: conductor)
            ParameterSlider(text: "Bit Depth",
                            parameter: self.$conductor.data.bitDepth,
                            range: 1...24,
                            units: "Generic")
            ParameterSlider(text: "Sample Rate",
                            parameter: self.$conductor.data.sampleRate,
                            range: 0.0...20_000.0,
                            units: "Hertz")
            ParameterSlider(text: "Balance",
                            parameter: self.$conductor.data.balance,
                            range: 0...1,
                            units: "%")
            DryWetMixPlotsView(dry: conductor.playerPlot, wet: conductor.bitcrusherPlot, mix: conductor.mixPlot)
        }
        .padding()
        .navigationBarTitle(Text("Bit Crusher"))
        .onAppear {
            self.conductor.start()
        }
        .onDisappear {
            self.conductor.stop()
        }
    }
}

struct BitCrusher_Previews: PreviewProvider {
    static var previews: some View {
        BitCrusherView()
    }
}
