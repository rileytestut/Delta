# Voucher

The new Apple TV is amazing but the keyboard input leaves a lot to be desired. Instead of making your users type credentials into their TV, you can use Voucher to let them easily sign into the TV app using your iOS app.

### How Does It Work?

Voucher uses [Bonjour](https://developer.apple.com/bonjour/), which is a technology to discover other devices on your network, and what they can do. When active, Voucher on tvOS starts looking in your local network for any Voucher Server, on iOS. 

Once it finds a Voucher Server, it asks it for authentication:
<p align="center"><img src="http://cl.ly/image/0H1p2p3i281H/Screen%20Shot%202015-11-11%20at%2011.14.46%20AM.png" width="600" alt="Sample tvOS App"/></p>

The iOS app can then show a notification to the user:
<p align="center"><img src="http://cl.ly/image/3d0L3P310C3w/IMG_0636.PNG" width="320" alt="iOS app shows a dialog"/></p>

If the user accepts, then the iOS app can send some authentication data back to the tvOS app (in this case, an auth token string)
<p align="center"><img src="http://cl.ly/image/1f2g3G3q3625/Screen%20Shot%202015-11-11%20at%2011.15.07%20AM.png" width="600" alt="Sample tvOS App"/></p>


## Installation

Voucher is available through [Carthage](https://github.com/Carthage/Carthage), and [Cocoapods](https://cocoapods.org). You can also manually install it, if that's your jam.

### Carthage
```
github "rsattar/Voucher"
```

### Cocoapods
```
pod 'Voucher'
```

### Manual 
- Clone the repo to your computer
- Copy only the source files in `Voucher` subfolder over to your project


## Using Voucher

In your tvOS app, when the user wants to authenticate, you should create a `VoucherClient` instance and start it:

### tvOS (Requesting Auth)
When the user triggers a "Login" button, your app should display some UI instructing them to open their iOS App to finish logging in, and then start the voucher client, like below:

```swift
import Voucher

func startVoucherClient() {
    let uniqueId = "SomethingUnique";
    self.voucher = VoucherClient(uniqueSharedId: uniqueId)
    
    self.voucher.startSearchingWithCompletion { [unowned self] tokenData, displayName, error in

        if tokenData != nil {
            // User granted permission on iOS app!
            self.authenticationSucceeded(tokenData!, from: displayName)
        } else {
            self.authenticationFailed()
        }
    }
}

```


### iOS (Providing Auth)
If your iOS app has auth credentials, it should start a Voucher Server, so it can answer any requests for a login. I'd recommend starting the server when (and if) the user is logged in.

```swift
import Voucher

func startVoucherServer() {
    let uniqueId = "SomethingUnique"
    self.server = VoucherServer(uniqueSharedId: uniqueId)

    self.server.startAdvertisingWithRequestHandler { (displayName, responseHandler) -> Void in

        let alertController = UIAlertController(title: "Allow Auth?", message: "Allow \"\(displayName)\" access to your login?", preferredStyle: .Alert)
        alertController.addAction(UIAlertAction(title: "Not Now", style: .Cancel, handler: { action in
            responseHandler(nil, nil)
        }))

        alertController.addAction(UIAlertAction(title: "Allow", style: .Default, handler: { action in
            let tokenData = "THIS IS AN AUTH TOKEN".dataUsingEncoding(NSUTF8StringEncoding)!
            responseHandler(tokenData, nil)
        }))

        self.presentViewController(alertController, animated: true, completion: nil)
        
    }
}

```

## Recommendations

### Tokens
Voucher works best if you pass an **OAuth** token, or better yet, generate some kind of a *single-use token* on your server, and pass that to tvOS. [Cluster](https://cluster.co), for example, uses single-use tokens to do auto-login from web to iOS app. Check out this [Medium post](https://library.launchkit.io/how-ios-9-s-safari-view-controller-could-completely-change-your-app-s-onboarding-experience-2bcf2305137f?source=your-stories) that shows how I do it! The same model can apply for iOS to tvOS logins.

### Voucher shouldn't be the only login option
In your login screen, you should still show the manual entry UI, but add messaging that if the user simply opens the iOS app they can login that way too.

## To do / Things I'd Love Your Help With!
* Encryption? Currently Voucher *does not* encrypt any data between the server and the client, so I suppose if someone wanted your credentials (See **Recommendations** section above), they could have a packet sniffer on your local network and access your credentials.

* Maybe change the response to be not called `tokenData`, as it's an `NSData` object, so anything can be passed back.

* Make Voucher Server work on `OS X`, and even `tvOS`! Would probably just need new framework targets, and additional test apps.

## Requirements
* iOS 7.0 and above
* tvOS 9.0
* Xcode 7


## License
`Voucher` is available using an MIT license. See the LICENSE file for more info.