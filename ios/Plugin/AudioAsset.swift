//
//  AudioAsset.swift
//  Plugin
//
//  Created by priyank on 2020-05-29.
//  Copyright © 2020 Max Lynch. All rights reserved.
//

import AVFoundation

public class AudioAsset: NSObject, AVAudioPlayerDelegate {

    var channels: NSMutableArray = NSMutableArray()
    var playIndex: Int = 0
    var assetId: String = ""
    var initialVolume: NSNumber = 1.0
    var fadeDelay: NSNumber = 1.0
    var owner: NativeAudio

    let FADE_STEP: Float = 0.05
    let FADE_DELAY: Float = 0.08

    init(owner: NativeAudio, withAssetId assetId: String, withPath path: String!, withChannels channels: NSNumber!, withVolume volume: NSNumber!, withFadeDelay delay: NSNumber!) {

        self.owner = owner
        self.assetId = assetId
        self.channels = NSMutableArray.init(capacity: channels as! Int)

        super.init()

        let pathUrl: NSURL! = NSURL.fileURL(withPath: path) as NSURL

        for _ in 0..<channels.intValue {
            do {
                let player: AVAudioPlayer! = try AVAudioPlayer(contentsOf: pathUrl as URL)

                if player != nil {
                    player.volume = volume.floatValue
                    player.prepareToPlay()
                    self.channels.addObjects(from: [player as Any])
                    if channels == 1 {
                        player.delegate = self
                    }
                }
            } catch {

            }
        }
    }

    func getCurrentTime() -> TimeInterval {
        if channels.count != 1 {
            return 0
        }

        let player: AVAudioPlayer = channels.object(at: playIndex) as! AVAudioPlayer

        return player.currentTime
    }

    func getDuration() -> TimeInterval {
        if channels.count != 1 {
            return 0
        }

        let player: AVAudioPlayer = channels.object(at: playIndex) as! AVAudioPlayer

        return player.duration
    }

    func play(time: TimeInterval) {
        guard channels.count > 0 else {
            // Notify frontend or log the issue if channels are empty.
            self.owner.notifyListeners("audioError", data: [
                "assetId": self.assetId,
                "message": "No available audio channels to play the file."
            ])
            print("Error: No available audio channels to play the file.")
            return
        }

        let player: AVAudioPlayer = channels.object(at: playIndex) as! AVAudioPlayer
        player.currentTime = time
        player.numberOfLoops = 0
        player.play()

        // Ensure playIndex is cycled through available channels
        playIndex = (playIndex + 1) % channels.count

        self.owner.notifyListeners("audioHasStartedPlaying", data: [
            "assetId": self.assetId
        ])
    }

    func playWithFade(time: TimeInterval) {
        let player: AVAudioPlayer! = channels.object(at: playIndex) as? AVAudioPlayer
        player.currentTime = time

        if !player.isPlaying {
            player.numberOfLoops = 0
            player.volume = 0
            player.play()
            playIndex = Int(truncating: NSNumber(value: playIndex + 1))
            playIndex = Int(truncating: NSNumber(value: playIndex % channels.count))
        } else {
            if player.volume < initialVolume.floatValue {
                player.volume = player.volume + self.FADE_STEP
            }
        }

        self.owner.notifyListeners("audioHasStartedPlaying", data: [
            "assetId": self.assetId
        ])
    }

    func pause() {
        let player: AVAudioPlayer = channels.object(at: playIndex) as! AVAudioPlayer
        player.pause()

        self.owner.notifyListeners("audioHasPausedPlaying", data: [
            "assetId": self.assetId
        ])
    }

    func resume() {
        let player: AVAudioPlayer = channels.object(at: playIndex) as! AVAudioPlayer

        let timeOffset = player.deviceCurrentTime + 0.01
        player.play(atTime: timeOffset)

        self.owner.notifyListeners("audioHasResumedPlaying", data: [
            "assetId": self.assetId
        ])
    }

    func stop() {
        for i in 0..<channels.count {
            let player: AVAudioPlayer! = channels.object(at: i) as? AVAudioPlayer
            player.stop()
        }

        self.owner.notifyListeners("audioHasStoppedPlaying", data: [
            "assetId": self.assetId
        ])
    }

    func stopWithFade() {
        let player: AVAudioPlayer! = channels.object(at: playIndex) as? AVAudioPlayer

        if !player.isPlaying {
            player.currentTime = 0.0
            player.numberOfLoops = 0
            player.volume = 0
            player.play()
            playIndex = Int(truncating: NSNumber(value: playIndex + 1))
            playIndex = Int(truncating: NSNumber(value: playIndex % channels.count))
        } else {
            if player.volume < initialVolume.floatValue {
                player.volume = player.volume + self.FADE_STEP
            }
        }

        self.owner.notifyListeners("audioHasStoppedPlaying", data: [
            "assetId": self.assetId
        ])
    }

    func loop() {
        self.stop()

        let player: AVAudioPlayer! = channels.object(at: Int(playIndex)) as? AVAudioPlayer
        player.numberOfLoops = -1
        player.play()
        playIndex = Int(truncating: NSNumber(value: playIndex + 1))
        playIndex = Int(truncating: NSNumber(value: playIndex % channels.count))
    }

    func unload() {
        self.stop()

        //        for i in 0..<channels.count {
        //            var player: AVAudioPlayer! = channels.object(at: i) as? AVAudioPlayer
        //
        //            player = nil
        //        }

        channels = NSMutableArray()
    }

    func setVolume(volume: NSNumber!) {
        for i in 0..<channels.count {
            let player: AVAudioPlayer! = channels.object(at: i) as? AVAudioPlayer
            player.volume = volume.floatValue
        }
    }

    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // Check if the player has reached the end of the file
        NSLog("CurrentTime: \(player.currentTime), Duration: \(player.duration), Flag: \(flag)")

        if flag {
            NSLog("playerDidFinish")
            self.owner.notifyListeners("complete", data: [
                "assetId": self.assetId
            ])
        } else {
            NSLog("player stopped early or interrupted")
        }
    }

    func playerDecodeError(player: AVAudioPlayer!, error: NSError!) {

    }

    func isPlaying() -> Bool {
        if channels.count != 1 {
            return false
        }

        let player: AVAudioPlayer = channels.object(at: playIndex) as! AVAudioPlayer

        return player.isPlaying
    }

    func seek(to time: TimeInterval) {
        let player: AVAudioPlayer = channels.object(at: playIndex) as! AVAudioPlayer
        player.currentTime = time
    }
}
