#!/usr/bin/env swift
//
//  build_appicon.swift
//  Loads the master PNG, applies a squircle mask (alpha outside),
//  and writes all sizes the macOS AppIcon.appiconset expects.
//

import AppKit
import CoreGraphics

let sourcePath = "art/icon_master.png"
let outDir = "Hotaru/Hotaru/Assets.xcassets/AppIcon.appiconset"

guard let src = NSImage(contentsOfFile: sourcePath) else {
    print("failed to load \(sourcePath)")
    exit(1)
}

func render(at side: CGFloat) -> NSImage {
    let img = NSImage(size: NSSize(width: side, height: side))
    img.lockFocusFlipped(false)
    let ctx = NSGraphicsContext.current!.cgContext

    // Squircle clip
    let r = side * 0.2237
    let path = CGPath(roundedRect: CGRect(x: 0, y: 0, width: side, height: side),
                      cornerWidth: r, cornerHeight: r, transform: nil)
    ctx.addPath(path)
    ctx.clip()

    // Draw source filled to the canvas (preserving aspect via fitting square)
    src.draw(in: NSRect(x: 0, y: 0, width: side, height: side),
             from: .zero,
             operation: .copy,
             fraction: 1.0)
    img.unlockFocus()
    return img
}

func savePNG(_ image: NSImage, _ name: String) {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let data = rep.representation(using: .png, properties: [:]) else {
        print("encode failed: \(name)"); return
    }
    let url = URL(fileURLWithPath: "\(outDir)/\(name)")
    try? data.write(to: url)
    print("wrote \(url.path)")
}

// (filename, side in px)
let outputs: [(String, CGFloat)] = [
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
    savePNG(render(at: side), name)
}
print("done")
