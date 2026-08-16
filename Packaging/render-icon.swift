import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else { fatalError("Expected output PNG path") }
let size = 1024
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else { fatalError("Unable to allocate icon bitmap") }

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
let canvas = NSRect(x: 0, y: 0, width: size, height: size)
NSColor.clear.setFill()
canvas.fill()

let tile = NSBezierPath(roundedRect: NSRect(x: 52, y: 52, width: 920, height: 920), xRadius: 210, yRadius: 210)
NSGradient(starting: NSColor(calibratedRed: 0.09, green: 0.15, blue: 0.23, alpha: 1), ending: NSColor(calibratedRed: 0.03, green: 0.06, blue: 0.10, alpha: 1))!.draw(in: tile, angle: -45)

let ringRect = NSRect(x: 196, y: 196, width: 632, height: 632)
NSColor(calibratedRed: 0.16, green: 0.27, blue: 0.37, alpha: 1).setStroke()
let ring = NSBezierPath(ovalIn: ringRect)
ring.lineWidth = 56
ring.stroke()

let signal = NSBezierPath()
signal.move(to: NSPoint(x: 224, y: 484))
signal.line(to: NSPoint(x: 355, y: 484))
signal.line(to: NSPoint(x: 410, y: 627))
signal.line(to: NSPoint(x: 496, y: 359))
signal.line(to: NSPoint(x: 572, y: 562))
signal.line(to: NSPoint(x: 624, y: 484))
signal.line(to: NSPoint(x: 800, y: 484))
signal.lineWidth = 48
signal.lineCapStyle = .round
signal.lineJoinStyle = .round
NSColor(calibratedRed: 0.20, green: 0.86, blue: 1, alpha: 1).setStroke()
signal.stroke()

NSColor(calibratedRed: 0.27, green: 0.93, blue: 0.67, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 472, y: 472, width: 80, height: 80)).fill()
NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Unable to encode icon PNG") }
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
