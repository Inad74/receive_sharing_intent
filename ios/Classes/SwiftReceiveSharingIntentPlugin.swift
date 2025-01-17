import Flutter
import UIKit
import Photos

public class SwiftReceiveSharingIntentPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    
    static let kMessagesChannel = "receive_sharing_intent/messages";
    static let kEventsChannelImage = "receive_sharing_intent/events-image";
    static let kEventsChannelLink = "receive_sharing_intent/events-text";
    
    private var initialImage: [String]? = nil
    private var latestImage: [String]? = nil
    
    private var initialText: String? = nil
    private var latestText: String? = nil
    
    private var eventSinkImage: FlutterEventSink? = nil;
    private var eventSinkText: FlutterEventSink? = nil;
    
    public typealias UIApplicationLaunchOptionsKey = UIApplication.LaunchOptionsKey
    public typealias UIApplicationOpenURLOptionsKey = UIApplication.OpenURLOptionsKey
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = SwiftReceiveSharingIntentPlugin()
        
        let channel = FlutterMethodChannel(name: kMessagesChannel, binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        let chargingChannelImage = FlutterEventChannel(name: kEventsChannelImage, binaryMessenger: registrar.messenger())
        chargingChannelImage.setStreamHandler(instance)
        
        let chargingChannelLink = FlutterEventChannel(name: kEventsChannelLink, binaryMessenger: registrar.messenger())
        chargingChannelLink.setStreamHandler(instance)
        
        registrar.addApplicationDelegate(instance)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        
        switch call.method {
        case "getInitialImage":
            result(self.initialImage);
        case "getInitialText":
            result(self.initialText);
        case "reset":
            self.initialImage = nil
            self.latestImage = nil
            self.initialText = nil
            self.latestText = nil
            result(nil);
        default:
            result(FlutterMethodNotImplemented);
        }
    }
    
    public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [AnyHashable : Any] = [:]) -> Bool {
        if let url = launchOptions[UIApplicationLaunchOptionsKey.url] as? URL {
            return handleUrl(url: url, setInitialData: true)
        } else if let activityDictionary = launchOptions[UIApplicationLaunchOptionsKey.userActivityDictionary] as? [AnyHashable: Any] { //Universal link
            for key in activityDictionary.keys {
                if let userActivity = activityDictionary[key] as? NSUserActivity {
                    if let url = userActivity.webpageURL {
                        return handleUrl(url: url, setInitialData: true)
                    }
                }
            }
        }
        return false
    }
    
    public func application(_ application: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        return handleUrl(url: url, setInitialData: false)
    }
    
    public func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([Any]) -> Void) -> Bool {
        return handleUrl(url: userActivity.webpageURL, setInitialData: true)
    }
    
    private func handleUrl(url: URL?, setInitialData: Bool) -> Bool {
        if let url = url {
            let appDomain = Bundle.main.bundleIdentifier!
            let userDefaults = UserDefaults(suiteName: "group.\(appDomain)")
            if url.fragment == "image" {
                if let key = url.host?.components(separatedBy: "=").last,
                    let sharedArray = userDefaults?.object(forKey: key) as? [String] {
                    let absoluteUrls = sharedArray.compactMap{getAbsolutePath(for: $0)}
                    latestImage = absoluteUrls
                    if(setInitialData) {
                        initialImage = latestImage
                    }
                    eventSinkImage?(latestImage)
                }
            } else if url.fragment == "text" {
                if let key = url.host?.components(separatedBy: "=").last,
                    let sharedArray = userDefaults?.object(forKey: key) as? [String] {
                    latestText =  sharedArray.joined(separator: ",")
                    if(setInitialData) {
                        initialText = latestText
                    }
                    eventSinkText?(latestText)
                }
            } else {
                latestText = url.absoluteString
                if(setInitialData) {
                    initialText = latestText
                }
                eventSinkText?(latestText)
            }
            return true
        }
        
        latestImage = nil
        latestText = nil
        return false
    }
    
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        if (arguments as! String? == "image") {
            eventSinkImage = events;
        } else if (arguments as! String? == "text") {
            eventSinkText = events;
        } else {
            return FlutterError.init(code: "NO_SUCH_ARGUMENT", message: "No such argument\(String(describing: arguments))", details: nil);
        }
        return nil;
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        if (arguments as! String? == "image") {
            eventSinkImage = nil;
        } else if (arguments as! String? == "text") {
            eventSinkText = nil;
        } else {
            return FlutterError.init(code: "NO_SUCH_ARGUMENT", message: "No such argument as \(String(describing: arguments))", details: nil);
        }
        return nil;
    }
    
    private func getAbsolutePath(for identifier: String) -> String? {
        if (identifier.starts(with: "file://") || identifier.starts(with: "/var/mobile/Media") || identifier.starts(with: "/private/var/mobile")) {
            return identifier.replacingOccurrences(of: "file://", with: "")
        }
        let phAsset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: .none).firstObject
        if(phAsset == nil) {
            return nil
        }
        var url: String?
        
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.isNetworkAccessAllowed = true
        PHImageManager.default().requestImageData(for: phAsset!, options: options) { (data, fileName, orientation, info) in
            url = (info?["PHImageFileURLKey"] as? NSURL)?.absoluteString?.replacingOccurrences(of: "file://", with: "")
        }
        return url
    }
}
