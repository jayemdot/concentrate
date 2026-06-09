import Foundation
import CryptoKit
import Security

/// 解除用パスコードを Keychain に保存する。平文ではなく salt + SHA256 ハッシュを保存する。
enum PasscodeStore {
    private static let service = "com.jayemdot.concentrate"
    private static let account = "unlock-passcode"
    private static let saltLength = 16
    private static let hashLength = 32 // SHA256

    /// パスコードが設定済みか。
    static var isSet: Bool { load() != nil }

    /// パスコードを設定(上書き)する。
    static func set(_ passcode: String) {
        let salt = randomSalt()
        let digest = hash(passcode, salt: salt)
        save(salt + digest)
    }

    /// 入力されたパスコードが正しいか検証する。
    static func verify(_ passcode: String) -> Bool {
        guard let data = load(), data.count == saltLength + hashLength else { return false }
        let salt = Data(data.prefix(saltLength))
        let stored = Data(data.suffix(hashLength))
        let computed = hash(passcode, salt: salt)
        return constantTimeEqual(computed, stored)
    }

    /// パスコードを削除する。
    static func clear() {
        SecItemDelete(baseQuery() as CFDictionary)
    }

    // MARK: - ハッシュ

    private static func randomSalt() -> Data {
        var salt = Data(count: saltLength)
        let result = salt.withUnsafeMutableBytes { buf in
            SecRandomCopyBytes(kSecRandomDefault, saltLength, buf.baseAddress!)
        }
        precondition(result == errSecSuccess, "乱数生成に失敗")
        return salt
    }

    private static func hash(_ passcode: String, salt: Data) -> Data {
        var input = salt
        input.append(Data(passcode.utf8))
        return Data(SHA256.hash(data: input))
    }

    /// タイミング攻撃を避けるための定数時間比較。
    private static func constantTimeEqual(_ a: Data, _ b: Data) -> Bool {
        guard a.count == b.count else { return false }
        var diff: UInt8 = 0
        for i in 0..<a.count { diff |= a[i] ^ b[i] }
        return diff == 0
    }

    // MARK: - Keychain

    private static func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    private static func save(_ data: Data) {
        clear()
        var query = baseQuery()
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func load() -> Data? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        guard status == errSecSuccess, let data = out as? Data else { return nil }
        return data
    }
}
