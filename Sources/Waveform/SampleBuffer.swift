// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/Waveform/

import Foundation

/// Immutable data for samples so we can quickly compare to see if we should recompute.
public final class SampleBuffer: Sendable {
    let samples: [Float]

    /// Initialize the buffer with samples
    public init(samples: [Float]) {
        self.samples = samples
    }

    /// Number of samples
    public var count: Int {
        samples.count
    }
}

extension SampleBuffer: Equatable {
    public static func == (lhs: SampleBuffer, rhs: SampleBuffer) -> Bool {
        return lhs.samples == rhs.samples
    }
}
