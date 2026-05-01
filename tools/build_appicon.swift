#!/usr/bin/env swift
//
//  build_appicon.swift
//  Loads the master PNG, applies a squircle mask (alpha outside),
//  and writes all sizes the macOS AppIcon.appiconset expects.
//
//  Why NSBitmapImageRep instead of NSImage.lockFocus:
//    NSImage.lockFocus uses the screen's backing scale, so on a Retina
//    display a 16x16 NSImage actually paints into a 32x32 buffer and
//    representations() returns a 32x32 PNG. We need exact pixel sizes.
//

import AppKit
import CoreGraphics

let sourcePath = "art/icon_master.png"
let outDir = "Hotaru/Hotaru/Assets.xcassets/AppIcon.appiconset"

guard let src = NSImage(contentsOfFile: sourcePath) else {
    print("failed to load \(sourcePath)")
    exit(1)
}

func render(pixels side: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: side,
        pixelsHigh: side,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    // Force the rep to report its size in points equal to its pixel size,
    // so the source draw() at (0,0,side,side) maps 1:1.
    rep.size = NSSize(width: CGFloat(side), height: CGFloat(side))

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext

    // Squircle clip
    let r = CGFloat(side) * 0.2237
    let path = CGPath(roundedRect: CGRect(x: 0, y: 0, width: CGFloat(side), height: CGFloat(side)),
                      cornerWidth: r, cornerHeight: r, transform: nil)
    ctx.addPath(path)
    ctx.clip()

    src.draw(in: NSRect(x: 0, y: 0, width: CGFloat(side), height: CGFloat(side)),
             from: .zero,
             operation: .copy,
             fraction: 1.0)

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func savePNG(_ rep: NSBitmapImageRep, _ name: String) {
    guard let data = rep.representation(using: .png, properties: [:]) else {
        print("encode failed: \(name)"); return
    }
    let url = URL(fileURLWithPath: "\(outDir)/\(name)")
    try? data.write(to: url)
    print("wrote \(url.path) (\(rep.pixelsWide)x\(rep.pixelsHigh))")
}

// (filename, side in px)
let outputs: [(String, Int)] = [
    ("icon_16x16.png",       16),
    ("icon_16x16@2x.png",    32),
    ("icon_32x32.png",       32),
    ("icon_32x32@2x.png",    64),
    ("icon_128x128.png",     128),
    ("icon_128x128@2x.png",  256),
    ("icon_256x256.png",     256),
    ("icon_256x256@2x.png",  512),
    ("icon_512x512.png",     512),
    ("icon_512x512@2x.png", 1024),
    ("icon_1024.png",       1024),  // for iOS universal slots
]

for (name, side) in outputs {
    savePNG(render(pixels: side), name)
}
print("done")
