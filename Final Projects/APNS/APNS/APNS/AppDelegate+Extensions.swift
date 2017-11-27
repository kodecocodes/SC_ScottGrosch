///// Copyright (c) 2017 Razeware LLC
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

extension AppDelegate {
  /// Attempts to register the user to accept push notifications.  If this is the
  /// first time the user has run the app, Apple will display a dialog asking for
  /// permission.  On successive runs the dialog will not be presented.
  ///
  /// - Parameter application: The UIApplication from `application(_:didFinishLaunchingWithOptions:)`
  func registerForPushNotifications(application: UIApplication) {
    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.badge, .sound, .alert]) {
      [unowned center, unowned self] granted, _ in
      guard granted else { return }

      center.delegate = self
      center.getNotificationSettings { settings in
        guard settings.authorizationStatus == .authorized else { return }
        
        DispatchQueue.main.async {
          application.registerForRemoteNotifications()
        }
      }
    }
  }

  /// Updates the remote webservice with the APNS token.
  ///
  /// - Note: This will also store the token in `UserDefaults.standard.apnsToken`
  /// - Parameters:
  ///   - url: The URL to send the details to.
  ///   - deviceToken: The device token provided from `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`
  func sendPushNotificationDetails(to url: URL, using deviceToken: Data) {
    let token = deviceToken.reduce("") { $0 + String(format: "%02x", $1) }
    
    UserDefaults.standard.apnsToken = token
    
    var request = URLRequest(url: url)
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpMethod = "POST"
    request.httpBody = try! JSONSerialization.data(withJSONObject: [
      "token" : token,
      ])
    
    URLSession.shared.dataTask(with: request).resume()
  }
}
