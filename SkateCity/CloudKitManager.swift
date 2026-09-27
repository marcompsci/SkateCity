// CloudKitManager.swift
// SkateCity — iCloud-backed leaderboard and player account management.
// Uses Apple's CloudKit public database so no server infrastructure is needed.
// All writes are authenticated via the player's iCloud account (no passwords stored).
//
// Copyright © 2026 MAR / SkateCity. All rights reserved.

import Foundation
import CloudKit
import Combine

// MARK: - Score record

struct LeaderboardEntry: Identifiable {
    let id:         CKRecord.ID
    let playerTag:  String
    let score:      Int
    let trickCount: Int
    let date:       Date
}

// MARK: - CloudKit Manager

@MainActor
final class CloudKitManager: ObservableObject {

    static let shared = CloudKitManager()

    private let container   = CKContainer(identifier: "iCloud.com.skatecity.app")
    private let publicDB:     CKDatabase
    private let privateDB:    CKDatabase

    private let recordType  = "HighScore"
    private let maxEntries  = 100

    @Published private(set) var leaderboard: [LeaderboardEntry] = []
    @Published private(set) var isSyncing = false
    @Published private(set) var accountStatus: CKAccountStatus = .couldNotDetermine

    private init() {
        publicDB  = container.publicCloudDatabase
        privateDB = container.privateCloudDatabase
    }

    // MARK: - Account status

    func checkAccountStatus() async {
        do {
            accountStatus = try await container.accountStatus()
        } catch {
            accountStatus = .couldNotDetermine
            log("Account status error: \(error.localizedDescription)")
        }
    }

    // MARK: - Submit score

    /// Submit a new high score. Rate-limited: one write per player per 60 seconds.
    func submitScore(tag: String, score: Int, trickCount: Int) async {
        guard accountStatus == .available else {
            log("CloudKit account not available — score not submitted")
            return
        }
        guard score > 0 else { return }

        // Rate limiting: check last submit time in Keychain
        let rateLimitKey = "ck.lastSubmit"
        if let lastData = KeychainManager.shared.data(forKey: rateLimitKey),
           let lastTime = try? JSONDecoder().decode(Date.self, from: lastData) {
            if Date().timeIntervalSince(lastTime) < 60 {
                log("Rate limit: score submission throttled")
                return
            }
        }

        let record         = CKRecord(recordType: recordType)
        record["playerTag"]  = sanitize(tag) as CKRecordValue
        record["score"]      = score as CKRecordValue
        record["trickCount"] = trickCount as CKRecordValue
        record["playerID"]   = KeychainManager.shared.playerID as CKRecordValue
        record["date"]       = Date() as CKRecordValue

        do {
            isSyncing = true
            _ = try await publicDB.save(record)
            if let encoded = try? JSONEncoder().encode(Date()) {
                KeychainManager.shared.set(encoded, forKey: rateLimitKey)
            }
            log("Score submitted: \(score)")
        } catch {
            log("Submit error: \(error.localizedDescription)")
        }
        isSyncing = false
    }

    // MARK: - Fetch leaderboard

    func fetchLeaderboard() async {
        isSyncing = true
        let pred   = NSPredicate(format: "score > 0")
        let sort   = NSSortDescriptor(key: "score", ascending: false)
        let query  = CKQuery(recordType: recordType, predicate: pred)
        query.sortDescriptors = [sort]

        do {
            let (results, _) = try await publicDB.records(matching: query,
                                                           resultsLimit: maxEntries)
            leaderboard = results.compactMap { (id, result) -> LeaderboardEntry? in
                guard let record = try? result.get() else { return nil }
                return LeaderboardEntry(
                    id:         id,
                    playerTag:  record["playerTag"] as? String ?? "Anon",
                    score:      record["score"] as? Int ?? 0,
                    trickCount: record["trickCount"] as? Int ?? 0,
                    date:       record["date"] as? Date ?? Date()
                )
            }
            log("Leaderboard fetched: \(leaderboard.count) entries")
        } catch {
            log("Fetch error: \(error.localizedDescription)")
        }
        isSyncing = false
    }

    // MARK: - Save wardrobe to private iCloud

    func saveWardrobeProfile(_ profile: SkaterWardrobeProfile) async {
        guard accountStatus == .available else { return }
        guard let data = try? JSONEncoder().encode(profile) else { return }

        let record       = CKRecord(recordType: "WardrobeProfile",
                                    recordID: CKRecord.ID(recordName: "wardrobe_\(KeychainManager.shared.playerID)"))
        record["data"]   = data as CKRecordValue

        do {
            _ = try await privateDB.save(record)
            log("Wardrobe profile synced to iCloud")
        } catch {
            log("Wardrobe sync error: \(error.localizedDescription)")
        }
    }

    func fetchWardrobeProfile() async -> SkaterWardrobeProfile? {
        guard accountStatus == .available else { return nil }
        let recordID = CKRecord.ID(recordName: "wardrobe_\(KeychainManager.shared.playerID)")
        do {
            let record = try await privateDB.record(for: recordID)
            if let data = record["data"] as? Data {
                return try? JSONDecoder().decode(SkaterWardrobeProfile.self, from: data)
            }
        } catch { log("Wardrobe fetch error: \(error.localizedDescription)") }
        return nil
    }

    // MARK: - Input sanitization

    private func sanitize(_ input: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(.init(charactersIn: "_-."))
        return String(input.unicodeScalars.filter { allowed.contains($0) }).prefix(24).description
    }

    // MARK: - Logging

    private func log(_ msg: String) {
        #if DEBUG
        print("[CloudKit] \(msg)")
        #endif
    }
}
