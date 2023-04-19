//
//  ViewController.swift
//  NXScreenCapturer
//
//  Created by yxibng on 2023/4/19.
//

import UIKit
import ReplayKit



class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    
    
    @IBAction func onStartButtonClick(_ sender: Any) {
        startScreenCapture()
    }
    
    @IBAction func onStopButtonClick(_ sender: Any) {
        stopScreenCapture()
    }
    
    func startScreenCapture() {
        RPScreenRecorder.shared().isMicrophoneEnabled = true
        RPScreenRecorder.shared().startCapture(handler: { sampleBuffer, sampleBufferType, err in
            switch sampleBufferType {
            case .video:
                self .handleVideoSampleBuffer(sampleBuffer)
                break
            case .audioApp:
                print("audioApp = \(sampleBuffer)")
                break
            case .audioMic:
                print("audioMic = \(sampleBuffer)")
                break
            @unknown default:
                fatalError()
            }
        }, completionHandler: { err in
            print(err ?? "")
        })
    }

    func stopScreenCapture() {
        if RPScreenRecorder.shared().isRecording {
            RPScreenRecorder.shared().stopCapture()
        }
    }
}


extension ViewController {
    
    func handleVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        var rotation : Int = 0
        if let orientationAttachment = CMGetAttachment(sampleBuffer, key: RPVideoSampleOrientationKey as CFString, attachmentModeOut: nil) as? NSNumber {
            if let orientation = CGImagePropertyOrientation(rawValue: orientationAttachment.uint32Value) {
                switch orientation {
                case .up,    .upMirrored:    rotation = 0
                case .down,  .downMirrored:  rotation = 180
                case .left,  .leftMirrored:  rotation = 90
                case .right, .rightMirrored: rotation = 270
                default:   break
                }
            }
        }
        print("rotation = \(rotation)")
        
    }
    
    
    
    
}


