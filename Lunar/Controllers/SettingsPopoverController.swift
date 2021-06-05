//
//  SettingsPopoverController.swift
//  Lunar
//
//  Created by Alin Panaitiu on 05.04.2021.
//  Copyright © 2021 Alin. All rights reserved.
//

import Cocoa
import Defaults

class SettingsPopoverController: NSViewController {
    let SYNC_MODE_ROLE_HELP_TEXT = """
    ## Description

    `Available only for monitors with a built-in light sensor that are controllable using CoreDisplay`

    This setting allows the user to choose a monitor to be used as the source when a built-in display is not available or can't be used (e.g. MacBook lid closed, Mac Mini).

    - `SOURCE`: Sync Mode will read this monitor's brightness/contrast and send it to the other external monitors
    - `TARGET`: Sync Mode will send brightness/contrast to this monitor after detecting a brightness change on the built-in/source monitor
    """
    let ADAPTIVE_HELP_TEXT = """
    ## Description

    `Available only in Sync, Location and Sensor mode`

    This setting allows the user to **pause** the adaptive algorithm on a **per-monitor** basis.

    - `RUNNING` will **allow** Lunar to change the brightness and contrast automatically for this monitor
    - `PAUSED` will **restrict** Lunar from changing the brightness and contrast automatically for this monitor
    """
    let DDC_LIMITS_HELP_TEXT = """
    ## Description

    `Available only in Sync, Location and Sensor mode`

    This setting allows the user to **pause** the adaptive algorithm on a **per-monitor** basis.

    - `RUNNING` will **allow** Lunar to change the brightness and contrast automatically for this monitor
    - `PAUSED` will **restrict** Lunar from changing the brightness and contrast automatically for this monitor
    """
    @IBOutlet var networkControlCheckbox: NSButton!
    @IBOutlet var coreDisplayControlCheckbox: NSButton!
    @IBOutlet var ddcControlCheckbox: NSButton!
    @IBOutlet var gammaControlCheckbox: NSButton!
    @IBOutlet var resetNetworkControlButton: ResetButton!
    @IBOutlet var resetDDCButton: ResetButton!

    @IBOutlet var maxDDCBrightnessField: ScrollableTextField!
    @IBOutlet var maxDDCContrastField: ScrollableTextField!
    @IBOutlet var maxDDCVolumeField: ScrollableTextField!

    @IBOutlet var adaptAutoToggle: MacToggle!
    @IBOutlet var syncModeRoleToggle: MacToggle!

    @IBOutlet var _ddcLimitsHelpButton: NSButton!
    var ddcLimitsHelpButton: HelpButton? {
        _ddcLimitsHelpButton as? HelpButton
    }

    @IBOutlet var _adaptAutomaticallyHelpButton: NSButton?
    var adaptAutomaticallyHelpButton: HelpButton? {
        _adaptAutomaticallyHelpButton as? HelpButton
    }

    @IBOutlet var _syncModeRoleHelpButton: NSButton?
    var syncModeRoleHelpButton: HelpButton? {
        _syncModeRoleHelpButton as? HelpButton
    }

    var lastEnabledCheckbox: NSButton? {
        [networkControlCheckbox, coreDisplayControlCheckbox, ddcControlCheckbox, gammaControlCheckbox]
            .first(where: { checkbox in checkbox!.state == .on })
    }

    var onClick: (() -> Void)?
    weak var display: Display? {
        didSet {
            guard let display = display else { return }

            applySettings = false
            defer {
                applySettings = true
            }

            mainThread {
                networkEnabled = display.enabledControls[.network] ?? true
                coreDisplayEnabled = display.enabledControls[.coreDisplay] ?? true
                ddcEnabled = display.enabledControls[.ddc] ?? true
                gammaEnabled = display.enabledControls[.gamma] ?? true

                adaptAutoToggle.isOn = display.adaptive
                syncModeRoleToggle.isOn = display.isSource
            }
            setupDDCLimits(display)
        }
    }

    var applySettings = true

    @objc dynamic var adaptive = true {
        didSet {
            guard applySettings, let display = display else { return }
            if adaptive {
                display.adaptivePaused = false
            }
            display.adaptive = adaptive
            display.save()
        }
    }

    @objc dynamic var isSource = false {
        didSet {
            guard applySettings, let display = display else { return }
            display.isSource = isSource
            display.save()
        }
    }

    @objc dynamic var networkEnabled = true {
        didSet {
            guard applySettings, let display = display else { return }
            display.enabledControls[.network] = networkEnabled
            display.save()
            display.control = display.getBestControl()
            display.onControlChange?(display.control)

            ensureAtLeastOneControlEnabled()
        }
    }

    @objc dynamic var coreDisplayEnabled = true {
        didSet {
            guard applySettings, let display = display else { return }
            display.enabledControls[.coreDisplay] = coreDisplayEnabled
            display.save()
            display.control = display.getBestControl()
            display.onControlChange?(display.control)

            ensureAtLeastOneControlEnabled()
        }
    }

    @objc dynamic var ddcEnabled = true {
        didSet {
            guard applySettings, let display = display else { return }
            display.enabledControls[.ddc] = ddcEnabled
            display.save()
            display.control = display.getBestControl()
            display.onControlChange?(display.control)

            ensureAtLeastOneControlEnabled()
        }
    }

    @objc dynamic var gammaEnabled = true {
        didSet {
            guard applySettings, let display = display else { return }
            display.enabledControls[.gamma] = gammaEnabled
            display.save()
            display.control = display.getBestControl()
            display.onControlChange?(display.control)

            ensureAtLeastOneControlEnabled()
        }
    }

    @IBAction func resetDDC(_: Any) {
        asyncAfter(ms: 10, uniqueTaskKey: "resetDDCTask") { [weak self] in
            guard let display = self?.display else { return }
            if display.control is DDCControl {
                display.control.resetState()
            } else {
                DDCControl(display: display).resetState()
            }

            for _ in 1 ... 5 {
                displayController.adaptBrightness(force: true)
                sleep(3)
            }
        }
    }

    @IBAction func resetNetworkController(_: Any) {
        asyncAfter(ms: 10, uniqueTaskKey: "resetNetworkControlTask") { [weak self] in
            guard let display = self?.display else { return }
            if display.control is NetworkControl {
                display.control.resetState()
            } else {
                NetworkControl.resetState()
            }

            for _ in 1 ... 5 {
                displayController.adaptBrightness(force: true)
                sleep(3)
            }
        }
    }

    func ensureAtLeastOneControlEnabled() {
        guard let display = display else { return }
        if display.enabledControls.values.filter({ enabled in enabled }).count <= 1 {
            if let checkbox = lastEnabledCheckbox {
                mainThread {
                    checkbox.isEnabled = false
                    checkbox.needsDisplay = true
                }
            } else {
                applySettings = false
                gammaEnabled = true
                display.enabledControls[.gamma] = gammaEnabled
                applySettings = true

                mainThread {
                    gammaControlCheckbox.isEnabled = false
                    gammaControlCheckbox.needsDisplay = true
                }
            }
        } else {
            mainThread {
                networkControlCheckbox.isEnabled = true
                coreDisplayControlCheckbox.isEnabled = true
                ddcControlCheckbox.isEnabled = true
                gammaControlCheckbox.isEnabled = true

                networkControlCheckbox.needsDisplay = true
                coreDisplayControlCheckbox.needsDisplay = true
                ddcControlCheckbox.needsDisplay = true
                gammaControlCheckbox.needsDisplay = true
            }
        }
    }

    @inline(__always) func toggleWithoutCallback(_ toggle: MacToggle, value: Bool) {
        let callback = toggle.callback
        toggle.callback = nil
        toggle.isOn = value
        toggle.callback = callback
    }

    func setupDDCLimits(_ display: Display? = nil) {
        if let display = display ?? self.display {
            mainThread {
                maxDDCBrightnessField.intValue = display.maxDDCBrightness.int32Value
                maxDDCContrastField.intValue = display.maxDDCContrast.int32Value
                maxDDCVolumeField.intValue = display.maxDDCVolume.int32Value
            }

            maxDDCBrightnessField.onValueChanged = { [weak display] value in display?.maxDDCBrightness = value.ns }
            maxDDCContrastField.onValueChanged = { [weak display] value in display?.maxDDCContrast = value.ns }
            maxDDCVolumeField.onValueChanged = { [weak display] value in display?.maxDDCVolume = value.ns }
        }
    }

    var displaysObserver: Defaults.Observation?

    override func viewDidLoad() {
        super.viewDidLoad()
        resetNetworkControlButton?.page = .hotkeysReset
        resetDDCButton?.page = .hotkeysReset

        syncModeRoleHelpButton?.helpText = SYNC_MODE_ROLE_HELP_TEXT
        adaptAutomaticallyHelpButton?.helpText = ADAPTIVE_HELP_TEXT
        ddcLimitsHelpButton?.helpText = DDC_LIMITS_HELP_TEXT

        adaptAutoToggle.callback = { [weak self] isOn in
            self?.adaptive = isOn
        }
        
        syncModeRoleToggle.callback = { [weak self] isOn in
            self?.isSource = isOn
            if isOn {
                for display in displayController.displays.values {
                    display.isSource = false
                }
                datastore.storeDisplays(displayController.displays.values.map { $0 })
            }
            SyncMode.sourceDisplay = SyncMode.getSourceDisplay()
        }
        syncModeRoleToggle.isEnabled = false
        setupDDCLimits()

        displaysObserver = displaysObserver ?? Defaults.observe(.displays) { [weak self] change in
            guard let self = self, let thisDisplay = self.display, let displays = change.newValue,
                  let display = displays.first(where: { d in d.serial == thisDisplay.serial }) else { return }
            self.applySettings = false
            defer {
                self.applySettings = true
            }
            self.networkEnabled = display.enabledControls[.network] ?? true
            self.coreDisplayEnabled = display.enabledControls[.coreDisplay] ?? true
            self.ddcEnabled = display.enabledControls[.ddc] ?? true
            self.gammaEnabled = display.enabledControls[.gamma] ?? true
            mainThread {
                self.toggleWithoutCallback(self.adaptAutoToggle, value: display.adaptive)
                self.toggleWithoutCallback(self.syncModeRoleToggle, value: display.isSource)
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
        super.mouseDown(with: event)
    }
}