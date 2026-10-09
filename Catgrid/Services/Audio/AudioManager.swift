import AVFoundation
import Foundation

enum SoundEffect: String, CaseIterable {
    case fill
    case cross
    case erase
    case mistake
    case line
    case solved
    case failed
    case tap
    /// Bir türün tüm bulmacaları bitince, yeni kart kazanılınca.
    case card
    /// Oyun ekranındaki küçük kediye dokununca.
    case mew
    /// Dopamin modu: satır/sütun tamamlanınca parıltı.
    case combo
    /// Dopamin modu: bulmaca çözülünce fanfar.
    case fanfare
}

/// Arka plan müziği ve ses efektleri. Ayarlar (aç/kapa, seviye) kalıcıdır.
///
/// Ses oturumu `.ambient`: telefonun sessiz anahtarına uyar ve oyuncunun kendi
/// müziğini/podcast'ini kesmez.
@MainActor
@Observable
final class AudioManager {
    enum Keys {
        static let musicEnabled = "audio.musicEnabled"
        static let musicVolume = "audio.musicVolume"
        static let effectsEnabled = "audio.effectsEnabled"
        static let effectsVolume = "audio.effectsVolume"
    }

    var musicEnabled: Bool {
        didSet {
            defaults.set(musicEnabled, forKey: Keys.musicEnabled)
            if musicEnabled {
                resumeMusic()
            } else {
                musicPlayer?.pause()
            }
        }
    }

    /// 0...1
    var musicVolume: Double {
        didSet {
            defaults.set(musicVolume, forKey: Keys.musicVolume)
            musicPlayer?.volume = Float(musicVolume) * Self.musicHeadroom
        }
    }

    var effectsEnabled: Bool {
        didSet { defaults.set(effectsEnabled, forKey: Keys.effectsEnabled) }
    }

    /// 0...1
    var effectsVolume: Double {
        didSet { defaults.set(effectsVolume, forKey: Keys.effectsVolume) }
    }

    /// Müzik efektlerin altında kalsın diye tam seviyede bile kısık çalar.
    private static let musicHeadroom: Float = 0.45
    /// Sürüklerken her karede ses çıkmasın: aynı efekt bu aralıktan sık çalınmaz.
    private static let minimumEffectInterval: TimeInterval = 0.045

    private let defaults: UserDefaults
    private let bundle: Bundle
    private var musicPlayer: AVAudioPlayer?
    private var effectPlayers: [SoundEffect: [AVAudioPlayer]] = [:]
    private var lastPlayed: [SoundEffect: Date] = [:]
    private var isMusicRequested = false
    /// Çalan müzik: Rahat modda sakin, Dopamin modunda hareketli döngü.
    private var musicTrack = "music_cozy"

    init(defaults: UserDefaults = .standard, bundle: Bundle = .main) {
        self.defaults = defaults
        self.bundle = bundle
        musicEnabled = defaults.object(forKey: Keys.musicEnabled) as? Bool ?? true
        musicVolume = defaults.object(forKey: Keys.musicVolume) as? Double ?? 0.6
        effectsEnabled = defaults.object(forKey: Keys.effectsEnabled) as? Bool ?? true
        effectsVolume = defaults.object(forKey: Keys.effectsVolume) as? Double ?? 0.8
    }

    /// Uygulama açılınca bir kez çağrılır.
    func prepare() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        for effect in SoundEffect.allCases {
            // Hızlı art arda çalınabilsin diye her efekt için küçük bir oynatıcı havuzu
            effectPlayers[effect] = (0..<3).compactMap { _ in makePlayer(effect.rawValue, extension: "wav") }
        }
    }

    // MARK: - Müzik

    func startMusic() {
        isMusicRequested = true
        resumeMusic()
    }

    /// Arka plana geçerken.
    func pauseMusic() {
        musicPlayer?.pause()
    }

    /// Oyun moduna göre müziği değiştirir; aynıysa bir şey yapmaz.
    func setMusicTrack(_ name: String) {
        guard name != musicTrack else { return }
        musicTrack = name
        musicPlayer?.stop()
        musicPlayer = nil
        resumeMusic()
    }

    func resumeMusic() {
        guard isMusicRequested, musicEnabled else { return }
        if musicPlayer == nil {
            musicPlayer = makePlayer(musicTrack, extension: "m4a")
            musicPlayer?.numberOfLoops = -1
        }
        musicPlayer?.volume = Float(musicVolume) * Self.musicHeadroom
        if musicPlayer?.isPlaying == false { musicPlayer?.play() }
    }

    // MARK: - Efektler

    func play(_ effect: SoundEffect) {
        guard effectsEnabled, effectsVolume > 0 else { return }
        let now = Date()
        if let last = lastPlayed[effect], now.timeIntervalSince(last) < Self.minimumEffectInterval { return }
        lastPlayed[effect] = now
        guard let player = effectPlayers[effect]?.first(where: { !$0.isPlaying }) ?? effectPlayers[effect]?.first else { return }
        player.volume = Float(effectsVolume)
        player.currentTime = 0
        player.play()
    }

    private func makePlayer(_ name: String, extension ext: String) -> AVAudioPlayer? {
        guard let url = bundle.url(forResource: name, withExtension: ext) else { return nil }
        let player = try? AVAudioPlayer(contentsOf: url)
        player?.prepareToPlay()
        return player
    }
}
