//
//  PopUpButton.swift
//  Lunar
//
//  Created by Alin on 23/12/2017.
//  Copyright © 2017 Alin. All rights reserved.
//

import Cocoa
import Combine
import Defaults
import SwiftyAttributes

// MARK: - PopUpButtonCell

class PopUpButtonCell: NSPopUpButtonCell {
    var textColor: NSColor?
    var dotColor: NSColor?
    @IBInspectable var prefix: String = ""

    override func drawTitle(_ title: NSAttributedString, withFrame frame: NSRect, in controlView: NSView) -> NSRect {
        guard let color = textColor else {
            return super.drawTitle(title, withFrame: frame, in: controlView)
        }

        let titleString = "\(prefix)\(title.string)"
        let title = titleString.withAttribute(.textColor(color))
        if titleString.count > 5, let dotColor = dotColor, let font = NSFont(name: "HiraKakuProN-W3", size: 11.0) {
            title.addAttributes([.font(font), .textColor(dotColor)], range: 0 ..< 3)
            title.addAttributes([.font(.boldSystemFont(ofSize: NSFont.smallSystemFontSize)), .textColor(color)], range: 3 ..< title.length)
        }
        return super.drawTitle(title, withFrame: frame, in: controlView)
    }
}

// MARK: - Origin

enum Origin {
    case left
    case center
    case right
}

// MARK: - PopUpButton

class PopUpButton: NSPopUpButton {
    // MARK: Lifecycle

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    // MARK: Internal

    @IBInspectable dynamic var dotColorSecondary: Bool = false
    @IBInspectable dynamic var dotColor: NSColor? = nil

    var hoverState = HoverState.noHover

    var observers: Set<AnyCancellable> = []

    var origin = Origin.center

    @IBInspectable var padding: CGFloat = 16 {
        didSet { resizeToFitTitle() }
    }

    @IBInspectable var verticalPadding: CGFloat = 10 {
        didSet {
            setFrameSize(NSSize(width: frame.width, height: frame.height + verticalPadding))
            radius = (frame.height / 2).ns
            trackHover()
        }
    }

    @IBInspectable var maxWidth: CGFloat = 0 {
        didSet { resizeToFitTitle() }
    }

    var page = Page.display {
        didSet {
            setColors()
        }
    }

    override var isEnabled: Bool {
        didSet { fade() }
    }

    var bgColor: NSColor {
        if !isEnabled {
            return (offStateButtonColor[hoverState]![page] ?? offStateButtonColor[hoverState]![.display]!)
                .with(saturation: -0.2, brightness: -0.1)
        } else if state == .off {
            return onStateButtonColor[hoverState]![page] ?? onStateButtonColor[hoverState]![.display]!
        } else {
            return offStateButtonColor[hoverState]![page] ?? offStateButtonColor[hoverState]![.display]!
        }
    }

    var labelColor: NSColor {
        if !isEnabled {
            return (offStateButtonLabelColor[hoverState]![page] ?? offStateButtonLabelColor[hoverState]![.display]!)
                .highlight(withLevel: 0.3)!.with(alpha: -0.4)
        } else if state == .off {
            return onStateButtonLabelColor[hoverState]![page] ?? offStateButtonLabelColor[hoverState]![.display]!
        } else {
            return offStateButtonLabelColor[hoverState]![page] ?? offStateButtonLabelColor[hoverState]![.display]!
        }
    }

    func getDotColor(modeKey: AdaptiveModeKey? = nil, overrideMode: Bool? = nil) -> NSColor {
        dotColor ?? (dotColorSecondary ? dropdownArrowSecondaryColor : dropdownArrowColor)
    }

    override func mouseEntered(with _: NSEvent) {
        hover()
    }

    override func mouseExited(with _: NSEvent) {
        defocus()
    }

    func setColors(fadeDuration: TimeInterval = 0.2, modeKey: AdaptiveModeKey? = nil, overrideMode: Bool? = nil) {
        if let cell = cell as? PopUpButtonCell {
            cell.textColor = labelColor
            cell.dotColor = getDotColor().with(alpha: isEnabled ? 0 : -0.4)
        }
        layer?.add(fadeTransition(duration: fadeDuration), forKey: "transition")
        bg = bgColor

        attributedTitle = attributedTitle.withAttribute(.textColor(labelColor))
    }

    func resizeToFitTitle() {
        var width = sizeThatFits(attributedTitle.size()).width + padding
        if maxWidth > 0 {
            width = cap(width, minVal: 0, maxVal: maxWidth)
        }

        let x: CGFloat
        switch origin {
        case .left:
            x = frame.minX
        case .center:
            if width > frame.width {
                x = frame.minX - (width - frame.width) / 2
            } else {
                x = frame.minX + (frame.width - width) / 2
            }
        case .right:
            if width > frame.width {
                x = frame.minX - (width - frame.width)
            } else {
                x = frame.minX + (frame.width - width)
            }
        }

        setFrameOrigin(NSPoint(x: x, y: frame.minY))

        setFrameSize(NSSize(width: width, height: frame.height))
        trackHover()
    }

    func fade(modeKey: AdaptiveModeKey? = nil, overrideMode: Bool? = nil) {
        mainThread {
            guard !isHidden else { return }
            setColors(modeKey: modeKey, overrideMode: overrideMode)
            resizeToFitTitle()
            trackHover()
        }
    }

    func defocus() {
        mainThread {
            guard !isHidden else { return }
            hoverState = .noHover
            setColors()
        }
    }

    func hover() {
        mainThread {
            guard isEnabled, !isHidden else { return }
            hoverState = .hover
            setColors(fadeDuration: 0.1)
        }
    }

    func setup() {
        wantsLayer = true

        setFrameSize(NSSize(width: frame.width, height: frame.height + verticalPadding))
        radius = (frame.height / 2).ns
        allowsMixedState = false
        setColors()
        trackHover()

        selectionPublisher
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.fade() }
            .store(in: &observers)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
}
