import Foundation

/// Bir kedi türünün tüm bulmacaları çözülünce kazanılan koleksiyon kartı.
public struct BreedCard: Hashable, Sendable, Decodable {
    public enum Rarity: String, Hashable, Sendable, Decodable, CaseIterable {
        case common
        case rare
        case epic
        case legendary
    }

    /// 1-5 arası puanlar.
    public struct Stats: Hashable, Sendable, Decodable {
        public let energy: Int
        public let affection: Int
        public let playfulness: Int
        public let grooming: Int

        public init(energy: Int, affection: Int, playfulness: Int, grooming: Int) {
            self.energy = energy
            self.affection = affection
            self.playfulness = playfulness
            self.grooming = grooming
        }
    }

    /// Koleksiyondaki sıra numarası (#01, #02...).
    public let number: Int
    public let rarity: Rarity
    public let origin: LocalizedText
    /// Yıl aralığı, ör. "12–15".
    public let lifespan: String
    public let coat: LocalizedText
    public let stats: Stats
    public let fact: LocalizedText

    public init(
        number: Int,
        rarity: Rarity,
        origin: LocalizedText,
        lifespan: String,
        coat: LocalizedText,
        stats: Stats,
        fact: LocalizedText
    ) {
        self.number = number
        self.rarity = rarity
        self.origin = origin
        self.lifespan = lifespan
        self.coat = coat
        self.stats = stats
        self.fact = fact
    }
}
