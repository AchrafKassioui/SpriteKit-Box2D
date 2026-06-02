/**
 
 # Performance Logger
 
 Achraf Kassioui
 Created 19 May 2026
 Updated 19 May 2026
 
 */
import SpriteKit

struct PhysicsStepProfiler {
    let label: String
    let warmupDuration: TimeInterval
    let sampleDuration: TimeInterval
    
    private var startTime: TimeInterval?
    private var samples: [Double] = []
    private var didPrintSummary = false
    
    init(label: String, warmupDuration: TimeInterval = 1, sampleDuration: TimeInterval = 12) {
        self.label = label
        self.warmupDuration = warmupDuration
        self.sampleDuration = sampleDuration
    }
    
    mutating func record(milliseconds: Double) {
        guard didPrintSummary == false else { return }
        
        let now = CACurrentMediaTime()
        
        if startTime == nil {
            startTime = now
        }
        
        guard let startTime else { return }
        
        let elapsed = now - startTime
        
        if elapsed < warmupDuration {
            return
        }
        
        if elapsed < warmupDuration + sampleDuration {
            samples.append(milliseconds)
            return
        }
        
        printSummary()
        didPrintSummary = true
    }
    
    private mutating func printSummary() {
        guard samples.isEmpty == false else {
            print("\(label): no samples")
            return
        }
        
        let sorted = samples.sorted()
        let mean = samples.reduce(0, +) / Double(samples.count)
        let median = sorted[sorted.count / 2]
        let p95Index = min(sorted.count - 1, Int(Double(sorted.count - 1) * 0.95))
        let p95 = sorted[p95Index]
        let minValue = sorted.first ?? 0
        let maxValue = sorted.last ?? 0
        
        print("""
        Results:
            samples: \(samples.count)
            mean: \(String(format: "%.3f", mean)) ms
            median: \(String(format: "%.3f", median)) ms
            p95: \(String(format: "%.3f", p95)) ms
            min: \(String(format: "%.3f", minValue)) ms
            max: \(String(format: "%.3f", maxValue)) ms
        """)
    }
}
