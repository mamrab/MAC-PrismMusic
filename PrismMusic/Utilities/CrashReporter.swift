import Foundation

final class CrashReporter: @unchecked Sendable {
    static let shared = CrashReporter()
    
    private let crashKey = "LastCrashReport"
    
    var lastCrashReport: String? {
        get { UserDefaults.standard.string(forKey: crashKey) }
        set { 
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: crashKey)
            } else {
                UserDefaults.standard.removeObject(forKey: crashKey)
            }
        }
    }
    
    func start() {
        // 1. Setup uncaught exception handler (ObjC exceptions)
        NSSetUncaughtExceptionHandler { exception in
            let stack = exception.callStackSymbols.joined(separator: "\n")
            let msg = "Uncaught Exception: \(exception.name.rawValue)\nReason: \(exception.reason ?? "Unknown")\n\nStack Trace:\n\(stack)"
            UserDefaults.standard.set(msg, forKey: "LastCrashReport")
            UserDefaults.standard.synchronize()
        }
        
        // 2. Setup Unix signal handlers (Swift fatal errors, memory access, etc.)
        let handler: @convention(c) (Int32) -> Void = { signalCode in
            var sigName = ""
            switch signalCode {
            case SIGABRT: sigName = "SIGABRT (Abort - often fatalError or force unwrap)"
            case SIGILL:  sigName = "SIGILL (Illegal Instruction)"
            case SIGSEGV: sigName = "SIGSEGV (Segmentation Fault - bad memory access)"
            case SIGFPE:  sigName = "SIGFPE (Floating Point Exception)"
            case SIGBUS:  sigName = "SIGBUS (Bus Error)"
            case SIGPIPE: sigName = "SIGPIPE (Broken Pipe)"
            case SIGTRAP: sigName = "SIGTRAP (Trace/BPT Trap - Swift runtime error)"
            default:      sigName = "SIGNAL \(signalCode)"
            }
            
            let callStack = Thread.callStackSymbols.joined(separator: "\n")
            let msg = "Native Crash: \(sigName)\n\nStack Trace:\n\(callStack)"
            UserDefaults.standard.set(msg, forKey: "LastCrashReport")
            UserDefaults.standard.synchronize()
            
            // We must call exit so the OS actually kills the process
            exit(signalCode)
        }
        
        signal(SIGABRT, handler)
        signal(SIGILL, handler)
        signal(SIGSEGV, handler)
        signal(SIGFPE, handler)
        signal(SIGBUS, handler)
        signal(SIGPIPE, handler)
        signal(SIGTRAP, handler)
    }
}
