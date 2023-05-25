// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/Waveform/

import AVFoundation
import SwiftUI
import Waveform

enum FileType: String, CaseIterable, Identifiable {
    case piano
    case beat
    
    var id: String { self.rawValue }
    
    var url: URL {
        switch self {
            case .piano:
                return Bundle.main.url(forResource: "Piano", withExtension: "mp3")!
            case .beat:
                return Bundle.main.url(forResource: "beat", withExtension: "aiff")!
        }
    }
}

class WaveformDemoModel: ObservableObject {
    @Published var samples: SampleBuffer

    init(file: AVAudioFile) {
        let stereo = file.floatChannelData()!
        samples = SampleBuffer(samples: stereo[0])
    }
    
    func changeFile(_ type: FileType) {
        let url = type.url
        let file = try! AVAudioFile(forReading: url)
        
        let stereo = file.floatChannelData()!
        samples = SampleBuffer(samples: stereo[0])
    }
}

func getFile() -> AVAudioFile {
    let url = Bundle.main.url(forResource: "Piano", withExtension: "mp3")!
    return try! AVAudioFile(forReading: url)
}

func clamp(_ x: Double, _ inf: Double, _ sup: Double) -> Double {
    max(min(x, sup), inf)
}

struct ContentView: View {
    @StateObject var model = WaveformDemoModel(file: getFile())

    @State var start: Int = 0
    @State var end: Int = 1
    
    let formatter = NumberFormatter()
    
    @State var fileType: FileType = .piano
    var body: some View {
        VStack {
            ZStack(alignment: .leading) {
                VStack {
                    Waveform(samples: model.samples) { sampleStart, sampleEnd in
                        start = sampleStart
                        end = sampleEnd
                    }
                    .foregroundColor(.white)
                    .highlightColor(.blue)
//                    .border(.red)
//                    .frame(width:200)
                    .clipShape(Rectangle())
                    
//                    .background(Color.clear)
//                    .padding(10)
                    HStack {
                        Text("Start: \(start)")
                        Text("End: \(end)")
                        Text("Sample Length: \(model.samples.count)")
                    }
                    Picker("FileType", selection: $fileType) {
                        ForEach(FileType.allCases) { fileType in
                            Text(fileType.rawValue.capitalized).tag(fileType)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: fileType) { newValue in
                        model.changeFile(newValue)
                    }
                }

                //MinimapView(start: $start, length: $length)
            }
//            .frame(height: 100)
//            .padding()
//            Waveform(samples: model.samples,
//                     start: Int(start * Double(model.samples.count - 1)),
//                     length: Int(length * Double(model.samples.count)))
//            .foregroundColor(.blue)
        }
//        .padding()
    }
}
