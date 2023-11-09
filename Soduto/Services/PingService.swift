//
//  PingService.swift
//  Soduto
//
//  Created by Giedrius Stanevičius on 2016-11-18.
//  Copyright © 2016 Soduto. All rights reserved.
//

import Foundation
import UserNotifications

/// Ping service data packet utilities
fileprivate extension DataPacket {
    
    static let pingPacketType = "kdeconnect.ping"
    
    enum PingError: Error {
        case wrongType
        case invalidMessage
    }
    
    enum PingProperty: String {
        case message = "message"
    }
    
    static func pingPacket() -> DataPacket {
        return DataPacket(type: pingPacketType, body: [
            PingProperty.message.rawValue: "Device was pinged for testing connection status!" as AnyObject
        ])
    }
    
    func getMessage() throws -> String? {
        try self.validatePingType()
        guard body.keys.contains(PingProperty.message.rawValue) else { return nil }
        guard let message = body[PingProperty.message.rawValue] as? String else { throw PingError.invalidMessage }
        return message
    }
    
    var isPingPacket: Bool { return self.type == DataPacket.pingPacketType }
    
    func validatePingType() throws {
        guard self.isPingPacket else { throw PingError.wrongType }
    }
}

/// Service providing capability to send end receive "pings" - short messages that can be used to test 
/// devices connectivity
///
/// This service displays a notification to the user each time a package with type
/// "kdeconnect.ping" is received. If the package has something in the "message"
/// field, that will be displayed in the notification body.
public class PingService: Service {
    
    let un = UNUserNotificationCenter.current()
    
    // MARK: Types
    
    enum ActionId: ServiceAction.Id {
        case send
    }
    
    
    // MARK: Service properties
    
    public static let serviceId: Service.Id = "com.soduto.services.ping"
    
    public let incomingCapabilities = Set<Service.Capability>([ DataPacket.pingPacketType ])
    public let outgoingCapabilities = Set<Service.Capability>([ DataPacket.pingPacketType ])
    
    
    // MARK: Service methods
    
    public func handleDataPacket(_ dataPacket: DataPacket, fromDevice device: Device, onConnection connection: Connection) -> Bool {
        
        guard dataPacket.isPingPacket else { return false }
        
        self.showNotification(for: dataPacket, from: device)
        
        return true
    }
    
    public func setup(for device: Device) {}
    
    public func cleanup(for device: Device) {}
    
    public func actions(for device: Device) -> [ServiceAction] {
        guard device.incomingCapabilities.contains(DataPacket.pingPacketType) else { return [] }
        guard device.pairingStatus == .Paired else { return [] }
        
        return [
            ServiceAction(id: ActionId.send.rawValue, group: "setup", title: "Test Connection", description: "Send ping to the remote device to test connectivity", service: self, device: device)
        ]
    }
    
    public func performAction(_ id: ServiceAction.Id, forDevice device: Device) {
        guard let actionId = ActionId(rawValue: id) else { return }
        guard device.pairingStatus == .Paired else { return }
        
        switch actionId {
        case .send:
            device.send(DataPacket.pingPacket())
            break
        }
        
    }
    
    
    // MARK: Private methods
    
    private func showNotification(for dataPacket: DataPacket, from device: Device) {
        assert(dataPacket.isPingPacket, "Expected ping data packet")
        
        if #available(macOS 11.0, *) {
            un.requestAuthorization(options: [.alert, .sound]) { (authorized, error) in
                if authorized {
                    print("Authorized to send notifications!")
                } else if !authorized {
                    print("Not authorized to send notifications")
                } else {
                    print(error?.localizedDescription as Any)
                }
            }
            un.getNotificationSettings { (settings) in
                if settings.authorizationStatus == .authorized {
                    let pingnotification = UNMutableNotificationContent()
                    
                    pingnotification.title = device.name
                    pingnotification.body = "Device was pinged for testing connection status!"
                    pingnotification.sound = UNNotificationSound.default()
                    
                    let id = "\(self.id).\(device.id)"
//                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                    let pingrequest = UNNotificationRequest(identifier: id, content: pingnotification, trigger: nil)
                    self.un.add(pingrequest){ (error) in
                        if error != nil {print(error?.localizedDescription as Any)}
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(5)) {
                        self.un.removeDeliveredNotifications(withIdentifiers: [id])
                    }
                }
            }
        } else {
            let notification = NSUserNotification()
            notification.title = device.name
            notification.informativeText = try? dataPacket.getMessage() ?? "Device was pinged for testing connection status!"
            notification.soundName = NSUserNotificationDefaultSoundName
            notification.hasActionButton = false
            notification.identifier = "\(self.id).\(device.id)"
            NSUserNotificationCenter.default.scheduleNotification(notification)
            
            _ = Timer.compatScheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
                NSUserNotificationCenter.default.removeDeliveredNotification(notification)
            }
        }
    }
}
