//
//  Notifications.swift
//  ShareBox
//
//  Created by Thom van den Broek on 08/08/2025.
//

import SwiftUI
import UserNotifications

class Utilities {
    /// Show local notification to the user if given permissions
    static func showNotification(title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        center.add(request) { (error) in
            if let error = error {
                NSLog("Error adding notification: \(error.localizedDescription)")
            }
        }
    }

    static func map(minRange: CGFloat, maxRange: CGFloat, minDomain: CGFloat, maxDomain: CGFloat, value: CGFloat) -> CGFloat {
        return minDomain + (maxDomain - minDomain) * (value - minRange) / (maxRange - minRange)
    }
}
