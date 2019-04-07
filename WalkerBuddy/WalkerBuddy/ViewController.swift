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
    
    var tier = 1
    var lSwipe = false
    var rSwipe = false
    var allowedToSwipe = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        say(item: "Press Trigger to Activate")
        //main()
        
        // Always Check
        addSwipeGestureRecognizers()
        object_dectection()
        
        // Different Tiers/Levels
        getting_address()
        dictate_directions()
    }
    
    func main() {
        // Not Working
        if (tier == 1) {
            self.say(item: "Press Trigger to Activate")
        }
        else if (tier == 2) {
            dictate_directions()
        }
    }
    
    func dictate_directions() {
        
        let database = Database.database().reference(fromURL: "https://siteseer.firebaseio.com/").child("maps/order")
        database.observe(.childChanged, with: { (snapshot) in
            print("DICTATE DIRECTIONS")
            let speech = snapshot.value as! String
            self.say(item: speech)
        })

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
                        
                        SpeechService.shared.speak(text: speech, voiceType: .waveNetFemale) { self.startRecording() }
                    }
                    else {
                        speech = userDict["end"] as! String
                        self.stopRecording()
                    }
                    if trigger == true{
                        SpeechService.shared.speak(text: speech, voiceType: .waveNetFemale) { self.startRecording() }
                    }
                    else {
                        // Fixed Audio Problem
                        do {
                            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playAndRecord, mode: .default, options: AVAudioSession.CategoryOptions.defaultToSpeaker)
                        }
                        catch {
                            print("can't default to speaker ")
                        }
                        SpeechService.shared.speak(text: "Destination Recorded. Swipe Left if \(self.textView.text as! String) is your destination, Swipe Right to restart", voiceType: .waveNetFemale) { self.allowedToSwipe = true }
                    }
                })
            })
        })
    }
    
    func object_dectection() {
        // CAMERA Dectection
        let database2 = Database.database().reference(fromURL: "******").child("sight")
        database2.observe(.childChanged, with: { (snapshot) -> Void in
            print("RECOGNIZED NEW OBJECT")
            // In order to get the value, that value needs to be embeded in a dictionary {nameObject : {random: desiredObject} }
            let ref = Database.database().reference(fromURL: "******").child("sight/speech")
            ref.observe(.childAdded, with: { (data) in
                self.say(item: "Alert: There is a \(data.value as! String) in your proximity")
            })
        })
    }
    
    func say(item: Any) { // Speech
        SpeechService.shared.speak(text: "\(item as! String)", voiceType: .waveNetFemale) { }
    }
    
    @objc func pop(){ // Method loops every 4 seconds
        if !self.feed.isLoading{
            self.feed.reload()
        }
        // print("Tier " + "\(tier)")
    }
 
    func addSwipeGestureRecognizers() {
        let leftSwipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(leftSwipe))
        leftSwipeGesture.direction = .left
        self.view.addGestureRecognizer(leftSwipeGesture)
        
        let rightSwipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(rightSwipe))
        rightSwipeGesture.direction = .right
        self.view.addGestureRecognizer(rightSwipeGesture)
    }
    @objc func leftSwipe() {
        resetSwipe()
        print("LSWIPE")
        lSwipe = true
        // viewDidLoad()
        if self.allowedToSwipe == true {
            if (tier == 1){
                //self.allowedToSwipe = false
                self.say(item: "Planning Route to \(self.textView.text as! String)")
                tier = 2
                print("Tier " + "\(tier)")
                let database = Database.database().reference(fromURL: "https://siteseer.firebaseio.com/").child("maps")
                var currentTrigger  = false
                database.updateChildValues(["destination":(self.textView.text)])
                database.child("trigger").setValue(["1":true])
                print("MAKING TRIGGER TRUE")
            }
            //self.allowedToSwipe = false
            print("ALLOWED TO SWIPE FALSE")
        }
    }
    @objc func rightSwipe() {
        resetSwipe()
        print("RSWIPE")
        rSwipe = true
        
        if self.allowedToSwipe {
            if (tier == 1) {
                self.say(item: "Restarting")
                // viewDidLoad()
                print("Restarting")
                print("Tier " + "\(tier)")
            }
            else {
                tier -= 1
                print("Tier " + "\(tier)")
            }
            //self.allowedToSwipe = false
            print("ALLOWED TO SWIPE FALSE")
        }
    }
    func resetSwipe() {
        lSwipe = false
        rSwipe = false
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
            //try audioSession.overrideOutputAudioPort(AVAudioSession.PortOverride)
            try audioSession.setCategory(AVAudioSession.Category.playAndRecord, mode: .default)
            
            try audioSession.setCategory(AVAudioSession.Category.playAndRecord, mode: .default, options:AVAudioSession.CategoryOptions.defaultToSpeaker)
            
            //try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playAndRecord, with:AVAudioSession.CategoryOptions.defaultToSpeaker)
            
            try audioSession.setMode(AVAudioSession.Mode.measurement)
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
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
    
    override func viewDidAppear(_ animated: Bool) {
        let url = URL(string: "******")
        feed.load(URLRequest(url: url!))
        btn.text = "Press Trigger to Activate"
        
        speechRecognizer?.delegate = self  //3
        SFSpeechRecognizer.requestAuthorization { (authStatus) in  //4
            var isButtonEnabled = false
            switch authStatus {  //5
            case .authorized:
                isButtonEnabled = true
            case .denied:
                isButtonEnabled = false
                print("User denied access to speech recognition")
            case .restricted:
                isButtonEnabled = false
                print("Speech recognition restricted on this device")
            case .notDetermined:
                isButtonEnabled = false
                print("Speech recognition not yet authorized")
            }
        }
        
        locManager.requestWhenInUseAuthorization()
        locManager.requestAlwaysAuthorization()
        if CLLocationManager.locationServicesEnabled() {
            locManager.delegate = self
            locManager.desiredAccuracy = kCLLocationAccuracyBest
            locManager.startUpdatingLocation()
        }
        else {
            print("Location authorization not allowed")
        }
        
        timer = Timer.scheduledTimer(timeInterval: 4, target: self, selector: #selector(pop), userInfo: nil, repeats: true)
    }
    
    // UNCOMMENT THIS CODE FOR REAL WORLD TESTING
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let locValue:CLLocationCoordinate2D = manager.location!.coordinate
          // print("\(locValue.latitude) \(locValue.longitude)")
//        let database = Database.database().reference(fromURL: "https://siteseer.firebaseio.com/").child("maps")
//        database.updateChildValues(["latitude":(locValue.latitude)])
//        database.updateChildValues(["longitude":(locValue.longitude)])
        self.locationTextView.text = "\(locValue.latitude), \(locValue.longitude)"
    }
    
}
