


import Cocoa
import CoreWLAN

class JWListView: NSView, NSTableViewDelegate, NSTableViewDataSource {
	var interfaceName = ""
	var networks: [CWNetwork] = []
	var scanButton: NSButton?
	var disassociateButton: NSButton?
	var jamButton: NSButton?
	var progressIndicator: NSProgressIndicator?
	var networksScrollView: NSScrollView?
	var networksTable: NSTableView?
	
	var sortAscending = true
	var sortOrder = ""
	
	
	override init(frame: NSRect) {
		super.init(frame: frame)
		
		networksScrollView = NSScrollView(frame: NSRect(x: 10, y: 52, width: frame.size.width - 20, height: frame.size.height - 62))
		networksTable = NSTableView(frame: networksScrollView?.contentView.bounds ?? NSRect.zero)
		disassociateButton = NSButton(frame: NSRect(x: 10, y: 10, width: 100, height: 24))
		scanButton = NSButton(frame: NSRect(x: 110, y: 10, width: 100, height: 24))
		progressIndicator = NSProgressIndicator(frame: NSRect(x: 225, y: 14, width: 16, height: 16))
		jamButton = NSButton(frame: NSRect(x: frame.size.width - 110, y: 10, width: 100, height: 24))
		
		progressIndicator?.controlSize = .small
		progressIndicator?.style = .spinning
		progressIndicator?.isDisplayedWhenStopped = false
		
		scanButton?.bezelStyle = .rounded
		scanButton?.title = "Scan"
		scanButton?.target = self
		scanButton?.action = #selector(scanButton(_:))
		scanButton?.font = NSFont.systemFont(ofSize: 13)
		
		disassociateButton?.bezelStyle = .rounded
		disassociateButton?.title = "Deauth"
		disassociateButton?.target = self
		disassociateButton?.action = #selector(disassociateButton(_:))
		disassociateButton?.font = NSFont.systemFont(ofSize: 13)
		
		jamButton?.bezelStyle = .rounded
		jamButton?.title = "Monitor"
		jamButton?.target = self
		jamButton?.action = #selector(jamButton(_:))
		jamButton?.font = NSFont.systemFont(ofSize: 13)
		jamButton?.isEnabled = false
		
		let channelColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("channel"))
		channelColumn.headerCell.stringValue = "CH"
		channelColumn.width = 40
		channelColumn.isEditable = true
		channelColumn.sortDescriptorPrototype = NSSortDescriptor(key: channelColumn.identifier.rawValue, ascending: true)
		networksTable?.addTableColumn(channelColumn)
		
		let essidColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("essid"))
		essidColumn.headerCell.stringValue = "ESSID"
		essidColumn.width = 170
		essidColumn.isEditable = true
		essidColumn.sortDescriptorPrototype = NSSortDescriptor(key: essidColumn.identifier.rawValue, ascending: true)
		networksTable?.addTableColumn(essidColumn)
		
		let bssidColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("bssid"))
		bssidColumn.headerCell.stringValue = "BSSID"
		bssidColumn.width = 120
		bssidColumn.isEditable = true
		bssidColumn.sortDescriptorPrototype = NSSortDescriptor(key: bssidColumn.identifier.rawValue, ascending: true)
		networksTable?.addTableColumn(bssidColumn)
		
		let encColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("enc"))
		encColumn.headerCell.stringValue = "Security"
		encColumn.width = 160
		encColumn.isEditable = true
		encColumn.sortDescriptorPrototype = NSSortDescriptor(key: encColumn.identifier.rawValue, ascending: true)
		networksTable?.addTableColumn(encColumn)
		
		let rssiColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("rssi"))
		rssiColumn.headerCell.stringValue = "RSSI"
		rssiColumn.width = 60
		rssiColumn.isEditable = true
		rssiColumn.sortDescriptorPrototype = NSSortDescriptor(key: rssiColumn.identifier.rawValue, ascending: true)
		networksTable?.addTableColumn(rssiColumn)
		
		networksScrollView?.documentView = networksTable
		networksScrollView?.borderType = .bezelBorder
		networksScrollView?.hasVerticalScroller = true
		networksScrollView?.hasHorizontalScroller = true
		networksScrollView?.autohidesScrollers = false
		networksScrollView?.hasHorizontalScroller = false
//		networksScrollView?.hasVerticalScroller = false
//		print("Scroller: \(networksScrollView?.verticalScroller?.frame.width)")
		
		networksTable?.dataSource = self
		networksTable?.delegate = self
		networksTable?.allowsMultipleSelection = true
		networksTable?.refusesFirstResponder = true
		
		if let _ = networksScrollView { addSubview(networksScrollView!) }
		if let _ = scanButton { addSubview(scanButton!) }
		if let _ = disassociateButton { addSubview(disassociateButton!) }
		if let _ = progressIndicator { addSubview(progressIndicator!) }
		if let _ = jamButton { addSubview(jamButton!) }
		
		autoresizesSubviews = true
		autoresizingMask = [.width, .height]
		networksScrollView?.autoresizingMask = [.width, .height]
		jamButton?.autoresizingMask = .minXMargin
	
	}
	
	required init?(coder decoder: NSCoder) {
		super.init(coder: decoder)
		//fatalError("init(coder:) has not been implemented")
	}
	
	@objc func scanButton(_ sender: Any?) {
		
		progressIndicator?.startAnimation(self)
		scanButton?.isEnabled = false
		scanInBackground()
	}
	
	@objc func disassociateButton(_ sender: Any?) {
		CWWiFiClient.shared().interface()!.disassociate()
	}
	
	@objc func jamButton(_ sender: Any?) {
		var theNetworks: [CWNetwork] = []
		
		
		for idx in networksTable?.selectedRowIndexes ?? [] {
			theNetworks.append(self.networks[idx])
		}
		let sniffer = ANWiFiSniffer(interfaceName: interfaceName)
		let gatherer = JWTrafficGatherer(frame: bounds, sniffer: sniffer, networks: theNetworks)
		(NSApp.delegate as? JWAppDelegate)?.push(gatherer, direction: .forward)
	}
	
	func scanInBackground() {
		let queue = DispatchQueue.global(qos: .default)
		weak var weakSelf = self
		queue.async(execute: {
			self.interfaceName = CWWiFiClient.shared().interface()?.interfaceName ?? "en0"
			var airportHandle: UnsafeMutableRawPointer?
			var foundNets: UnsafeMutableRawPointer?
			
			let scanParams: NSDictionary = UserDefaults.standard.dictionary(forKey: "USER_SCAN_OPTIONS") as NSDictionary? ?? NSDictionary()
				

			_ = _open!(&airportHandle)
			_ = _bind!(airportHandle, self.interfaceName)
			_ = _scan!(airportHandle, &foundNets, scanParams)
			

			if foundNets == nil {
				print("wifi scan error")
				
				// Cleanup
				_ = _close!(airportHandle)
				
				weakSelf?.performSelector(onMainThread: #selector(self.handleScanError), with: nil, waitUntilDone: false)
			} else {
				
				var networks: [CWNetwork] = []
	
				for dict in unsafeBitCast(foundNets, to: NSArray.self) {
					let network = CWNetwork()
					network.setValue(dict, forKey: "_scanRecord")
					networks.append(network)
				}
				
				// Cleanup
				_ = _close!(airportHandle)
				
				
				weakSelf?.performSelector(onMainThread: #selector(self.handleScanSuccess(_:)), with: networks, waitUntilDone: false)
			}
		})
	}
	
	func numberOfRows(in tableView: NSTableView) -> Int {
		return networks.count
	}
	
	func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
		let network = networks[row]
		
		if tableColumn?.identifier.rawValue == "channel" {
			return NSNumber(value: network.wlanChannel?.channelNumber ?? 0)
		} else if tableColumn?.identifier.rawValue == "essid" {
			return network.ssid ?? "<Hidden>"
		} else if tableColumn?.identifier.rawValue == "bssid" {
			return network.bssid
		} else if tableColumn?.identifier.rawValue == "enc" {
			return securityTypeString(network)
		} else if tableColumn?.identifier.rawValue == "rssi" {
			return NSNumber(value: network.rssiValue).description
		}
		return nil
	}
	
	func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int) {
		return
	}
	func tableViewSelectionDidChange(_ notification: Notification) {
		if networksTable?.selectedRowIndexes.count ?? 0 > 0 {
			jamButton?.isEnabled = true
		} else {
			jamButton?.isEnabled = false
		}
	}
	
	func securityTypeString(_ network: CWNetwork?) -> String {
		var securityArray: [String] = []
		if network?.supportsSecurity(.none) ?? false {
			return "Open"
		}
		if network?.supportsSecurity(.WEP) ?? false {
			securityArray.append("WEP")
		}
		if network?.supportsSecurity(.dynamicWEP) ?? false {
			securityArray.append("Dynamic WEP")
		}
		if network?.supportsSecurity(.wpaPersonal) ?? false {
			securityArray.append("WPA (P)")
		}
		if network?.supportsSecurity(.wpa2Personal) ?? false {
			securityArray.append("WPA2 (P)")
		}
		if network?.supportsSecurity(.wpaEnterprise) ?? false {
			securityArray.append("WPA (E)")
		}
		if network?.supportsSecurity(.wpa2Enterprise) ?? false {
			securityArray.append("WPA2 (E)")
		}
		if network?.supportsSecurity(.unknown) ?? false {
			securityArray.append("Unknown")
		}
		
		if securityArray.count == 0 {
			return "?"
		} else {
			return securityArray.joined(separator: " / ")
		}
		
	}
	func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
		
		guard let sortDescriptor = tableView.sortDescriptors.first else {
		   return
		 }
		
		sortAscending = sortDescriptor.ascending
		sortOrder = sortDescriptor.key!
		sortNetworks()
		networksTable?.reloadData()
	}
	
	func sortNetworks() {
		if sortOrder == "" { return }
		
		let order: ComparisonResult = sortAscending ? .orderedAscending : .orderedDescending
		
		switch sortOrder {
			case "channel": networks.sort { String($0.wlanChannel!.channelNumber).localizedStandardCompare(String($1.wlanChannel!.channelNumber)) == order}; break
			case "essid": networks.sort { ($0.ssid ?? "<Hidden>").localizedStandardCompare($1.ssid ?? "<Hidden>") == order}; break
			case "bssid": networks.sort { $0.bssid?.localizedStandardCompare($1.bssid!) == order}; break
			case "enc": networks.sort { securityTypeString($0).localizedStandardCompare(securityTypeString($1)) == order}; break
			case "rssi": networks.sort { String($0.rssiValue).localizedStandardCompare(String($1.rssiValue)) == order}; break
			default: break
		}
		
	}
	
	// MARK: - Private -
	@objc private func handleScanError() {
		progressIndicator?.stopAnimation(self)
		scanButton?.isEnabled = true
		runAlert("Scan Failed", "A network scan could not be completed at this time.")
	}
	
	@objc private func handleScanSuccess(_ theNetworks: [CWNetwork]?) {
		var newNetworks = theNetworks
		for network in networks {
			if !newNetworks!.contains(network) {
				newNetworks?.append(network)
			}
		}
		
		
		progressIndicator?.stopAnimation(self)
		scanButton?.isEnabled = true
		networks = newNetworks ?? networks
		
		sortNetworks()
		networksTable?.reloadData()
	}

}

