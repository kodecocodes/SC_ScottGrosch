## Introduction

Hey everybody, I'm Scott, and I'd like to welcome you to my first ever raywenderlich.com screencast!  Huge thanks to Ray for giving me this opportunity and Tim Mitra for tech editing the project. 

In today's screencast we'll be talking about push notifications.  There are tons of tutorials out there already but most of them don't handle the server side push at all and they leave out many of the possible ways to get notified in your app.

To get going, please download the startup project and open it up in Xcode.  We're not going to build the next cool app here, but rather just focus on push notifications.

OK, here we go!

## App Setup

### AppDelegate Extension

Most of the APNS setup code is the same from app to app, so let's put our code in an extension that we can reuse across projects.  Our first goal is to tell the remote server how to contact us, so create a new Swift file called AppDelegate+Extensions.swift and then make a function which takes a URL and a device token, and sends a POST to our remote server.

```
func sendPushNotificationDetails(to url: URL, using deviceToken: Data? = nil) {
  let token = deviceToken.reduce("") { $0 + String(format: "%02x", $1) }
  
  var request = URLRequest(url: url)
  request.addValue("application/json", forHTTPHeaderField: "Content-Type")
  request.httpMethod = "POST"
  request.httpBody = try! JSONSerialization.data(withJSONObject: [
    "token" : token,
    ])
    
  URLSession.shared.dataTask(with: request).resume()
}

```

### Interlude

The first time your application starts, iOS will ask the user if they want to enable push notifications.  You need to always remember they might have said no, or they might have said yes but later disabled it.  We therefore need a way to check when the app starts up if we can register for notifications or not.  We actually have to make two separate checks.  First we request authorization to interact with the user, and then we have to check their notification settings.  Only after both of those succeed can we actually register!

### Registering

Back in our extension let's add another method to that checking and registration.  This code is exactly the same across apps so it makes sense to put it here.   

We'll get the UNUserNotificationCenter and ask for authorization requesting badges, sounds and alerts.  Note in the callback we need to be careful not to cause retain cycles on either the center or self.   If access is granted, we can then get the notification settings, check *its* authorization status, and finally do the actual registration.  The notification center callback doesn't run on the main thread, so be sure to dispatch back to the right queue before the actual registration call.

```
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
```

### Interlude

At this point you'll notice that Xcode isn't happy because you specified that AppDelegate is the notification center's delegate, but you haven't actually implemented it.  Those delegate methods are what actually processes the notifications you received, meaning they're application specific.  So let's go back to the AppDelegate file now and implement the stubs to make the compiler happy.

### Notification Delegate

We first need to implement the delegate method that gets called when your app is running in the background and the user taps on the notification.  You *must* call the completionHandler given to you, so let's use a defer block to ensure it runs no matter how we exit the method.

```
extension AppDelegate: UNUserNotificationCenterDelegate {
  func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
    // Called when the app is in the background and the user taps the notification
    defer { completionHandler() }
    }
  }
```

Then we need to implement the method that gets called when your app is running in the foreground.  For this screencast, we'll just tell the notification to go ahead and appear.  In your real world application this would be where you could implement more customer logic, use deep linking to jump to a specific view controller, etc... Those are all outside the scope of this screencast though as we are just focused on push notifications.

```
  func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    // Called when a notification is delivered to a foreground app.

    // If you want the alert to show up even if the app is running, then just pass the options into the completion handler.
    // If you don't, then pass in an empty set.
    completionHandler([.alert, .sound, .badge])
  }
}
```

### Interlude

OK, so at this point the compiler is happy and we've implemented our methods, so we're good to go, right?  Nope!  Astute observers will notice that we never *called* our registration.   

There are three methods we have to implement in the UIApplicationDelegate to have basic notification support.  We've got to support registration failure, registration setup, and registration success.  Let's go do that now.

### UIApplicationDelegate

Personally I like to pull the app delegate methods out of the AppDelegate class just to be consistent with our style of using extension.  We want to call the registration method we wrote earlier every time the application starts.  Remember that inbetween runs they might change their preferences, and that's why you do this every time.  All we have to do is call our method from the didFinishLaunchingWithOptions delegate method.

```
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {
  registerForPushNotifications(application: application)
    
  return true
}
```

Once we do that, we'll either succeed or fail.  Notification registration might fail for a number of reasons according to Apple.  Personally I've never seen it happen, but defensive programming and all...

```
func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
  print("Failed to register for notifications: \(error)")
}
```

When we succeed we'll want to update our server, so let's implement that now.

```
func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
  let url = URL(string: "https://gargoyle.local/apps/myCoolApp/apns.php")!
  sendPushNotificationDetails(to: url, using: deviceToken)
}
```

### Interlude

At this point you're done with the basics of notifications!  You can receive both foreground and background notifications and take action when they arrive.  But don't take my word for it!  Let's send something!  We'll switch to the server side setup at this point.  If you've done anything with APNS in the past you're probably cringing, knowing it's time to setup the PEM keys.  I'd never do that to you though!  Instead, lets use Apple's new auth keys which never expire, don't differentiate because production and development, and don't even need to differentiate between apps!

## Developer Center

Open up your favorite browser and head over to the developer portal.  I usually use Chrome for everything, but I find Safari is more reliable when working with the dev center and iTunesConnect.  

Once you're there, go to the certificates tab and click on Keys -> All.  Add a new key, choose notifications, and then save the p8 file that's generated.  Nice, right?  You'll never come back to this page again.

At the top right of the page click on Account, and then Membership.  You'll want to copy down your team id as we'll need that in a minute.

### Docker

If you don't already have a server you're using then docker is a great solution to spin up a server for development.  If it's not already installed on your mac, just head over to docker.com, use the Get Docker link at the top of the page and then download the mac version.

Now open up Terminal and go to the starter materials you downloaded and you'll see a createServer script that will spin up a docker instance for you.  The script will link port 80 of your mac to port 80 on the docker container for your webserver, and port 5432 for PostgreSQL.  

Now run the provided script and specify a directory where your server instance should live.   Change directories to that path and you'll notice a src directory there.  This is the root of your website.

## Setup SQL and Web

Now that docker is running, run the createPsqlTables.sql file through psql to setup the user, database, and tables.  

```
psql -U postgres -h localhost -f ./createPsqlTables.sql
```

Now copy the three PHP files into the src directory and then take a look at the apns.php file.

```
cp *.php src
cat src/apns.php
```
 
You'll see that when the iOS app sends over the device token, it's stored in the apns table in the database.  If you're going to send a push notification to somebody, you need to know their device token, and this is how we store them.

Copy the APNS key you downloaded from apple to the src directory as well and then edit the sendPush.php file.  Set the const variables at the top of the script to the appropriate values.  Remember to use a full path to the auth key, and for the key id use the value in the p8 file.

If you're interested in the nitty gritties of how auth keys work, you can look at https://jwt.io, but realistically there's no need for that.    The only pieces of the script that you'll need to modify are the payload and the tokensToReceiveNotification function.

Build and run in Xcode and then you can look in the database to see that your token is there.

```
psql -U apns -h localhost apns
select * from apns;
```

Phew.  We're finally ready to send a push!  Execute the sendPush.php script and watch with amazement as your iOS device displays a notification!


# THIS IS PROBABLY A SCREENCAST BREAKING POINT

## Interlude

Hey everybody, it's Scott again.  Welcome to the second half of our screencast on push notifications.  In the last screencast we setup Xcode, a web server, PostgreSQL and implemented the scripts to handle push notifications server side.

In this screencast we'll extend that to include custom actions and background downloading, also known as silent notifications, as well as add some helpers to make UserDefaults and foundation notifications easier.

Just displaying a message to the user is frequently more than enough, but sometimes you want them to be able to take action.  If your end user does a long press on the notification then you can display action buttons to them.  You could also completely change the notification that comes in and customize the display.  We'll only be covering custom actions as Sam Davies has already done a couple great screencasts on this topic.


CAROLINE, please show some type of image on the screen to "iOS 10: Custom Notification UI with Content Extensions" and "iOS 10: Interactive Custom Notifications"


##  Setup custom action

Let's jump right into our app delegate and create an enum to represent our actions so that we're not hardcoding strings.

```
enum NotificationActionIdentifier: String {
  case Snooze
  case Stop
}
```

Our action will just have two buttons.  Let's setup the registration nowIt's easy to fall into the trap of just putting that text but force yourself to always think of localization from the start.   The UNNotificationAction is used to identify the buttons that will be presented.  Then we use a UNNotificationCategory to register the category that our push notification will use to identify that we want the actions to appear on that push.

```
private let categoryIdentifier = "Timer"

private func registerCustomActions() {
  var title = NSLocalizedString("Snooze", comment: "The button to press if you need a bit more of a nap.")
  let snooze = UNNotificationAction(identifier: NotificationActionIdentifier.Snooze.rawValue, title: title)

  title = NSLocalizedString("Stop", comment: "The button to press if you want to stop the alarm.")
  let stop = UNNotificationAction(identifier: NotificationActionIdentifier.Stop.rawValue, title: title, options: .foreground)

  let category = UNNotificationCategory(identifier: categoryIdentifier, actions: [snooze, stop], intentIdentifiers: [])
  UNUserNotificationCenter.current().setNotificationCategories([category])
}
```

Head down to didRegisterForRemoteNotificationsWithDeviceToken and call that registration method.  No need to register if we can't send push notifications.

Finally, we need to update our receive method to know whether a button was pressed, they dismissed the notification, or simply tapped on it.

```
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
```

### Interlude

When you receive a notification you frequently can't do everything you need to inside of the delegate.  One of the simplest things to do is send a notification (a foundation notification, not a push notification) when it happens.  NSNotification center is awkward to use and we can greatly simplify it with a simple extension to Notification.Name.  Let's go do that now and take care of the compiler error we just introduced.


### Add notification extension

```
extension Notification.Name {
  static let NotificationAction = Notification.Name("Action Notification")

  func post(center: NotificationCenter = NotificationCenter.default, object: Any? = nil, userInfo: [AnyHashable : Any]? = nil) {
    center.post(name: self, object: object, userInfo: userInfo)
  }

  @discardableResult
  func onPost(center: NotificationCenter = NotificationCenter.default, object: Any? = nil, queue: OperationQueue? = nil, using: @escaping (Notification) -> Void) -> NSObjectProtocol {
    return center.addObserver(forName: self, object: object, queue: queue, using: using)
  }
}
``` 

### Update the view controller

In the view controller we can now catch the fact that a notification was sent and perform some type of action.

```
Notification.Name.NotificationAction.onPost { note in
  guard let selectedAction = note.userInfo?["action"] as? NotificationActionIdentifier else { return }

  print("Got a push and they chose action \(selectedAction.rawValue)")
}
```

### Update server

Finally, we have to update the server's push script to identify that we want to use the categories we just registered.  Just edit the payload and add the category to the apns block.

```
'aps' => [
   'category' => 'Timer'
]
```

Any notification you send where the payload contains that category will trigger our custom actions to be available.


## Silent Notifications

### Interlude

There's one more type of notification you can receive.  Known as both background notifications and silent notifications, these are useful if your app needs to download data and you want it to be ready *before* the user runs your app.  There's no visible notification presented to the user.  It simply wakes up your application in the background, does some work, and exits.  You get around 30 seconds to complete your action after awakening.

You should not push your data to your app unless it's very small.  The notification should just tell your app that new data is available and then your application can make a network connection, if relevant, to download the data.

If your data to be downloaded is very small, you could go ahead and send it.  For example, in the DidIWin app I go ahead and just push the current powerball or megamilllions numbers to the user's device instead of making a new network connection as the full data packet is simply a Date and seven integers.  

### Updating the iOS app

First we need to tell the app we're going to support background exection, so let's go back to our projects capabilities, turn on Background modes, and then select "Remote notifications"

As we're receiving a new notification type, let's first update our extension to add a name.

```
static let SilentPush = Notification.Name("Silent Push")

```

Now, back in the app delegate, there's just a single new method to implement.

```
func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
  // Called if the app is in the background and the content-available option is set to true in the payload.
  // This is where you can download new content automatically.  For this method to be utilized you must
  // also enable the "Remote notifications" background modes in your project's capibilities
  Notification.Name.SilentPush.post(userInfo: userInfo)
  completionHandler(.noData)
}
```

In this case I'm saying that no data was downloaded as I don't make any type of network call.  If you do make a network connection, you'd need to pass either .failed or .newData depending on what happened.

### Updating the server

In our push notification script all we have to do is add the content-available key to our apns payload with a value of 1.  Note that it doesn't make sense to include both a category and this key.  There's also no need to include an alert since it's a silent notification.

```
$payload = [
  'aps' => [
    'content-available' => 1
  ]
];
```   

## Miscellaneous

### Interlude

At this point the application is complete, but there are a couple extra things we can add to make things better.  Depending on how you use notifications, you may register more than once.  For example, in a ticketing application you would only want to receive notifications during timeframes for which your ticket is valid.  

We can also take this opportunity to store a bit more user information in our database to help with future items such as OS upgrades and localization.

### Update appdelegate+extensions

We'll want to update our sendPushNotificationDetails so that we can either pass in a device token or use one that was already stored.  This is a great use case for UserDefaults, so let's add a quick extension.  This is a good pattern to follow for UserDefaults to ensure that we don't repeat strings in multiple places that might get out of sync.

```
extension UserDefaults {
  private struct Keys {
    static let apnsToken = "apns"
  }
  
  /// The token provided during a successful APNS registration, or nil on failure.
  var apnsToken: String? {
    get {
      return UserDefaults.standard.string(forKey: Keys.apnsToken)
    }
    set {
      UserDefaults.standard.set(newValue, forKey: Keys.apnsToken)
    }
  }
}
```

Then back in our app delegate we can update our method to make use of that value and whatever details the caller has sent in.

```
func sendPushNotificationDetails(to url: URL, using deviceToken: Data? = nil, httpBody: [String : Any]? = nil) {
  let token: String
  if let deviceToken = deviceToken {
    token = deviceToken.reduce("") { $0 + String(format: "%02x", $1) }
  } else if let apnsToken = UserDefaults.standard.apnsToken {
    token = apnsToken
  } else {
    fatalError("Must provide a deviceToken at startup!")
  }
    
  UserDefaults.standard.apnsToken = token
  
  var body: [String : Any] = [:]

  if let httpBody = httpBody {
    body = httpBody
  }

  body["token"] = token 
  
  var request = URLRequest(url: url)
  request.addValue("application/json", forHTTPHeaderField: "Content-Type")
  request.httpMethod = "POST"
  request.httpBody = try! JSONSerialization.data(withJSONObject: body)
    
  URLSession.shared.dataTask(with: request).resume()
}
```

### Saving launch info

Our last modification is to store a bit of information about the user so that we can better support our app long-term.  There are no personally identifiable details here but by storing these pieces we know when we can drop support for older operating systems, and see what languages our users prefer so we pay for the right localizations, and don't simply guess that "Spanish is probably a good idea".

```
func saveLaunchInfo(appName name: String? = nil) {
  guard let url = URL(string: "https://www.contoso.com/apps/info.php"),
    let uuid = UIDevice.current.identifierForVendor?.uuidString else { return }

  let version = UIDevice.current.systemVersion
  let languages = Locale.preferredLanguages.joined(separator: ", ")

  let appName = name ?? Bundle.main.infoDictionary![kCFBundleNameKey as String] as! String

  var request = URLRequest(url: url)
  request.addValue("application/json", forHTTPHeaderField: "Content-Type")
  request.httpMethod = "POST"
  request.httpBody = try! JSONSerialization.data(withJSONObject: [
    "ident" : uuid,
    "ios" : version,
    "app" : appName,
    "languages" : languages
    ])

  URLSession.shared.dataTask(with: request).resume()
}
```


## Closing

Allright, that's everything I'd like to cover in this screencast. 

At this point, you should have a good handle on how to send and receive push notifications, perform background updates, and know when to drop older OS support.
 
Thanks for watching!
