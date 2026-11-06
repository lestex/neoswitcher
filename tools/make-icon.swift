import AppKit

// Renders an .iconset of the NeoSwitcher mark: two overlapping keycaps ("A" and "Я") on a
// rounded plate. Run via tools/make-icon.sh, which turns the set into Resources/AppIcon.icns.

let out = CommandLine.arguments[1]
let plateTop = NSColor(srgbRed: 0.33, green: 0.38, blue: 0.95, alpha: 1)     // #5461F2
let plateBottom = NSColor(srgbRed: 0.13, green: 0.15, blue: 0.48, alpha: 1)  // #212679

func keycap(in rect: NSRect, label: String, fill: NSColor, ink: NSColor, size: CGFloat) {
    let radius = rect.width * 0.2
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = size * 0.03
    shadow.shadowOffset = NSSize(width: 0, height: -size * 0.015)
    shadow.set()
    fill.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
    NSGraphicsContext.restoreGraphicsState()

    // Lower lip gives the key some depth.
    let lip = NSBezierPath(roundedRect: rect.insetBy(dx: 0, dy: 0), xRadius: radius, yRadius: radius)
    NSGraphicsContext.saveGraphicsState()
    lip.addClip()
    NSColor.black.withAlphaComponent(0.10).setFill()
    NSRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height * 0.12).fill()
    NSGraphicsContext.restoreGraphicsState()

    let font = NSFont.systemFont(ofSize: rect.height * 0.62, weight: .bold)
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: ink]
    let str = NSAttributedString(string: label, attributes: attrs)
    let s = str.size()
    str.draw(at: NSPoint(x: rect.midX - s.width / 2, y: rect.midY - s.height / 2 + rect.height * 0.03))
}

func icon(size: CGFloat) -> NSImage {
    NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
        let inset = size * 0.098
        let plate = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
        let radius = plate.width * 0.2237
        NSGradient(starting: plateTop, ending: plateBottom)?
            .draw(in: NSBezierPath(roundedRect: plate, xRadius: radius, yRadius: radius), angle: -90)

        let cap = plate.width * 0.42
        let back = NSRect(x: plate.minX + plate.width * 0.14, y: plate.midY - plate.height * 0.03,
                          width: cap, height: cap)
        let front = NSRect(x: plate.maxX - plate.width * 0.14 - cap, y: plate.midY + plate.height * 0.03 - cap,
                           width: cap, height: cap)
        keycap(in: back, label: "A", fill: NSColor(white: 0.86, alpha: 1),
               ink: NSColor(srgbRed: 0.13, green: 0.15, blue: 0.48, alpha: 1), size: size)
        keycap(in: front, label: "Я", fill: .white,
               ink: NSColor(srgbRed: 0.33, green: 0.38, blue: 0.95, alpha: 1), size: size)
        return true
    }
}

for (name, pixels) in [("icon_16x16", 16), ("icon_16x16@2x", 32),
                       ("icon_32x32", 32), ("icon_32x32@2x", 64),
                       ("icon_128x128", 128), ("icon_128x128@2x", 256),
                       ("icon_256x256", 256), ("icon_256x256@2x", 512),
                       ("icon_512x512", 512), ("icon_512x512@2x", 1024)] {
    let image = icon(size: CGFloat(pixels))
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!
        .write(to: URL(fileURLWithPath: "\(out)/\(name).png"))
}
print("wrote \(out)")
