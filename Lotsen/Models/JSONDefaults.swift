//
//  JSONDefaults.swift
//  Lotsen
//

import Foundation

/// Collections are stored as JSON strings, which is also the format settings
/// export and import exchange, so these must keep writing exactly that.
extension UserDefaults {
    /// nil when the key is missing or its value does not decode.
    func json<Value: Decodable>(_ type: Value.Type = Value.self, forKey key: String) -> Value? {
        guard let data = string(forKey: key)?.data(using: .utf8) else {
            return nil
        }

        return try? JSONDecoder().decode(type, from: data)
    }

    /// Like `json`, but a stored value that doesn't decode is first copied to
    /// `<key>.unreadable`. One entry from a newer version empties a whole list,
    /// and the next change would otherwise save the empty list over it.
    func jsonKeepingUnreadable<Value: Decodable>(_ type: Value.Type = Value.self, forKey key: String) -> Value? {
        if let value = json(type, forKey: key) {
            return value
        }
        // Compared first, since every write notifies and settings reload on that.
        if let raw = string(forKey: key), string(forKey: key + ".unreadable") != raw {
            set(raw, forKey: key + ".unreadable")
        }

        return nil
    }

    func setJSON<Value: Encodable>(_ value: Value, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value),
              let string = String(data: data, encoding: .utf8)
        else {
            return
        }

        set(string, forKey: key)
    }
}
