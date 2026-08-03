import Foundation

private let notificationName = Notification.Name("net.xgxgx.GazeAwake.stateDidChange")

final class Listener: NSObject {
    @objc func stateChanged(_ notification: Notification) {
        guard let value = notification.userInfo?["isLookingAtScreen"] as? Bool else { return }
        print("isLookingAtScreen: \(value)")
        fflush(stdout)
    }
}

let listener = Listener()
DistributedNotificationCenter.default().addObserver(
    listener,
    selector: #selector(Listener.stateChanged(_:)),
    name: notificationName,
    object: nil,
    suspensionBehavior: .deliverImmediately
)
print("Listening for \(notificationName.rawValue)…")
RunLoop.current.run()
