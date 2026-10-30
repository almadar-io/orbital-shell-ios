// R1-device-ios host: loads liborbital_ffi through the kernel C ABI and times the parity workloads
// (`@almadar-io/kernel-bench-tool gen-device-workloads` writes them). Prints one JSON line.
// Usage: bench <workload-dir> [--sustained]
import Foundation

let viewer = #"{"id":"viewer-1","name":"Dev Viewer","email":"viewer@example.com","role":""}"#
let frameBudgetMs = 1000.0 / 60.0
let sustainedSeconds = 300.0

func nowMs() -> Double { Double(clock_gettime_nsec_np(CLOCK_UPTIME_RAW)) / 1_000_000.0 }

func percentile(_ values: [Double], _ p: Double) -> Double {
    guard !values.isEmpty else { return 0 }
    let sorted = values.sorted()
    let rank = Int((p / 100.0 * Double(sorted.count)).rounded(.up))
    return sorted[min(max(rank, 1), sorted.count) - 1]
}

func stats(_ samples: [Double]) -> [String: Any] {
    ["samples": samples.count, "p50Ms": percentile(samples, 50), "p95Ms": percentile(samples, 95), "maxMs": samples.max() ?? 0]
}

/// Copies a library-allocated result out and frees it; nil for a null result.
func take(_ raw: UnsafeMutablePointer<CChar>?) -> String? {
    guard let raw = raw else { return nil }
    let text = String(cString: raw)
    orbital_kernel_free_string(raw)
    return text
}

func parse(_ file: URL) throws -> [String: Any] {
    guard let spec = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any] else {
        throw NSError(domain: "bench", code: 1, userInfo: [NSLocalizedDescriptionKey: "\(file.path): not an object"])
    }
    return spec
}

func json(_ value: Any) -> String {
    let data = (try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed, .sortedKeys])) ?? Data()
    return String(decoding: data, as: UTF8.self)
}

func open(_ spec: [String: Any]) throws -> OpaquePointer {
    guard let handle = orbital_kernel_init(json(spec["schema"] ?? [:]), "bench") else {
        throw NSError(domain: "bench", code: 2, userInfo: [NSLocalizedDescriptionKey: "orbital_kernel_init returned null"])
    }
    orbital_kernel_set_current_user(handle, viewer)
    return handle
}

func runDispatch(_ id: String, _ spec: [String: Any]) throws -> [String: Any] {
    let handle = try open(spec)
    defer { orbital_kernel_destroy(handle) }
    let steps = (spec["steps"] as? [[String: Any]] ?? []).map { step in
        (step["trait"] as? String ?? "", step["event"] as? String ?? "", json(step["payload"] ?? [:]))
    }
    let events = spec["events"] as? Int ?? 0
    var latencies: [Double] = []
    latencies.reserveCapacity(events)
    var errors = 0
    for i in 0..<events {
        let (trait, event, payload) = steps[i % steps.count]
        let start = nowMs()
        let result = take(orbital_kernel_dispatch(handle, trait, nil, event, payload))
        latencies.append(nowMs() - start)
        if result == nil || result!.hasPrefix(#"{"error""#) { errors += 1 }
    }
    return ["id": id, "kind": "dispatch", "dispatchMs": stats(latencies), "errors": errors]
}

func runFrames(_ id: String, _ spec: [String: Any], sustained: Bool) throws -> [String: Any] {
    let handle = try open(spec)
    defer { orbital_kernel_destroy(handle) }
    let ticks = spec["ticks"] as? Int ?? 0
    let step = spec["frameStepMs"] as? Double ?? frameBudgetMs
    for name in spec["bootTraits"] as? [String] ?? [] { _ = take(orbital_kernel_dispatch(handle, name, nil, "INIT", nil)) }
    let declared = Int(orbital_kernel_tick_count(handle))
    guard declared == ticks else { throw NSError(domain: "bench", code: 3, userInfo: [NSLocalizedDescriptionKey: "\(id): kernel declares \(declared) ticks, expected \(ticks)"]) }
    _ = take(orbital_kernel_frame(handle, 0))
    let frames = sustained ? Int.max : (spec["frames"] as? Int ?? 0)
    var kernelMs: [Double] = []
    var firstMinute: [Double] = []
    var lastMinute: [Double] = []
    var fired = 0
    var dropped = 0
    let wallStart = nowMs()
    var i = 1
    while i <= frames {
        let virtualMs = UInt64(Double(i) * step)
        let start = nowMs()
        let result = take(orbital_kernel_frame(handle, virtualMs))
        let spent = nowMs() - start
        if i == 1, let result = result, let wire = try? JSONSerialization.jsonObject(with: Data(result.utf8)) as? [String: Any] {
            fired = (wire["fired"] as? [String: [Any]])?.values.reduce(0) { $0 + $1.count } ?? 0
        }
        kernelMs.append(spent)
        if spent > frameBudgetMs { dropped += 1 }
        if sustained {
            let elapsedS = (nowMs() - wallStart) / 1000.0
            if elapsedS < 60 { firstMinute.append(spent) }
            if elapsedS >= sustainedSeconds - 60 { lastMinute.append(spent) }
            if elapsedS >= sustainedSeconds { break }
            let next = wallStart + Double(i) * frameBudgetMs
            let wait = next - nowMs()
            if wait > 0 { usleep(UInt32(wait * 1000)) }
        }
        i += 1
    }
    var out: [String: Any] = ["id": id, "kind": "frame", "ticks": ticks, "firedOnFirstFrame": fired, "kernelFrameMs": stats(kernelMs), "droppedFrames": dropped, "frameBudgetMs": frameBudgetMs]
    if sustained { out["firstMinuteP50Ms"] = percentile(firstMinute, 50); out["lastMinuteP50Ms"] = percentile(lastMinute, 50) }
    return out
}

let args = CommandLine.arguments
guard args.count >= 2 else { FileHandle.standardError.write(Data("usage: bench <workload-dir> [--sustained]\n".utf8)); exit(2) }
let sustained = args.contains("--sustained")
let dir = URL(fileURLWithPath: args[1])
var results: [[String: Any]] = []
do {
    let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil).filter { $0.pathExtension == "json" }.sorted { $0.path < $1.path }
    for file in files {
        let spec = try parse(file)
        let id = spec["id"] as? String ?? file.lastPathComponent
        switch spec["kind"] as? String {
        case "dispatch": results.append(try runDispatch(id, spec))
        case "frame":
            results.append(try runFrames(id, spec, sustained: false))
            if sustained && (spec["ticks"] as? Int) == 1000 { results.append(try runFrames("sustained-5min", spec, sustained: true)) }
        default: throw NSError(domain: "bench", code: 4, userInfo: [NSLocalizedDescriptionKey: "\(id): unknown kind"])
        }
    }
    let report: [String: Any] = ["row": "R1-device-ios", "workloads": results, "outstandingStrings": Int(orbital_kernel_outstanding_strings())]
    print(json(report))
} catch {
    print(json(["row": "R1-device-ios", "error": error.localizedDescription]))
    exit(1)
}
