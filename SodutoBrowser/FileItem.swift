//
//  FileItem.swift
//  Soduto
//
//  Created by Giedrius on 2017-03-05.
//  Copyright © 2017 Soduto. All rights reserved.
//

import Foundation
import AppKit
import CleanroomLogger

public class FileItem: NSObject, NSPasteboardReading, NSPasteboardWriting {
    
    public struct Flags: OptionSet {
        public let rawValue: Int
        
        public init(rawValue: Int) { self.rawValue = rawValue }
        
        public static let isDirectory = Flags(rawValue: 1 << 0)
        public static let isHidden = Flags(rawValue: 1 << 1)
        public static let isReadable = Flags(rawValue: 1 << 2)
        public static let isWritable = Flags(rawValue: 1 << 3)
        public static let isBusy = Flags(rawValue: 1 << 4)    // Indicates, that there is pending operation on the item
        public static let isDeleted = Flags(rawValue: 1 << 5) // Indicates that item is already deleted and this is just a placeholder
    }

    
    public let url: URL
    public let name: String
    public let icon: NSImage
    public let staticFlags: Flags
    public var dynamicFlags: Flags = []
    
    public var flags: Flags { return self.staticFlags.union(self.dynamicFlags) }
    @objc dynamic public var isDirectory: Bool { return self.flags.contains(.isDirectory) }
    @objc dynamic public var isHidden: Bool { return self.flags.contains(.isHidden) }
    @objc dynamic public var isBusy: Bool { return self.flags.contains(.isBusy) }
    @objc dynamic public var isDeleted: Bool { return self.flags.contains(.isDeleted) }
    @objc dynamic public var isReadable: Bool { return self.flags.contains(.isReadable) }
    @objc dynamic public var isWritable: Bool { return self.flags.contains(.isWritable) }
    @objc dynamic public var canRead: Bool { return self.isReadable && !self.isBusy && !self.isDeleted }
    @objc dynamic public var canModify: Bool { return self.isWritable && !self.isBusy && !self.isDeleted }
    
    public init(url: URL, name: String, icon: NSImage, flags: Flags) {
        self.url = url
        self.name = name
        self.icon = icon
        self.staticFlags = flags
    }
    
    public convenience init(url: URL) {
        if url.isFileURL {
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            do {
                let resourceValues = try url.resourceValues(forKeys: [URLResourceKey.isHiddenKey, URLResourceKey.localizedNameKey, URLResourceKey.isDirectoryKey])
                let name = resourceValues.localizedName ?? url.lastPathComponent
                var flags: Flags = []
                if resourceValues.isDirectory == true { flags.insert(.isDirectory) }
                if resourceValues.isHidden == true { flags.insert(.isHidden) }
                if FileManager.default.isReadableFile(atPath: url.path) { flags.insert(.isReadable) }
                if FileManager.default.isWritableFile(atPath: url.path) { flags.insert(.isWritable) }
                self.init(url: url, name: name, icon: icon, flags: flags)
            }
            catch {
                Log.error?.message("Failed retrieving file resource information for url [\(url)]: \(error)")
                let name = url.lastPathComponent
                var flags: Flags = []
                if url.hasDirectoryPath { flags.insert(.isDirectory) }
                if url.lastPathComponent.hasPrefix(".") { flags.insert(.isHidden) }
                if FileManager.default.isReadableFile(atPath: url.path) { flags.insert(.isReadable) }
                if FileManager.default.isWritableFile(atPath: url.path) { flags.insert(.isWritable) }
                self.init(url: url, name: name, icon: icon, flags: flags)
            }
        }
        else {
            let name = url.lastPathComponent
            var flags: Flags = [.isReadable, .isWritable]
            if url.hasDirectoryPath { flags.insert(.isDirectory) }
            if url.lastPathComponent.hasPrefix(".") { flags.insert(.isHidden) }
            let fileType: String = flags.contains(.isDirectory) ? String(kUTTypeDirectory) : url.pathExtension
            let icon = flags.contains(.isDirectory) ? NSImage(named: NSImage.Name.folder)! : NSWorkspace.shared.icon(forFileType: fileType)
            self.init(url: url, name: name, icon: icon, flags: flags)

        }
    }

    
    // MARK: NSPasteboardWriting
    
    public func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        if self.url.isFileURL {
            if self.isDirectory {
                return [
                    NSPasteboard.PasteboardType(rawValue: kPasteboardTypeFileURLPromise),
                    NSPasteboard.PasteboardType(rawValue: kPasteboardTypeFilePromiseContent),
                    NSPasteboard.PasteboardType(rawValue: kUTTypeDirectory as String),
                    NSPasteboard.PasteboardType(rawValue: kUTTypeFileURL as String),
                    NSPasteboard.PasteboardType(rawValue: kUTTypeURL as String) ]
            }
            else {
                return [
                    NSPasteboard.PasteboardType(rawValue: kPasteboardTypeFileURLPromise),
                    NSPasteboard.PasteboardType(rawValue: kPasteboardTypeFilePromiseContent),
                    NSPasteboard.PasteboardType(rawValue: kUTTypeFileURL as String),
                    NSPasteboard.PasteboardType(rawValue: kUTTypeURL as String) ]
            }
        }
        else {
            return [
                NSPasteboard.PasteboardType(rawValue: kPasteboardTypeFileURLPromise),
                NSPasteboard.PasteboardType(rawValue: kPasteboardTypeFilePromiseContent),
                NSPasteboard.PasteboardType(rawValue: kUTTypeURL as String) ]
        }
    }
    
    public func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        switch type.rawValue {
        case String(kUTTypeDirectory):
            guard self.url.isFileURL && self.isDirectory else { return nil }
            return self.url.path
        case String(kUTTypeFileURL):
            guard self.url.isFileURL else { return nil }
            return (self.url as NSURL).pasteboardPropertyList(forType: type)
        case String(kUTTypeURL):
            return (self.url as NSURL).pasteboardPropertyList(forType: type)
        case String(kPasteboardTypeFilePromiseContent):
            return  kUTTypeBMP
        case String(kPasteboardTypeFileURLPromise):
            return nil
        default:
            return nil
        }
    }
    

    // MARK: NSPasteboardReading
    
    public static func readableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        return [ kUTTypeURL as NSPasteboard.PasteboardType ]
    }
    
    public static func readingOptions(forType type: NSPasteboard.PasteboardType, pasteboard: NSPasteboard) -> NSPasteboard.ReadingOptions {
        return NSURL.readingOptions(forType: type, pasteboard: pasteboard)
    }
    
    public required convenience init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        guard let url = NSURL(pasteboardPropertyList: propertyList, ofType: type) as URL? else { return nil }
        self.init(url: url as URL)
    }
    
}
