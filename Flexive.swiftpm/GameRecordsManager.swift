import Foundation
import Combine

class GameRecordsManager: ObservableObject {
    @Published var records: [GameRecord] = []
    private let recordsKey = "flexibilityGameRecords"

    static var highScore: Int { UserDefaults.standard.integer(forKey: "highScore") }
    
    init() {
        loadRecords()
    }
    
    func addRecord(score: Int, clearCount: Int) {
        let record = GameRecord(id: UUID(), score: score, clearCount: clearCount, date: Date())
        records.append(record)
        records.sort { $0.score > $1.score }
        if records.count > 10 {
            records = Array(records.prefix(10))
        }
        saveRecords()
    }
    
    private func saveRecords() {
        if let encoded = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(encoded, forKey: recordsKey)
        }
    }
    
    private func loadRecords() {
        if let data = UserDefaults.standard.data(forKey: recordsKey),
           let decoded = try? JSONDecoder().decode([GameRecord].self, from: data) {
            records = decoded.sorted { $0.score > $1.score }
        }
    }
}
