import AppKit

let outputPath = CommandLine.arguments[1]
let canvas = NSSize(width: 1024, height: 1024)
let image = NSImage(size: canvas)

image.lockFocus()
guard let context = NSGraphicsContext.current else {
    fatalError("Unable to create graphics context")
}
context.imageInterpolation = .high

NSColor.clear.setFill()
NSRect(origin: .zero, size: canvas).fill()

let iconRect = NSRect(x: 72, y: 72, width: 880, height: 880)
let iconPath = NSBezierPath(roundedRect: iconRect, xRadius: 196, yRadius: 196)
let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.10, green: 0.77, blue: 0.47, alpha: 1),
    NSColor(calibratedRed: 0.02, green: 0.55, blue: 0.34, alpha: 1)
])!
gradient.draw(in: iconPath, angle: -55)

NSColor.white.withAlphaComponent(0.18).setStroke()
iconPath.lineWidth = 12
iconPath.stroke()

let keyRect = NSRect(x: 208, y: 327, width: 608, height: 370)
let keyPath = NSBezierPath(roundedRect: keyRect, xRadius: 92, yRadius: 92)
NSColor.white.withAlphaComponent(0.97).setFill()
keyPath.fill()

let text = "Esc" as NSString
let font = NSFont.systemFont(ofSize: 238, weight: .bold)
let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let attributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor(calibratedRed: 0.02, green: 0.51, blue: 0.32, alpha: 1),
    .paragraphStyle: paragraph
]
let textRect = NSRect(x: keyRect.minX + 20, y: keyRect.midY - 151, width: keyRect.width - 40, height: 302)
text.draw(in: textRect, withAttributes: attributes)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Unable to encode icon")
}
try png.write(to: URL(fileURLWithPath: outputPath))
