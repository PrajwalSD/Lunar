//
//  SettingsPageController.swift
//  Lunar
//
//  Created by Alin on 21/06/2018.
//  Copyright © 2018 Alin. All rights reserved.
//

import Charts
import Cocoa

class SettingsPageController: NSViewController {
    @IBOutlet var brightnessContrastChart: BrightnessContrastChartView!
    var adaptiveModeObserver: NSKeyValueObservation?
    var pageController: NSPageController?

    func updateDataset(
        display: Display,
        daylightExtension: Int? = nil,
        noonDuration: Int? = nil,
        brightnessOffset: Int? = nil,
        contrastOffset: Int? = nil,
        brightnessLimitMin: Int? = nil,
        contrastLimitMin: Int? = nil,
        brightnessLimitMax: Int? = nil,
        contrastLimitMax: Int? = nil,
        appBrightnessOffset: Int = 0,
        appContrastOffset: Int = 0,
        withAnimation: Bool = false
    ) {
        if display.id == GENERIC_DISPLAY_ID {
            return
        }
        var brightnessChartEntry = brightnessContrastChart.brightnessGraph.values
        var contrastChartEntry = brightnessContrastChart.contrastGraph.values

        switch brightnessAdapter.mode {
        case .location:
            let maxValues = brightnessContrastChart.maxValuesLocation
            for x in 0 ..< (maxValues - 1) {
                let (brightness, contrast) = brightnessAdapter.getBrightnessContrast(
                    for: display,
                    hour: x,
                    daylightExtension: daylightExtension,
                    noonDuration: noonDuration,
                    brightnessOffset: brightnessOffset,
                    contrastOffset: contrastOffset,
                    appBrightnessOffset: appBrightnessOffset,
                    appContrastOffset: appContrastOffset
                )
                brightnessChartEntry[x].y = brightness.doubleValue
                contrastChartEntry[x].y = contrast.doubleValue
            }
            brightnessChartEntry[maxValues - 1].y = brightnessChartEntry[0].y
            contrastChartEntry[maxValues - 1].y = contrastChartEntry[0].y
        case .sync:
            let maxValues = brightnessContrastChart.maxValuesSync
            for x in 0 ..< (maxValues - 1) {
                let percent = Double(x)
                brightnessChartEntry[x].y = display.computeBrightness(from: percent, offset: brightnessOffset, appOffset: appBrightnessOffset).doubleValue
                contrastChartEntry[x].y = display.computeContrast(from: percent, offset: contrastOffset, appOffset: appContrastOffset).doubleValue
            }
        case .manual:
            let maxValues = brightnessContrastChart.maxValuesSync
            for x in 0 ..< (maxValues - 1) {
                brightnessChartEntry[x].y = brightnessAdapter.computeManualValueFromPercent(percent: Int8(x), key: "brightness", minVal: brightnessLimitMin, maxVal: brightnessLimitMax).doubleValue
                contrastChartEntry[x].y = brightnessAdapter.computeManualValueFromPercent(percent: Int8(x), key: "contrast", minVal: contrastLimitMin, maxVal: contrastLimitMax).doubleValue
            }
        }

        if withAnimation {
            brightnessContrastChart.animate(yAxisDuration: 1.0, easingOption: ChartEasingOption.easeOutExpo)
        } else {
            brightnessContrastChart.notifyDataSetChanged()
        }
    }

    func listenForAdaptiveModeChange() {
        adaptiveModeObserver = datastore.defaults.observe(\.adaptiveBrightnessMode, options: [.old, .new], changeHandler: { _, change in
            guard let mode = change.newValue, let oldMode = change.oldValue, mode != oldMode else {
                return
            }
            let adaptiveMode = AdaptiveMode(rawValue: mode)
            if let chart = self.brightnessContrastChart, !chart.visibleRect.isEmpty {
                self.initGraph(display: brightnessAdapter.firstDisplay, mode: adaptiveMode)
            }
        })
    }

    func initGraph(display: Display?, mode: AdaptiveMode? = nil) {
        brightnessContrastChart?.initGraph(display: display, brightnessColor: brightnessGraphColorYellow, contrastColor: contrastGraphColorYellow, labelColor: xAxisLabelColorYellow, mode: mode)
    }

    func zeroGraph() {
        initGraph(display: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        view.layer?.backgroundColor = settingsBgColor.cgColor
        initGraph(display: nil)
        listenForAdaptiveModeChange()
    }
}
