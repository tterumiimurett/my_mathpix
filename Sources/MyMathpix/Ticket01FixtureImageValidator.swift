import CoreGraphics
import Foundation
import ImageIO

struct Ticket01FixtureImageValidator {
    struct RGB {
        let red: Int
        let green: Int
        let blue: Int
    }

    struct Result {
        let fixtureMarkersPresent: Bool
        let fixtureCoverageComplete: Bool
        let fixtureContentPresent: Bool
        let guardBandAbsent: Bool
    }

    static let markerColors = [
        RGB(red: 6, green: 182, blue: 212),
        RGB(red: 168, green: 85, blue: 247),
        RGB(red: 245, green: 158, blue: 11),
        RGB(red: 59, green: 130, blue: 246)
    ]
    static let patternColors = [
        RGB(red: 209, green: 250, blue: 229),
        RGB(red: 236, green: 252, blue: 203)
    ]
    private static let guardColor = RGB(red: 244, green: 63, blue: 94)

    static func validate(_ pngData: Data) -> Result {
        guard let source = CGImageSourceCreateWithData(pngData as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              image.width > 0,
              image.height > 0 else {
            return Result(
                fixtureMarkersPresent: false,
                fixtureCoverageComplete: false,
                fixtureContentPresent: false,
                guardBandAbsent: false
            )
        }
        let bytesPerPixel = 4
        let bytesPerRow = image.width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * image.height)
        guard let validationColorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
            data: &pixels,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: validationColorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return Result(
                fixtureMarkersPresent: false,
                fixtureCoverageComplete: false,
                fixtureContentPresent: false,
                guardBandAbsent: false
            )
        }
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))

        let stride = max(1, min(image.width, image.height) / 300)
        var markerMatches = Array(repeating: 0, count: markerColors.count)
        var spatialMarkerMatches = Array(repeating: 0, count: 4)
        var fixturePatternMatches = Array(repeating: 0, count: 9)
        var fixtureInkMatches = Array(repeating: 0, count: 9)
        var guardMatches = 0
        var sampledPixels = 0
        for y in Swift.stride(from: 0, to: image.height, by: stride) {
            for x in Swift.stride(from: 0, to: image.width, by: stride) {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let sample = RGB(
                    red: Int(pixels[offset]),
                    green: Int(pixels[offset + 1]),
                    blue: Int(pixels[offset + 2])
                )
                sampledPixels += 1
                let column = min(2, x * 3 / image.width)
                let row = min(2, y * 3 / image.height)
                let region = row * 3 + column
                for (index, marker) in markerColors.enumerated() where matches(sample, marker, tolerance: 40) {
                    markerMatches[index] += 1
                }
                if isHighlySaturated(sample),
                   let corner = markerCorner(x: x, y: y, width: image.width, height: image.height) {
                    spatialMarkerMatches[corner] += 1
                }
                if patternColors.contains(where: { matches(sample, $0, tolerance: 40) }) {
                    fixturePatternMatches[region] += 1
                }
                if sample.red <= 80, sample.green <= 80, sample.blue <= 80 {
                    fixtureInkMatches[region] += 1
                }
                if isGuardColor(sample) {
                    guardMatches += 1
                }
            }
        }
        let markerThreshold = 4
        let guardThreshold = max(8, sampledPixels / 5_000)
        let exactMarkersPresent = markerMatches.allSatisfy { $0 >= markerThreshold }
        let spatialMarkersPresent = spatialMarkerMatches.allSatisfy { $0 >= markerThreshold }
        return Result(
            fixtureMarkersPresent: exactMarkersPresent || spatialMarkersPresent,
            fixtureCoverageComplete: fixturePatternMatches.allSatisfy { $0 >= 5 },
            fixtureContentPresent: fixtureInkMatches.filter { $0 >= 5 }.count >= 4,
            guardBandAbsent: guardMatches < guardThreshold
        )
    }

    private static func matches(_ lhs: RGB, _ rhs: RGB, tolerance: Int) -> Bool {
        abs(lhs.red - rhs.red) <= tolerance
            && abs(lhs.green - rhs.green) <= tolerance
            && abs(lhs.blue - rhs.blue) <= tolerance
    }

    private static func isHighlySaturated(_ color: RGB) -> Bool {
        let high = max(color.red, color.green, color.blue)
        let low = min(color.red, color.green, color.blue)
        return high >= 140 && high - low >= 80
    }

    private static func isGuardColor(_ color: RGB) -> Bool {
        if matches(color, guardColor, tolerance: 40) { return true }
        return color.red >= 150
            && color.red - color.green >= 95
            && color.red - color.blue >= 95
    }

    private static func markerCorner(
        x: Int,
        y: Int,
        width: Int,
        height: Int
    ) -> Int? {
        let horizontal: Int
        if x >= max(1, width / 40), x < width / 5 {
            horizontal = 0
        } else if x >= width * 4 / 5, x < width - max(1, width / 40) {
            horizontal = 1
        } else {
            return nil
        }

        let vertical: Int
        if y >= max(1, height / 20), y < height * 3 / 10 {
            vertical = 0
        } else if y >= height * 7 / 10, y < height - max(1, height / 20) {
            vertical = 1
        } else {
            return nil
        }
        return vertical * 2 + horizontal
    }
}
