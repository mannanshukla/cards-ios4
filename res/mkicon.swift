import AppKit
// App icon: a monochrome white stack of index cards on raspberry.
let a = CommandLine.arguments
func bitmap(_ w: Int, _ h: Int) -> NSBitmapImageRep { return NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)! }
func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor { return NSColor(calibratedRed: r/255, green: g/255, blue: b/255, alpha: 1) }
func icon(_ size: Int, _ path: String) {
    let rep = bitmap(size, size); NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(size), u = s / 100
    let bg0 = rgb(226, 78, 132), bg1 = rgb(170, 36, 88), mid = rgb(196, 54, 108)
    NSGradient(starting: bg0, ending: bg1)!.draw(in: NSRect(x: 0, y: 0, width: s, height: s), angle: -90)
    func card(_ angle: CGFloat, _ dx: CGFloat, _ dy: CGFloat, _ outline: Bool) {
        let t = NSAffineTransform(); t.translateX(by: (50 + dx) * u, yBy: s - (52 + dy) * u); t.rotate(byDegrees: angle)
        let p = NSBezierPath(roundedRect: NSRect(x: -31 * u, y: -21 * u, width: 62 * u, height: 42 * u), xRadius: 5 * u, yRadius: 5 * u); p.transform(using: t as AffineTransform)
        if outline { mid.setFill(); p.fill(); NSColor.white.setStroke(); p.lineWidth = 4.5 * u; p.stroke(); return }
        NSColor(white: 0, alpha: 0.2).setFill(); let sh = p.copy() as! NSBezierPath; let st = NSAffineTransform(); st.translateX(by: 0, yBy: -2 * u); sh.transform(using: st as AffineTransform); sh.fill()
        NSColor.white.setFill(); p.fill()
        // the index card's rule and lines, cut out in the background colour
        for (y, w, h) in [(-11.0, 48.0, 3.2), (-1.0, 40.0, 2.4), (7.0, 40.0, 2.4)] as [(CGFloat, CGFloat, CGFloat)] {
            let l = NSBezierPath(roundedRect: NSRect(x: -w / 2 * u, y: -(y + h / 2) * u, width: w * u, height: h * u), xRadius: h / 2 * u, yRadius: h / 2 * u); l.transform(using: t as AffineTransform); mid.setFill(); l.fill()
        }
    }
    card(14, 3, -6, true); card(-4, 0, 6, false)
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}
icon(57, a[1] + "/Icon.png"); icon(114, a[1] + "/Icon@2x.png"); icon(256, a[1] + "/Icon-preview.png"); print("icon ok")
