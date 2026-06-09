import ServiceManagement
import os

/// ログイン項目(ログイン時の自動起動)を SMAppService で管理する。
enum LoginItem {
    private static let log = Logger(subsystem: "com.jayemdot.concentrate", category: "LoginItem")

    /// 現在有効か。
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// 承認待ち(システム設定でユーザ承認が必要)か。
    static var requiresApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    /// 自動起動を有効/無効にする。失敗時はログのみ。
    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            log.info("ログイン項目を更新: \(enabled, privacy: .public)")
        } catch {
            log.error("ログイン項目の更新失敗: \(error.localizedDescription, privacy: .public)")
        }
    }
}
