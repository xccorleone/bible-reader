// Renders the bible-reader app icon as 1024×1024 PNGs.
//
// Usage:
//   swift tools/icon/render_icon.swift <output-dir>
//
// Produces:
//   icon-light.png    — full-color light appearance
//   icon-dark.png     — full-color dark appearance
//   icon-tinted.png   — grayscale for iOS tinted mode (system applies tint)

import AppKit
import CoreGraphics
import Foundation

enum Variant {
    case light, dark, tinted
}

struct Palette {
    let backgroundTop: NSColor
    let backgroundBottom: NSColor
    let pageFront: NSColor
    let pageBack: NSColor
    let pageEdge: NSColor
    let spine: NSColor
    let ruleLine: NSColor
    let ribbon: NSColor
    let ribbonShadow: NSColor
    let cross: NSColor

    static func forVariant(_ v: Variant) -> Palette {
        switch v {
        case .light:
            return Palette(
                backgroundTop: NSColor(srgbRed: 0.98, green: 0.88, blue: 0.62, alpha: 1),
                backgroundBottom: NSColor(srgbRed: 0.90, green: 0.66, blue: 0.32, alpha: 1),
                pageFront: NSColor(srgbRed: 0.99, green: 0.97, blue: 0.92, alpha: 1),
                pageBack: NSColor(srgbRed: 0.93, green: 0.88, blue: 0.78, alpha: 1),
                pageEdge: NSColor(srgbRed: 0.72, green: 0.60, blue: 0.40, alpha: 1),
                spine: NSColor(srgbRed: 0.45, green: 0.28, blue: 0.16, alpha: 1),
                ruleLine: NSColor(srgbRed: 0.55, green: 0.42, blue: 0.28, alpha: 0.55),
                ribbon: NSColor(srgbRed: 0.78, green: 0.18, blue: 0.20, alpha: 1),
                ribbonShadow: NSColor(srgbRed: 0.55, green: 0.10, blue: 0.12, alpha: 1),
                cross: NSColor(srgbRed: 0.78, green: 0.55, blue: 0.20, alpha: 1)
            )
        case .dark:
            return Palette(
                backgroundTop: NSColor(srgbRed: 0.10, green: 0.13, blue: 0.22, alpha: 1),
                backgroundBottom: NSColor(srgbRed: 0.04, green: 0.05, blue: 0.10, alpha: 1),
                pageFront: NSColor(srgbRed: 0.95, green: 0.92, blue: 0.84, alpha: 1),
                pageBack: NSColor(srgbRed: 0.80, green: 0.76, blue: 0.66, alpha: 1),
                pageEdge: NSColor(srgbRed: 0.55, green: 0.45, blue: 0.30, alpha: 1),
                spine: NSColor(srgbRed: 0.20, green: 0.16, blue: 0.12, alpha: 1),
                ruleLine: NSColor(srgbRed: 0.40, green: 0.30, blue: 0.20, alpha: 0.55),
                ribbon: NSColor(srgbRed: 0.85, green: 0.22, blue: 0.24, alpha: 1),
                ribbonShadow: NSColor(srgbRed: 0.55, green: 0.10, blue: 0.12, alpha: 1),
                cross: NSColor(srgbRed: 0.95, green: 0.78, blue: 0.40, alpha: 1)
            )
        case .tinted:
            // For iOS tinted mode, the system multiplies our grayscale by the
            // user's chosen tint. Background stays dark; foreground is light.
            return Palette(
                backgroundTop: NSColor(white: 0.10, alpha: 1),
                backgroundBottom: NSColor(white: 0.02, alpha: 1),
                pageFront: NSColor(white: 0.92, alpha: 1),
                pageBack: NSColor(white: 0.72, alpha: 1),
                pageEdge: NSColor(white: 0.50, alpha: 1),
                spine: NSColor(white: 0.30, alpha: 1),
                ruleLine: NSColor(white: 0.45, alpha: 0.6),
                ribbon: NSColor(white: 0.85, alpha: 1),
                ribbonShadow: NSColor(white: 0.55, alpha: 1),
                cross: NSColor(white: 1.00, alpha: 1)
            )
        }
    }
}

func renderIcon(size: CGFloat, palette: Palette) -> CGImage {
    let pixel = Int(size)
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(
        data: nil,
        width: pixel,
        height: pixel,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!

    // Background gradient (top → bottom). CG origin is bottom-left, so
    // start the gradient at the top of the canvas.
    let bgGradient = CGGradient(
        colorsSpace: cs,
        colors: [palette.backgroundTop.cgColor, palette.backgroundBottom.cgColor] as CFArray,
        locations: [0.0, 1.0]
    )!
    ctx.drawLinearGradient(
        bgGradient,
        start: CGPoint(x: 0, y: size),
        end: CGPoint(x: 0, y: 0),
        options: []
    )

    // Geometry — center book, leave generous icon-grid padding.
    let bookW = size * 0.68
    let bookH = size * 0.50
    let bookX = (size - bookW) / 2
    let bookY = (size - bookH) / 2 - size * 0.02
    let spineX = size / 2

    // Soft drop-shadow behind the book.
    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -size * 0.012),
        blur: size * 0.05,
        color: NSColor(white: 0, alpha: 0.35).cgColor
    )

    // Back pages (a slightly wider shape behind the front pages, for depth).
    let backInset = size * 0.018
    let backRect = CGRect(
        x: bookX - backInset,
        y: bookY - backInset,
        width: bookW + backInset * 2,
        height: bookH + backInset
    )
    let backPath = CGPath(
        roundedRect: backRect,
        cornerWidth: size * 0.025,
        cornerHeight: size * 0.025,
        transform: nil
    )
    ctx.addPath(backPath)
    ctx.setFillColor(palette.pageEdge.cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    // Front pages — two leaves meeting at the spine, top edge gently curved.
    let leftLeaf = CGMutablePath()
    let topLift = size * 0.018
    leftLeaf.move(to: CGPoint(x: bookX, y: bookY))
    leftLeaf.addLine(to: CGPoint(x: bookX, y: bookY + bookH - topLift))
    leftLeaf.addQuadCurve(
        to: CGPoint(x: spineX, y: bookY + bookH),
        control: CGPoint(x: bookX + bookW * 0.18, y: bookY + bookH + topLift * 0.5)
    )
    leftLeaf.addLine(to: CGPoint(x: spineX, y: bookY))
    leftLeaf.closeSubpath()

    let rightLeaf = CGMutablePath()
    rightLeaf.move(to: CGPoint(x: spineX, y: bookY))
    rightLeaf.addLine(to: CGPoint(x: spineX, y: bookY + bookH))
    rightLeaf.addQuadCurve(
        to: CGPoint(x: bookX + bookW, y: bookY + bookH - topLift),
        control: CGPoint(x: bookX + bookW * 0.82, y: bookY + bookH + topLift * 0.5)
    )
    rightLeaf.addLine(to: CGPoint(x: bookX + bookW, y: bookY))
    rightLeaf.closeSubpath()

    ctx.setFillColor(palette.pageFront.cgColor)
    ctx.addPath(leftLeaf)
    ctx.fillPath()
    ctx.addPath(rightLeaf)
    ctx.fillPath()

    // Subtle page back tone behind the gutter to suggest depth at the spine.
    let gutter = CGRect(
        x: spineX - size * 0.012,
        y: bookY,
        width: size * 0.024,
        height: bookH
    )
    ctx.setFillColor(palette.pageBack.cgColor)
    ctx.fill(gutter)

    // Verse rule lines on each page.
    ctx.setStrokeColor(palette.ruleLine.cgColor)
    ctx.setLineWidth(size * 0.006)
    ctx.setLineCap(.round)
    let textTop = bookY + bookH * 0.78
    let textBottom = bookY + bookH * 0.22
    let lineCount = 6
    let lineSpacing = (textTop - textBottom) / CGFloat(lineCount - 1)
    let leftLineStart = bookX + bookW * 0.08
    let leftLineEnd = spineX - bookW * 0.06
    let rightLineStart = spineX + bookW * 0.06
    let rightLineEnd = bookX + bookW * 0.92
    for i in 0..<lineCount {
        let y = textTop - CGFloat(i) * lineSpacing
        // Vary line lengths a little so it reads as text, not a grid.
        let leftShorten = (i == 2) ? bookW * 0.18 : (i == 5 ? bookW * 0.10 : 0)
        let rightShorten = (i == 1) ? bookW * 0.14 : (i == 4 ? bookW * 0.22 : 0)
        ctx.move(to: CGPoint(x: leftLineStart, y: y))
        ctx.addLine(to: CGPoint(x: leftLineEnd - leftShorten, y: y))
        ctx.strokePath()
        ctx.move(to: CGPoint(x: rightLineStart, y: y))
        ctx.addLine(to: CGPoint(x: rightLineEnd - rightShorten, y: y))
        ctx.strokePath()
    }

    // Small cross above the spine on the front-page top, centered.
    let crossCenterX = spineX
    let crossCenterY = bookY + bookH * 0.90
    let crossArm = size * 0.022
    let crossThick = size * 0.012
    ctx.setFillColor(palette.cross.cgColor)
    let vertical = CGRect(
        x: crossCenterX - crossThick / 2,
        y: crossCenterY - crossArm,
        width: crossThick,
        height: crossArm * 2
    )
    let horizontal = CGRect(
        x: crossCenterX - crossArm * 0.75,
        y: crossCenterY - crossThick / 2 + crossArm * 0.25,
        width: crossArm * 1.5,
        height: crossThick
    )
    ctx.fill(vertical)
    ctx.fill(horizontal)

    // Ribbon bookmark — drops from the top of the right page, with a notched tail.
    let ribbonX = bookX + bookW * 0.74
    let ribbonW = size * 0.055
    let ribbonTop = bookY + bookH - size * 0.005
    let ribbonBottom = bookY - size * 0.075
    let ribbonNotch = size * 0.030
    let ribbon = CGMutablePath()
    ribbon.move(to: CGPoint(x: ribbonX, y: ribbonTop))
    ribbon.addLine(to: CGPoint(x: ribbonX, y: ribbonBottom))
    ribbon.addLine(to: CGPoint(x: ribbonX + ribbonW / 2, y: ribbonBottom + ribbonNotch))
    ribbon.addLine(to: CGPoint(x: ribbonX + ribbonW, y: ribbonBottom))
    ribbon.addLine(to: CGPoint(x: ribbonX + ribbonW, y: ribbonTop))
    ribbon.closeSubpath()
    ctx.setFillColor(palette.ribbon.cgColor)
    ctx.addPath(ribbon)
    ctx.fillPath()

    // Ribbon shadow strip along its left edge for a little dimension.
    let ribbonShadow = CGRect(
        x: ribbonX,
        y: ribbonBottom,
        width: ribbonW * 0.30,
        height: ribbonTop - ribbonBottom
    )
    ctx.setFillColor(palette.ribbonShadow.cgColor)
    ctx.fill(ribbonShadow)

    // Spine highlight — a slim darker stripe in the gutter for separation.
    ctx.setFillColor(palette.spine.cgColor)
    let spineRect = CGRect(
        x: spineX - size * 0.003,
        y: bookY,
        width: size * 0.006,
        height: bookH
    )
    ctx.fill(spineRect)

    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) throws {
    let rep = NSBitmapImageRep(cgImage: image)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "render_icon", code: 1)
    }
    try data.write(to: url)
}

// ── main ───────────────────────────────────────────────────────────────────
let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write(Data("usage: render_icon <output-dir>\n".utf8))
    exit(2)
}
let outDir = URL(fileURLWithPath: args[1], isDirectory: true)
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let variants: [(String, Variant)] = [
    ("icon-light.png", .light),
    ("icon-dark.png", .dark),
    ("icon-tinted.png", .tinted),
]
for (name, variant) in variants {
    let image = renderIcon(size: 1024, palette: Palette.forVariant(variant))
    try writePNG(image, to: outDir.appendingPathComponent(name))
    print("wrote \(name)")
}
