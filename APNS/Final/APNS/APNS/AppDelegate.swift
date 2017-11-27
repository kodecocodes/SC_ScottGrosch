/// Copyright (c) 2017 Razeware LLC
/// 
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
/// 
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
/// 
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
/// 
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import UIKit
import UserNotifications

enum NotificationActionIdentifier: String {
  case Snooze
  case Stop
}

@UIApplicationMain
class AppDelegate: UIResponder {
  var window: UIWindow?

  private let categoryIdentifier = "Timer"

  private func registerCustomActions() {
    var title = NSLocalizedString("Snooze", comment: "The button to press if you need a bit more of a nap.")
    let snooze = UNNotificationAction(identifier: NotificationActionIdentifier.Snooze.rawValue, title: title)

    title = NSLocalizedString("Stop", comment: "The button to press if you want to stop the alarm.")
    let stop = UNNotificationAction(identifier: NotificationActionIdentifier.Stop.rawValue, title: title, options: .foreground)

    let category = UNNotificationCategory(identifier: categoryIdentifier, actions: [snooze, stop], intentIdentifiers: [])
    UNUserNotificationCenter.current().setNotificationCategories([category])
  }
}

// MARK: - UIApplicationDelegate
extension AppDelegate: UIApplicationDelegate {
  func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("Failed to register for notifications: \(error)")
  }
  
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {
    registerForPushNotifications(application: application)
    return true
  }

  func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    // Called if the app is in the background and the content-available option is set to true in the payload.
    // This is where you can download new content automatically.  For this method to be utilized you must
    // also enable the "Remote notifications" background modes in your project's capibilities
    Notification.Name.SilentPush.post(userInfo: userInfo)
    completionHandler(.noData)
  }

  func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    registerCustomActions()

    let url = URL(string: "https://www.contoso.com/apps/myCoolApp/apns.php")!
    sendPushNotificationDetails(to: url, using: deviceToken)

    #if DEBUG
      print("Registered for APNS with token \(UserDefaults.standard.apnsToken!)")
    #endif
  }
}

// MARK: - UNUserNotificationCenterDelegate
extension AppDelegate: UNUserNotificationCenterDelegate {
  func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
    // Called when the app is in the background and the user taps the notification
    defer { completionHandler() }

    if response.actionIdentifier == UNNotificationDismissActionIdentifier {
      // The user dismissed the notification without taking action
      return
    } else if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
      // The user launched the app by tapping on your notification
      return
    }

    guard response.notification.request.content.categoryIdentifier == categoryIdentifier,
      let action = NotificationActionIdentifier(rawValue: response.actionIdentifier) else { return }

    // If we get here that means they did a long-press and then chose one of our notifications.
    Notification.Name.NotificationAction.post(userInfo: ["action" : action])
  }

  func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    // Called when a notification is delivered to a foreground app.
    // let userInfo = notification.request.content.userInfo

    // If you want the alert to show up even if the app is running, then just pass the options into the completion handler.
    // If you don't, then pass in an empty set.
    completionHandler([.alert, .sound, .badge])
  }
}
