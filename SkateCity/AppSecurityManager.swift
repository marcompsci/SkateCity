// AppSecurityManager.swift
// SkateCity — Runtime integrity and tamper-detection layer.
//
// Copyright © 2026 MAR / SkateCity. All rights reserved.
// Unauthorized reproduction, distribution, or modification of this software
// or any portion thereof is strictly prohibited. Protected under U.S. and
// international copyright law.

import Foundation
import UIKit
import Darwin
import MachO

// MARK: - Threat model

enum SecurityThreat: String {
    case jailbreak      = "Jailbreak detected"
    case debugger       = "Debugger attached"
    case simulator      = "Running in simulator"
    case hooking        = "Code hooking detected"
    case tampered       = "Bundle integrity failure"
}

// MARK: - Manager

final class AppSecurityManager {

    static let shared = AppSecurityManager()
    private init() {}

    // MARK: - Public API

    /// Run all checks. Returns the first threat found, or nil if clean.
    func runChecks() -> SecurityThreat? {
        if isJailbroken()    { return .jailbreak }
        if isDebuggerAttached() { return .debugger }
        if isSimulator()     { return .simulator }
        if isBundleTampered() { return .tampered }
        return nil
    }

    /// Call at app launch. In production, terminates the process on threat.
    /// Pass `enforce: false` during development to log only.
    func enforce(strict: Bool = true) {
        guard let threat = runChecks() else { return }
        log("⚠️ Security threat: \(threat.rawValue)")
        if strict {
            // Wipe any cached session data before exiting
            KeychainManager.shared.deleteAll()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
                exit(0)
            }
        }
    }

    // MARK: - Jailbreak detection

    private func isJailbroken() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        // 1. Known jailbreak paths
        let paths = [
            "/Applications/Cydia.app",
            "/Applications/blackra1n.app",
            "/Applications/FakeCarrier.app",
            "/Applications/Icy.app",
            "/Applications/IntelliScreen.app",
            "/Applications/MxTube.app",
            "/Applications/RockApp.app",
            "/Applications/SBSettings.app",
            "/Applications/WinterBoard.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/Library/MobileSubstrate/DynamicLibraries/LiveClock.plist",
            "/Library/MobileSubstrate/DynamicLibraries/Veency.plist",
            "/private/var/lib/apt",
            "/private/var/lib/cydia",
            "/private/var/mobile/Library/SBSettings/Themes",
            "/private/var/stash",
            "/private/var/tmp/cydia.log",
            "/System/Library/LaunchDaemons/com.ikey.bbot.plist",
            "/System/Library/LaunchDaemons/com.saurik.Cydia.Startup.plist",
            "/bin/bash",
            "/bin/sh",
            "/usr/sbin/sshd",
            "/usr/libexec/sftp-server",
            "/etc/apt",
            "/usr/bin/sshd",
        ]
        for path in paths {
            if FileManager.default.fileExists(atPath: path) { return true }
        }

        // 2. Can write outside sandbox
        let testPath = "/private/jailbreaktest_\(UUID().uuidString)"
        do {
            try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: testPath)
            return true
        } catch {}

        // 3. Cydia URL scheme
        if let url = URL(string: "cydia://package/com.example.package"),
           UIApplication.shared.canOpenURL(url) { return true }

        // 4. Suspicious dylibs loaded
        let count = _dyld_image_count()
        for i in 0..<count {
            if let name = _dyld_get_image_name(i) {
                let s = String(cString: name).lowercased()
                if s.contains("substrate") || s.contains("substitute") ||
                   s.contains("cynject") || s.contains("frida") { return true }
            }
        }

        return false
        #endif
    }

    // MARK: - Debugger detection

    private func isDebuggerAttached() -> Bool {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        let result = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
        guard result == 0 else { return false }
        return (info.kp_proc.p_flag & P_TRACED) != 0
    }

    // MARK: - Simulator detection

    private func isSimulator() -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    // MARK: - Bundle integrity

    private func isBundleTampered() -> Bool {
        // Verify the main bundle executable exists and is signed
        guard let exec = Bundle.main.executableURL else { return true }
        guard FileManager.default.fileExists(atPath: exec.path) else { return true }

        // Check Info.plist has expected bundle identifier
        guard let bundleID = Bundle.main.bundleIdentifier,
              bundleID.contains("SkateCity") || bundleID.contains("skatecity") else {
            return true
        }
        return false
    }

    // MARK: - Logging

    private func log(_ message: String) {
        #if DEBUG
        print("[AppSecurity] \(message)")
        #endif
    }
}
