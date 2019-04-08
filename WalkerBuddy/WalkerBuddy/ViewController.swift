//
//  ViewController.swift
//  ConnectRaspi
//
//  Created by Kevin Chen on 4/6/2019.
//  Copyright © 2019 New York University. All rights reserved.
//

import UIKit
import Firebase
import WebKit
import Speech
import CoreLocation
import MapKit
 
class ViewController: UIViewController, SFSpeechRecognizerDelegate, CLLocationManagerDelegate {
    
    @IBOutlet weak var btn: UILabel!
    var timer = Timer()
    @IBOutlet weak var feed: WKWebView!
    @IBOutlet weak var textView: UILabel!
    var locManager = CLLocationManager()
    var currentLocation: CLLocation!
    @IBOutlet weak var locationTextView: UILabel!
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.init(identifier: "en-US"))  //1
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    override func viewDidLoad() {
        super.viewDidLoad()
        say(item: "Press Trigger to Activate")
    }
    
    func getting_address() {
        
        tier = 1
        // NEW LOCATION Detection
        let database = Database.database().reference(fromURL: "*****").child("restart")
        database.observe(.childChanged, with: { (snapshot) -> Void in
            print("RECOGNIZED RESTART")
            //self.feed.reload()
            var trigger = false
            var speech = "Nothing to Say"
            database.observeSingleEvent(of: .value, with: { (snapshot) in
                let userDict = snapshot.value as! [String: Any]
                trigger = userDict["triggeredPressed"] as! Bool

                let ref = Database.database().reference(fromURL: "******").child("restart/speech")
                ref.observeSingleEvent(of: .value, with: { (snapshot) in
                    let userDict = snapshot.value as! [String: Any]
                    if trigger == true {
                        speech = userDict["start"] as! String
                    }
                    else {
                        speech = userDict["end"] as! String
                        self.stopRecording()
                    }
                    if trigger == true{
                        SpeechService.shared.speak(text: speech, voiceType: .waveNetFemale) { self.startRecording() }
                    }
                    else {
                        do {
                            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playAndRecord, mode: .default, options: AVAudioSession.CategoryOptions.defaultToSpeaker)
                        }
                        catch {
                            print("can't default to speaker ")
                        }
                    }
                })
            })
        })
    }
    
    func stopRecording() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        btn.text = "Press Trigger to Activate"
    }
    
    func startRecording() {
        
        btn.text = "Listening ..."
        textView.text = "Where do you want to go, I'm listening!"
        
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(AVAudioSession.Category.playAndRecord, mode: .default)
        } catch {
            print("audioSession properties weren't set because of an error.")
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        let inputNode = audioEngine.inputNode
        
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create an SFSpeechAudioBufferRecognitionRequest object")
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest, resultHandler: { (result, error) in
            
            var isFinal = false
            
            if result != nil {
                
                self.textView.text = result?.bestTranscription.formattedString
                isFinal = (result?.isFinal)!
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                self.btn.isEnabled = true
            }
        })
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
        } catch {
            print("audioEngine couldn't start because of an error.")
        }
        
    }
}
