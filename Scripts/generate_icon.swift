// Erzeugt build/AppIcon.icns: Zielscheibe in Bitcoin-Orange auf dunklem Grund.
// Randlos über die volle Fläche, denn macOS legt seine eigene Form darüber.
import AppKit

let orange = NSColor(red: 247 / 255, green: 147 / 255, blue: 26 / 255, alpha: 1)
let gold = NSColor(red: 1.0, green: 0.80, blue: 0.48, alpha: 1)

func render(_ px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    NSGradient(colors: [NSColor(white: 0.17, alpha: 1), NSColor(white: 0.04, alpha: 1)])!
        .draw(in: NSRect(x: 0, y: 0, width: s, height: s), angle: -90)

    func ring(_ radius: CGFloat, _ width: CGFloat, _ color: NSColor) {
        let rect = NSRect(x: s / 2 - radius * s, y: s / 2 - radius * s, width: 2 * radius * s, height: 2 * radius * s)
        let path = NSBezierPath(ovalIn: rect)
        path.lineWidth = width * s
        color.setStroke()
        path.stroke()
    }
    ring(0.34, 0.05, orange)
    ring(0.20, 0.05, gold)
    let dot = NSBezierPath(ovalIn: NSRect(x: s / 2 - 0.07 * s, y: s / 2 - 0.07 * s, width: 0.14 * s, height: 0.14 * s))
    orange.setFill()
    dot.fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let iconset = URL(fileURLWithPath: "build/AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try! render(base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try! render(base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", "build/AppIcon.icns"]
try! p.run()
p.waitUntilExit()
print(p.terminationStatus == 0 ? "build/AppIcon.icns" : "iconutil fehlgeschlagen")
