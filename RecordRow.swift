import SwiftUI

struct RecordRow: View {
    let rank: Int
    let record: GameRecord
    
    var body: some View {
        HStack(spacing: 15) {
            Text("#\(rank)")
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(rank <= 3 ? .yellow : .white.opacity(0.6))
                .frame(width: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Score: \(record.score)")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("Clear: \(record.clearCount)")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
                
                Text(formatDate(record.date))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(rank <= 3 ? Color.yellow.opacity(0.2) : Color.white.opacity(0.1))
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }
}
