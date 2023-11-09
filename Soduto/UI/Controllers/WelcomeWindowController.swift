//
//  WelcomeWindowController.swift
//  Soduto
//
//  Created by Giedrius on 2017-05-24.
//  Copyright © 2017 Soduto. All rights reserved.
//

import Foundation
import Cocoa

class WelcomeWindowController: NSWindowController {
    
    var dismissHandler: ((WelcomeWindowController)->Void)?
    
    var tabViewController: WelcomeTabViewController? {
        assert(self.contentViewController is WelcomeTabViewController)
        return self.contentViewController as? WelcomeTabViewController
    }
    
    var deviceDataSource: DeviceDataSource? {
        get { return self.tabViewController?.deviceDataSource }
        set { self.tabViewController?.deviceDataSource = newValue }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        self.window?.titleVisibility = .hidden
        self.window?.styleMask.insert(.fullSizeContentView)
        self.window?.titlebarAppearsTransparent = true
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleWindowWillClose(_:)), name: NSWindow.willCloseNotification, object: nil)
    }
    
    func refreshDeviceLists() {
        self.tabViewController?.refreshDeviceLists()
    }
    
    @objc private func handleWindowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow == self.window else { return }
        dismissHandler?(self)
    }
}

class WelcomeTabViewController: NSTabViewController {
    
    var deviceDataSource: DeviceDataSource?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        for item in self.tabViewItems {
            guard let itemViewController = item.viewController as? WelcomeTabItemViewController else { assertionFailure("Welcome tab item view controllers must be WelcomeTabItemViewController"); continue }
            itemViewController.tabViewController = self
        }
    }
    
    func selectPreviousTab(_ viewController: NSViewController) {
        guard self.selectedTabViewItemIndex > 0 else { assertionFailure("Current tab is already first."); return }
        self.selectedTabViewItemIndex = self.selectedTabViewItemIndex - 1
    }
    
    func selectNextTab(_ viewController: NSViewController) {
        guard self.selectedTabViewItemIndex < self.tabViewItems.count - 1 else { assertionFailure("Current tab is already last."); return }
        self.selectedTabViewItemIndex = self.selectedTabViewItemIndex + 1
    }
    
    override var selectedTabViewItemIndex: Int {
        didSet {
            if self.selectedTabViewItemIndex > 0 {
                self.view.window?.titlebarAppearsTransparent = false
                self.view.window?.titleVisibility = .visible
                self.view.window?.title = NSLocalizedString("Quick Setup", comment: "")
                self.view.window?.styleMask.remove(.fullSizeContentView)
            }
            else {
                self.view.window?.titlebarAppearsTransparent = true
                self.view.window?.titleVisibility = .hidden
                self.view.window?.title = NSLocalizedString("Welcome to Soduto", comment: "")
                self.view.window?.styleMask.insert(.fullSizeContentView)
            }
        }
    }
    
    func refreshDeviceLists() {
        guard selectedTabViewItemIndex > 0 else { return }
        let selectedTabViewItem = self.tabView.tabViewItem(at: selectedTabViewItemIndex)
        guard let pairingController = selectedTabViewItem.viewController as? PairingTabItemViewController else { return }
        pairingController.refreshDeviceLists()
    }
}

class WelcomeTabItemViewController: NSViewController {
    
    weak var tabViewController: WelcomeTabViewController?
    
    @IBAction func back(_ sender: AnyObject) {
        self.tabViewController?.selectPreviousTab(self)
    }
    
    @IBAction func finish(_ sender: AnyObject) {
        self.view.window?.close()
    }
    
    @IBAction func forward(_ sender: AnyObject) {
        self.tabViewController?.selectNextTab(self)
    }
    
    @IBAction func goToSodutoWebsite(_ sender: AnyObject) {
        guard let url = URL(string: "http://www.soduto.com") else { assertionFailure("Could not create URL"); return }
        NSWorkspace.shared.open(url)
    }
    
    @IBAction func goToKdeConnectLinuxWebsite(_ sender: AnyObject) {
        guard let url = URL(string: "https://community.kde.org/KDEConnect") else { assertionFailure("Could not create URL"); return }
        NSWorkspace.shared.open(url)
    }
    
    @IBAction func goToKdeConnectAndroidWebsite(_ sender: AnyObject) {
        guard let url = URL(string: "https://go.thenoton.com/kde-connect") else { assertionFailure("Could not create URL"); return }
        NSWorkspace.shared.open(url)
    }
    @IBAction func goToZorinConnectAndroidWebsite(_ sender: AnyObject) {
        guard let url = URL(string: "https://play.google.com/store/apps/details?id=com.zorinos.zorin_connect") else { assertionFailure("Could not create URL"); return }
        NSWorkspace.shared.open(url)
    }
}

class PairingTabItemViewController: WelcomeTabItemViewController {
    
    @IBOutlet weak var troubleshootingLabel: NSTextField?
    
    private weak var deviceListController: DeviceListController?
    
    var deviceDataSource: DeviceDataSource? { return self.tabViewController?.deviceDataSource }
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let deviceListController = segue.destinationController as? DeviceListController {
            self.deviceListController = deviceListController
        }
    }
    
    override func viewWillAppear() {
        self.deviceListController?.deviceDataSource = self.deviceDataSource
        self.deviceListController?.refreshDeviceList()
        self.view.layoutSubtreeIfNeeded()
    }
    
    func refreshDeviceLists() {
        self.deviceListController?.refreshDeviceList()
    }
}
