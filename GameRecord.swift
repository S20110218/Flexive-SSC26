import Foundation

struct GameRecord: Identifiable, Codable {
    let id: UUID
    let score: Int
    let clearCount: Int
    let date: Date
    
    init(id: UUID = UUID(), score: Int, clearCount: Int, date: Date = Date()) {
        self.id = id
        self.score = score
        self.clearCount = clearCount
        self.date = date
    }
}
