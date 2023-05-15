//
//  ViewController.swift
//  NXScreenCapturer
//
//  Created by yxibng on 2023/4/19.
//

import UIKit
import ReplayKit
import WebKit
import AVFoundation



class ViewController: UIViewController {

    @IBOutlet weak var webView: WKWebView! {
        didSet {
            webView.load(.init(url: .init(string: "https://naozhong.net.cn/jishiqi/")!))
        }
    }
    
    var player: AVAudioPlayer?
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    
    
    @IBAction func onStartButtonClick(_ sender: Any) {
        startScreenCapture()
        
        guard let path = Bundle.main.path(forResource: "2486354025", ofType: "mp3") else {return}
        
        let url = NSURL.init(fileURLWithPath: path)
        
        guard let player = try? AVAudioPlayer.init(contentsOf: url as URL) else {
            return
        }
        
        player.prepareToPlay()
        player.play()
        
        self.player = player
        
    }
    
    @IBAction func onStopButtonClick(_ sender: Any) {
        stopScreenCapture()
        self.player?.stop()
    }
    
    func startScreenCapture() {
        RPScreenRecorder.shared().isMicrophoneEnabled = true
        RPScreenRecorder.shared().startCapture(handler: { sampleBuffer, sampleBufferType, err in
            
            if !RPScreenRecorder.shared().isMicrophoneEnabled {
                print("=====not enable mic")
            }
            
            
            switch sampleBufferType {
            case .video:
                self .handleVideoSampleBuffer(sampleBuffer)
            case .audioApp:
                self.handleAppSampleBuffer(sampleBuffer)
            case .audioMic:
                self.handleMicSampleBuffer(sampleBuffer)
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
    
    func handleAppSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        NXManager.shared().handleAppAudioBuffer(sampleBuffer)
    }
    
    func handleMicSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        NXManager.shared().handleMicAudioBuffer(sampleBuffer)
    }
}


