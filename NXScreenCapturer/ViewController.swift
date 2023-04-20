//
//  ViewController.swift
//  NXScreenCapturer
//
//  Created by yxibng on 2023/4/19.
//

import UIKit
import ReplayKit
import WebKit



class ViewController: UIViewController {

    @IBOutlet weak var webView: WKWebView! {
        didSet {
            webView.load(.init(url: .init(string: "https://www.toutiao.com/video/6923901776512942599/?log_from=63fd615683f0d_1681913305384")!))
        }
    }
    
    
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
//                print("audioApp = \(sampleBuffer)")
                break
            case .audioMic:
//                print("audioMic = \(sampleBuffer)")
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
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds * 1000
        NXManager.shared().handleVideoPixelBuffer(pixelBuffer, timestamp: Int64(timestamp))
    }
    
}


