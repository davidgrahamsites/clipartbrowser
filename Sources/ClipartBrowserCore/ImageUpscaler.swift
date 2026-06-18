import Accelerate.vImage
import AppKit
import CoreImage
import Foundation

/// Image resizing techniques ported from the NSHipster Image-Resizing-Example
/// (https://github.com/NSHipster/Image-Resizing-Example). The originals are
/// UIKit + file-`URL` based; these operate on `Data` (the app's image currency)
/// using AppKit/Core Graphics/Core Image/Accelerate on macOS.
public enum ImageResizeMethod: String, CaseIterable, Identifiable, Sendable {
    case coreImage
    case coreGraphics
    case vImage
    case appKit

    public var id: String { rawValue }

    /// Human-readable label describing what the technique is good for, shown in
    /// the UI instead of the framework name.
    public var displayName: String {
        switch self {
        case .coreImage:
            return "Sharpest detail"
        case .coreGraphics:
            return "Balanced"
        case .vImage:
            return "Fastest"
        case .appKit:
            return "Smoothest"
        }
    }

    /// A one-line hint about the trade-off, for tooltips / preview subtitles.
    public var summary: String {
        switch self {
        case .coreImage:
            return "Crispest edges, best for clipart — slowest"
        case .coreGraphics:
            return "Good all-round quality and speed"
        case .vImage:
            return "Quickest, hardware-accelerated"
        case .appKit:
            return "Softest result, fewest hard edges"
        }
    }

    /// The underlying framework/technique name, for reference in the preview.
    public var technicalName: String {
        switch self {
        case .appKit:
            return "AppKit"
        case .coreGraphics:
            return "Core Graphics"
        case .coreImage:
            return "Core Image (Lanczos)"
        case .vImage:
            return "vImage"
        }
    }
}

public enum ImageUpscaler {
    /// Resizes `data` to `target` pixel dimensions using the chosen technique.
    ///
    /// This is an upscaler: if the target is no larger than the source, the
    /// original `data` is returned unchanged. Returns `nil` only when decoding
    /// or rendering fails.
    public static func resized(_ data: Data, to target: CGSize, using method: ImageResizeMethod) -> Data? {
        guard let source = cgImage(from: data) else { return nil }

        let targetWidth = Int(target.width.rounded())
        let targetHeight = Int(target.height.rounded())
        guard targetWidth > 0, targetHeight > 0 else { return data }

        // Upscale-only: don't shrink below the source resolution.
        guard max(targetWidth, targetHeight) > max(source.width, source.height) else {
            return data
        }

        let size = CGSize(width: targetWidth, height: targetHeight)
        let resized: CGImage?
        switch method {
        case .appKit:
            resized = appKitResize(source, to: size)
        case .coreGraphics:
            resized = coreGraphicsResize(source, to: size)
        case .coreImage:
            resized = coreImageResize(source, to: size)
        case .vImage:
            resized = vImageResize(source, to: size)
        }

        guard let resized else { return nil }
        return pngData(from: resized)
    }
}

// MARK: - Techniques

private extension ImageUpscaler {
    /// Mirrors the repo's UIKit / `UIGraphicsImageRenderer` approach using an
    /// `NSBitmapImageRep`-backed `NSGraphicsContext` with high interpolation.
    static func appKitResize(_ image: CGImage, to size: CGSize) -> CGImage? {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }
        rep.size = size

        guard let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        context.cgContext.draw(image, in: CGRect(origin: .zero, size: size))
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()

        return rep.cgImage
    }

    /// Mirrors the repo's Core Graphics approach: a bitmap `CGContext` at the
    /// target size with high interpolation quality.
    static func coreGraphicsResize(_ image: CGImage, to size: CGSize) -> CGImage? {
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(origin: .zero, size: size))
        return context.makeImage()
    }

    /// Mirrors the repo's Core Image approach using `CILanczosScaleTransform`.
    static func coreImageResize(_ image: CGImage, to size: CGSize) -> CGImage? {
        let ciImage = CIImage(cgImage: image)
        let extent = ciImage.extent
        guard extent.height > 0, extent.width > 0 else { return nil }

        let scale = size.height / extent.height
        let aspectRatio = size.width / (extent.width * scale)
        guard scale > 0, !scale.isNaN, !scale.isInfinite,
              aspectRatio > 0, !aspectRatio.isNaN, !aspectRatio.isInfinite,
              let filter = CIFilter(name: "CILanczosScaleTransform")
        else {
            return nil
        }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(scale, forKey: kCIInputScaleKey)
        filter.setValue(aspectRatio, forKey: kCIInputAspectRatioKey)

        guard let output = filter.outputImage,
              let result = ciContext.createCGImage(output, from: output.extent)
        else {
            return nil
        }
        return result
    }

    /// Direct port of the repo's vImage approach using `vImageScale_ARGB8888`.
    static func vImageResize(_ image: CGImage, to size: CGSize) -> CGImage? {
        var format = vImage_CGImageFormat(
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            colorSpace: nil,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.first.rawValue),
            version: 0,
            decode: nil,
            renderingIntent: .defaultIntent
        )

        var error: vImage_Error = kvImageNoError

        var sourceBuffer = vImage_Buffer()
        defer { free(sourceBuffer.data) }
        error = vImageBuffer_InitWithCGImage(&sourceBuffer, &format, nil, image, vImage_Flags(kvImageNoFlags))
        guard error == kvImageNoError else { return nil }

        var destinationBuffer = vImage_Buffer()
        defer { free(destinationBuffer.data) }
        error = vImageBuffer_Init(
            &destinationBuffer,
            vImagePixelCount(size.height),
            vImagePixelCount(size.width),
            format.bitsPerPixel,
            vImage_Flags(kvImageNoFlags)
        )
        guard error == kvImageNoError else { return nil }

        error = vImageScale_ARGB8888(&sourceBuffer, &destinationBuffer, nil, vImage_Flags(kvImageHighQualityResampling))
        guard error == kvImageNoError else { return nil }

        let resized = vImageCreateCGImageFromBuffer(
            &destinationBuffer,
            &format,
            nil,
            nil,
            vImage_Flags(kvImageNoFlags),
            &error
        )
        guard error == kvImageNoError else { return nil }
        return resized?.takeRetainedValue()
    }
}

// MARK: - Helpers

private extension ImageUpscaler {
    static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    static func cgImage(from data: Data) -> CGImage? {
        guard let image = NSImage(data: data) else { return nil }
        return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }

    static func pngData(from image: CGImage) -> Data? {
        NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }
}
