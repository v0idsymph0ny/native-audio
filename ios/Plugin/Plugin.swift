import AVFoundation
import Foundation
import Capacitor
import CoreAudio
import MediaPlayer

enum MyError: Error {
    case runtimeError(String)
}

/**
 * Please read the Capacitor iOS Plugin Development Guide
 * here: https://capacitor.ionicframework.com/docs/plugins/ios
 */
@objc(NativeAudio)
public class NativeAudio: CAPPlugin {

    var audioList: [String: Any] = [:]
    var fadeMusic = false
    var session = AVAudioSession.sharedInstance()
    var audioEngine: AVAudioEngine?
    var audioPlayerNode: AVAudioPlayerNode?
    var analyzerNode: AVAudioMixerNode?

    override public func load() {
        super.load()

        self.fadeMusic = false

        do {
            try self.session.setCategory(AVAudioSession.Category.playback)
            try self.session.setActive(false)
        } catch {
            print("Failed to set session category")
        }

        // Initialize the audio engine
        audioEngine = AVAudioEngine()
        audioPlayerNode = AVAudioPlayerNode()
        analyzerNode = AVAudioMixerNode()

        if let engine = audioEngine, let player = audioPlayerNode, let analyzer = analyzerNode {
            engine.attach(player)
            engine.attach(analyzer)
            
            engine.connect(player, to: analyzer, format: nil)
            engine.connect(analyzer, to: engine.outputNode, format: nil)

            analyzer.installTap(onBus: 0, bufferSize: 1024, format: engine.outputNode.outputFormat(forBus: 0)) { buffer, _ in
                self.analyzeAudioBuffer(buffer: buffer)
            }
        }

        setupRemoteCommandCenter()
    }

    @objc func configure(_ call: CAPPluginCall) {
        self.fadeMusic = call.getBool(Constant.FadeKey, false)
        do {
            if call.getBool(Constant.FocusAudio, false) {
                try self.session.setCategory(AVAudioSession.Category.playback)
            } else {
                try self.session.setCategory(AVAudioSession.Category.ambient)
            }
        } catch {
            print("Failed to set setCategory audio")
        }
        call.resolve()
    }

    @objc func preload(_ call: CAPPluginCall) {
        preloadAsset(call, isComplex: true)
    }

    @objc func play(_ call: CAPPluginCall) {
        let audioId = call.getString(Constant.AssetIdKey) ?? ""
        let time = call.getDouble("time") ?? 0
        if audioId != "" {
            let queue = DispatchQueue(label: "com.getcapacitor.community.audio.complex.queue", qos: .userInitiated)

            queue.async {
                if self.audioList.count > 0 {
                    let asset = self.audioList[audioId]

                    if asset != nil {
                        if asset is AudioAsset {
                            let audioAsset = asset as? AudioAsset

                            if self.fadeMusic {
                                audioAsset?.playWithFade(time: time)
                            } else {
                                audioAsset?.play(time: time)
                            }

                            /*
                            // Update the Now Playing Info Center
                            if let asset = audioAsset {
                                self.updateNowPlayingInfo(forAudioAsset: asset)
                            }
                            */

                            call.resolve()
                        } else if asset is Int32 {
                            let audioAsset = asset as? NSNumber ?? 0
                            AudioServicesPlaySystemSound(SystemSoundID(audioAsset.intValue ))
                            call.resolve()
                        } else {
                            call.reject(Constant.ErrorAssetNotFound)
                        }
                    }
                }
            }
        }
    }

    @objc private func getAudioAsset(_ call: CAPPluginCall) -> AudioAsset? {
        let audioId = call.getString(Constant.AssetIdKey) ?? ""
        if audioId == "" {
            call.reject(Constant.ErrorAssetId)
            return nil
        }
        if self.audioList.count > 0 {
            let asset = self.audioList[audioId]
            if asset != nil && asset is AudioAsset {
                return asset as? AudioAsset
            }
        }
        call.reject(Constant.ErrorAssetNotFound + " - " + audioId)
        return nil
    }

    @objc func getDuration(_ call: CAPPluginCall) {
        guard let audioAsset: AudioAsset = self.getAudioAsset(call) else {
            return
        }

        call.resolve([
            "duration": audioAsset.getDuration()
        ])
    }

    @objc func getCurrentTime(_ call: CAPPluginCall) {
        guard let audioAsset: AudioAsset = self.getAudioAsset(call) else {
            return
        }

        call.resolve([
            "currentTime": audioAsset.getCurrentTime()
        ])
    }

    @objc func resume(_ call: CAPPluginCall) {
        guard let audioAsset: AudioAsset = self.getAudioAsset(call) else {
            return
        }

        audioAsset.resume()
        call.resolve()
    }

    @objc func pause(_ call: CAPPluginCall) {
        guard let audioAsset: AudioAsset = self.getAudioAsset(call) else {
            return
        }

        audioAsset.pause()
        call.resolve()
    }

    @objc func stop(_ call: CAPPluginCall) {
        let audioId = call.getString(Constant.AssetIdKey) ?? ""

        do {
            try stopAudio(audioId: audioId)
            call.resolve()
        } catch {
            call.reject(Constant.ErrorAssetNotFound)
        }
    }

    @objc func loop(_ call: CAPPluginCall) {
        guard let audioAsset: AudioAsset = self.getAudioAsset(call) else {
            return
        }

        audioAsset.loop()
        call.resolve()
    }

    @objc func unload(_ call: CAPPluginCall) {
        let audioId = call.getString(Constant.AssetIdKey) ?? ""
        if self.audioList.count > 0 {
            let asset = self.audioList[audioId]
            if asset != nil && asset is AudioAsset {
                let audioAsset = asset as! AudioAsset
                audioAsset.unload()
                self.audioList[audioId] = nil
            }
        }
        call.resolve()
    }

    @objc func setVolume(_ call: CAPPluginCall) {
        guard let audioAsset: AudioAsset = self.getAudioAsset(call) else {
            return
        }

        let volume = call.getFloat(Constant.Volume) ?? 1.0

        audioAsset.setVolume(volume: volume as NSNumber)
        call.resolve()
    }

    @objc func isPlaying(_ call: CAPPluginCall) {
        guard let audioAsset: AudioAsset = self.getAudioAsset(call) else {
            return
        }

        call.resolve([
            "isPlaying": audioAsset.isPlaying()
        ])
    }

    @objc func updateNowPlayingInfo(_ call: CAPPluginCall) {
        guard let audioAsset: AudioAsset = self.getAudioAsset(call) else {
            return
        }

        let title: String = call.getString("title") ?? ""

        let artist: String = call.getString("artist") ?? ""

        self.updateNowPlayingInfo(forAudioAsset: audioAsset, title: title, artist: artist)

        call.resolve()
    }

    @objc func seek(_ call: CAPPluginCall) {
        guard let audioAsset: AudioAsset = self.getAudioAsset(call) else {
            return
        }

        //let audioId = call.getString(Constant.AssetIdKey) ?? ""
        let time = call.getDouble("time") ?? 0

        audioAsset.seek(to: time)

        call.resolve()
    }

    private func preloadAsset(_ call: CAPPluginCall, isComplex complex: Bool) {
        let audioId = call.getString(Constant.AssetIdKey) ?? ""
        let channels: NSNumber?
        let volume: Float?
        let delay: NSNumber?
        let isUrl: Bool?

        if audioId != "" {
            let assetPath: String = call.getString(Constant.AssetPathKey) ?? ""

            if complex {
                volume = call.getFloat("volume") ?? 1.0
                channels = NSNumber(value: call.getInt("channels") ?? 1)
                delay = NSNumber(value: call.getInt("delay") ?? 1)
                isUrl = call.getBool("isUrl") ?? false
            } else {
                channels = 0
                volume = 0
                delay = 0
                isUrl = false
            }

            if audioList.isEmpty {
                audioList = [:]
            }

            let asset = audioList[audioId]
            let queue = DispatchQueue(label: "com.getcapacitor.community.audio.simple.queue", qos: .userInitiated)

            queue.async {
                if asset == nil {
                    var basePath: String?
                    if isUrl == false {
                        let docsPath = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
                        basePath = docsPath.appendingPathComponent(assetPath).path
                    } else {
                        let url = URL(string: assetPath)
                        basePath = url!.path
                    }

                    if FileManager.default.fileExists(atPath: basePath ?? "") {
                        if !complex {
                            let pathUrl = URL(fileURLWithPath: basePath ?? "")
                            let soundFileUrl: CFURL = CFBridgingRetain(pathUrl) as! CFURL
                            var soundId = SystemSoundID()
                            AudioServicesCreateSystemSoundID(soundFileUrl, &soundId)
                            self.audioList[audioId] = NSNumber(value: Int32(soundId))
                            call.resolve()
                        } else {
                            let audioAsset: AudioAsset = AudioAsset(owner: self, withAssetId: audioId, withPath: basePath, withChannels: channels, withVolume: volume as NSNumber?, withFadeDelay: delay)
                            self.audioList[audioId] = audioAsset
                            call.resolve()
                        }
                    } else {
                        call.reject(Constant.ErrorAssetPath + " - " + assetPath)
                    }
                } else {
                    call.reject(Constant.ErrorAssetExists)
                }
            }
        }
    }

    private func stopAudio(audioId: String) throws {
        if self.audioList.count > 0 {
            let asset = self.audioList[audioId]

            if asset != nil {
                if asset is AudioAsset {
                    let audioAsset = asset as? AudioAsset

                    if self.fadeMusic {
                        audioAsset?.playWithFade(time: audioAsset?.getCurrentTime() ?? 0)
                    } else {
                        audioAsset?.stop()
                    }
                }
            } else {
                throw MyError.runtimeError(Constant.ErrorAssetNotFound)
            }
        }
    }

    public func updateNowPlayingInfo(forAudioAsset audioAsset: AudioAsset, title: String, artist: String) {
        let nowPlayingInfoCenter = MPNowPlayingInfoCenter.default()
        var nowPlayingInfo = [String: Any]()

        nowPlayingInfo[MPMediaItemPropertyTitle] = title
        nowPlayingInfo[MPMediaItemPropertyArtist] = artist
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = audioAsset.getCurrentTime()
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = audioAsset.getDuration()
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1.0

        nowPlayingInfoCenter.nowPlayingInfo = nowPlayingInfo
    }

    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { event in
            if let audioAsset = self.audioList.values.first as? AudioAsset {
                audioAsset.resume()
                //self.updateNowPlayingInfo(forAudioAsset: audioAsset)
            }
            return .success
        }

        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            if let audioAsset = self.audioList.values.first as? AudioAsset {
                audioAsset.seek(to: event.positionTime)
                //self.updateNowPlayingInfo(forAudioAsset: audioAsset)
            }
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { event in
            if let audioAsset = self.audioList.values.first as? AudioAsset {
                audioAsset.pause()
                //self.updateNowPlayingInfo(forAudioAsset: audioAsset)
            }
            return .success
        }

        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { event in
            if let audioAsset = self.audioList.values.first as? AudioAsset {
                self.notifyListeners("nextTrackCommandWasPressed", data: [
                    "assetId": audioAsset.assetId
                ])
            }
            return .success
        }

        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { event in
            if let audioAsset = self.audioList.values.first as? AudioAsset {
                self.notifyListeners("previousTrackCommandWasPressed", data: [
                    "assetId": audioAsset.assetId
                ])
            }
            return .success
        }
    }

    func analyzeAudioBuffer(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let channelDataValue = channelData.pointee
        let channelDataArray = Array(UnsafeBufferPointer(start: channelDataValue, count: Int(buffer.frameLength)))
        
        // Perform analysis (e.g., FFT) and extract relevant data
        // Here you can perform frequency analysis and create a frequency bin array
        
        // Send data to frontend
        self.notifyListeners("audioVisualizationData", data: [
            "frequencyBins": channelDataArray
        ])
    }
}
