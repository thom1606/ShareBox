//
//  Notifications.swift
//  ShareBox.Helper
//
//  Created by Thom van den Broek on 11/08/2025.
//

import Foundation
import UserNotifications

final class Notifications {
    public static func getStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            completion(settings.authorizationStatus)
        }
    }

    public static func requestAccess() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
    }

    public static func show(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body

        UNUserNotificationCenter.current().delegate = nil
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "ShareBox", content: content, trigger: nil))
    }
}
