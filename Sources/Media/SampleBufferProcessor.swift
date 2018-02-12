//
//  SampleBufferProcessor.swift
//  HaishinKit iOS
//
//  Created by Waldemar on 11/02/2018.
//  Copyright © 2018 Shogo Endo. All rights reserved.
//

import AVFoundation

public protocol SampleBufferProcessor: class {
    var delegate: SampleBufferProcessorDelegate? {get set}
    func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer)
}

public protocol SampleBufferProcessorDelegate: class {
    func appendProcessedSampleBuffer(_ sampleBuffer: CMSampleBuffer)
}
