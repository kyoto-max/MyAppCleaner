import Foundation
import Observation

@Observable
class StorageManager {
    var totalSpace: Int64 = 0
    var freeSpace: Int64 = 0
    var usedSpace: Int64 = 0
    
    init() {
        updateStorageInfo()
    }
    
    func updateStorageInfo() {
        let fileURL = URL(fileURLWithPath: NSHomeDirectory() as String)
        do {
            let values = try fileURL.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey])
            if let capacity = values.volumeTotalCapacity {
                self.totalSpace = Int64(capacity)
            }
            if let available = values.volumeAvailableCapacityForImportantUsage {
                self.freeSpace = available
            }
            self.usedSpace = self.totalSpace - self.freeSpace
        } catch {
            print("Error retrieving capacity: \(error.localizedDescription)")
        }
    }
    
    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
