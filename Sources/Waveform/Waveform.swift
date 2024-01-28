// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/Waveform/

import AVFoundation
import MetalKit
import SwiftUI

#if os(macOS)
/// Waveform SwiftUI View
public struct Waveform: NSViewRepresentable {
    var samples: SampleBuffer
    var start: Int
    var length: Int
    var constants: Constants = Constants()


    /// Initialize the waveform
    /// - Parameters:
    ///   - samples: All samples able to be displayed
    ///   - start: Which sample on which to start displaying samples
    ///   - length: The width of the entire waveform in samples
    ///   - constants: Look and feel parameters for the waveform
    public init(samples: SampleBuffer, start: Int = 0, length: Int = 0) {
        self.samples = samples
        self.start = start
        if length > 0 {
            self.length = min(length, samples.samples.count - start)
        } else {
            self.length = samples.samples.count - start
        }
    }

    /// Class required by NSViewRepresentable
    public class Coordinator {
        var renderer: Renderer

        init(constants: Constants) {
            renderer = Renderer(device: MTLCreateSystemDefaultDevice()!)
            renderer.constants = constants
        }
    }

    /// Required by NSViewRepresentable
    public func makeCoordinator() -> Coordinator {
        return Coordinator(constants: constants)
    }

    /// Required by NSViewRepresentable
    public func makeNSView(context: Context) -> some NSView {
        let metalView = MTKView(frame: CGRect(x: 0, y: 0, width: 1024, height: 768),
                                device: MTLCreateSystemDefaultDevice()!)
        metalView.enableSetNeedsDisplay = true
        metalView.isPaused = true
        metalView.delegate = context.coordinator.renderer
        metalView.layer?.isOpaque = false
        return metalView
    }

    /// Required by NSViewRepresentable
    public func updateNSView(_ nsView: NSViewType, context: Context) {
        let renderer = context.coordinator.renderer
        renderer.constants = constants
        Task {
            await renderer.set(samples: samples,
                               start: start,
                               length: length)
            nsView.setNeedsDisplay(nsView.bounds)
        }
        nsView.setNeedsDisplay(nsView.bounds)
    }
}
#else
/// Waveform SwiftUI View
public struct Waveform: UIViewRepresentable {
    var samples: SampleBuffer
    var start: Int
    var length: Int
    var constants: Constants = Constants()
    
    var highlightColor: Color = .blue
    
    var highlightStart: Float // This will store the start of the selection
    var highlightWidth: Float // This will store the end of the selection
    
    var onSelectionChange: ((Int, Int) -> Void)? // This function will be called when the selection changes


    /// Initialize the waveform
    /// - Parameters:
    ///   - samples: All samples able to be displayed
    ///   - start: Which sample on which to start displaying samples
    ///   - length: The width of the entire waveform in samples
    ///   - constants: Look and feel parameters for the waveform
    public init(samples: SampleBuffer, start: Int = 0, length: Int = 0, onSelectionChange: ((Int, Int) -> Void)? = nil) {
        self.samples = samples
        self.start = start
        
        self.onSelectionChange = onSelectionChange
        
        self.highlightStart = 0
        self.highlightWidth = 0

        if length > 0 {
            self.length = length
        } else {
            self.length = samples.samples.count
        }
    }
    
    public func highlightColor(_ color: Color) -> Waveform {
        var newView = self
        newView.highlightColor = color
        return newView
    }

    /// Required by UIViewRepresentable
    public class Coordinator {
        var renderer: Renderer
        var parent: Waveform // Access to the parent view
        var onSelectionChange: ((Int, Int) -> Void)?

        let highlightView: UIView = {
            let view = UIView()
            view.backgroundColor = UIColor.blue.withAlphaComponent(0.3)
            return view
        }()

        init(parent: Waveform, constants: Constants, onSelectionChange: ((Int, Int) -> Void)?) {
            self.parent = parent
            renderer = Renderer(device: MTLCreateSystemDefaultDevice()!)
            renderer.constants = constants
            self.onSelectionChange = onSelectionChange
        }

        @objc
        func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
            let location = gesture.location(in: gesture.view)
            let width = gesture.view?.bounds.width ?? 1
            let normalizedLocation = Float(location.x / width)
            highlightView.backgroundColor = UIColor(parent.highlightColor).withAlphaComponent(0.3)

            switch gesture.state {
            case .began:
                parent.highlightStart = normalizedLocation
                gesture.view?.addSubview(highlightView)
                highlightView.frame = CGRect(x: location.x, y: 0, width: 0, height: gesture.view?.bounds.height ?? 0)
            case .changed:
                parent.highlightWidth = normalizedLocation
                highlightView.frame.origin.x = CGFloat(min(parent.highlightStart, parent.highlightWidth)) * width
                highlightView.frame.size.width = CGFloat(abs(parent.highlightWidth - parent.highlightStart)) * width
            case .ended, .cancelled, .failed:
                print("Ended, canceled or failed gesture")
                //gesture.view?.removeSubview(highlightView)
                // Compute the sample range based on the normalized highlight range
                let sampleStart = Int(Float(renderer.samples.count) * parent.highlightStart)
                var sampleEnd = Int(Float(renderer.samples.count) * parent.highlightWidth)
                if sampleEnd >= renderer.samples.count {
                    sampleEnd = renderer.samples.count
                }
                onSelectionChange?(sampleStart, sampleEnd)

            default:
                break
            }
        }
        
        @objc
        func handleTapGesture(_ gesture: UITapGestureRecognizer) {
            if gesture.state == .began {
                print("Started long gesture:\(gesture.location(in: gesture.view))")
            }
            if gesture.state == .ended {
                print("Tap gesture ended, location:\(gesture.location(in: gesture.view))")
                highlightView.removeFromSuperview()
                parent.highlightStart = 0
                parent.highlightWidth = 0
                // Reset the sampleStart and sampleEnd
                onSelectionChange?(0, 0)
            }
        }
    }

    /// Required by UIViewRepresentable
    public func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self, constants: constants, onSelectionChange: onSelectionChange)
    }

    /// Required by UIViewRepresentable
    public func makeUIView(context: Context) -> some UIView {
        let metalView = MTKView(frame: CGRect(x: 0, y: 0, width: 0, height: 0),
                                device: MTLCreateSystemDefaultDevice()!)
        metalView.enableSetNeedsDisplay = true
        metalView.isPaused = true
        metalView.delegate = context.coordinator.renderer
        metalView.layer.isOpaque = false
        
        // Attach the gesture recognizer to the metalView
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePanGesture))
        metalView.addGestureRecognizer(panGesture)
        
        let tapGesture = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTapGesture))
        metalView.addGestureRecognizer(tapGesture)

        return metalView
    }

    /// Required by UIViewRepresentable
    public func updateUIView(_ uiView: UIViewType, context: Context) {
        let renderer = context.coordinator.renderer
        renderer.constants = constants
        Task {
            await renderer.set(samples: samples,
                               start: start,
                               length: length)
            uiView.setNeedsDisplay()
        }
    }
}

#endif

extension Waveform {
    /// Modifer to change the foreground color of the wheel
    /// - Parameter foregroundColor: foreground color
    public func foregroundColor(_ foregroundColor: Color) -> Waveform {
        var copy = self
        copy.constants = Constants(color: foregroundColor)
        return copy
    }
}
