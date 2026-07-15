import CoreGraphics
import Foundation
import TensorFlowLite
import UIKit

enum DewarpError: LocalizedError {
    case modelMissing
    case invalidImage
    case invalidTensor(String)
    case renderingFailed

    var errorDescription: String? {
        switch self {
        case .modelMissing:
            return "The bundled dewarp.tflite model could not be found."
        case .invalidImage:
            return "The selected image could not be converted for dewarping."
        case .invalidTensor(let detail):
            return "The DewarpNet tensor layout is unexpected: \(detail)"
        case .renderingFailed:
            return "The corrected image could not be rendered."
        }
    }
}

/// Runs DewarpNet and applies its backward-mapping grid to the source image.
///
/// Model contract:
/// - input:  [1, 3, 256, 256] Float32 NCHW, BGR, values in 0...1
/// - output: [1, 2, 128, 128] Float32 backward map, values near -1...1
actor DewarpService {
    static let shared = DewarpService()

    private let inputSide = 256
    private let gridSide = 128
    private var interpreter: Interpreter?

    func dewarp(_ image: UIImage) throws -> UIImage {
        let source = try PixelImage(image: image)
        let interpreter = try loadInterpreter()
        let input = try makeInput(from: source)

        try interpreter.copy(input, toInputAt: 0)
        try interpreter.invoke()

        let output = try interpreter.output(at: 0)
        let expectedCount = 2 * gridSide * gridSide
        guard output.data.count == expectedCount * MemoryLayout<Float32>.size else {
            throw DewarpError.invalidTensor(
                "expected \(expectedCount) Float32 values, got \(output.data.count) bytes"
            )
        }

        let grid = output.data.withUnsafeBytes {
            Array($0.bindMemory(to: Float32.self))
        }
        let blurred = blurGrid(grid)
        return try render(source: source, grid: blurred, scale: image.scale)
    }

    private func loadInterpreter() throws -> Interpreter {
        if let interpreter {
            return interpreter
        }
        guard let modelPath = Bundle.main.path(forResource: "dewarp", ofType: "tflite") else {
            throw DewarpError.modelMissing
        }

        var options = Interpreter.Options()
        options.threadCount = max(2, min(ProcessInfo.processInfo.activeProcessorCount, 4))
        let created = try Interpreter(modelPath: modelPath, options: options)
        try created.allocateTensors()

        let input = try created.input(at: 0)
        guard input.dataType == .float32,
              input.shape.dimensions == [1, 3, inputSide, inputSide] else {
            throw DewarpError.invalidTensor("input is \(input.shape.dimensions), \(input.dataType)")
        }

        let output = try created.output(at: 0)
        guard output.dataType == .float32,
              output.shape.dimensions == [1, 2, gridSide, gridSide] else {
            throw DewarpError.invalidTensor("output is \(output.shape.dimensions), \(output.dataType)")
        }

        interpreter = created
        return created
    }

    private func makeInput(from source: PixelImage) throws -> Data {
        let small = try source.resized(width: inputSide, height: inputSide)
        let planeSize = inputSide * inputSide
        var values = [Float32](repeating: 0, count: planeSize * 3)

        for index in 0..<planeSize {
            let pixel = index * 4
            values[index] = Float32(small.rgba[pixel + 2]) / 255 // B
            values[planeSize + index] = Float32(small.rgba[pixel + 1]) / 255 // G
            values[(2 * planeSize) + index] = Float32(small.rgba[pixel]) / 255 // R
        }

        return values.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    private func blurGrid(_ grid: [Float32]) -> [Float32] {
        let planeSize = gridSide * gridSide
        var result = grid

        for channel in 0..<2 {
            let offset = channel * planeSize
            for y in 0..<gridSide {
                for x in 0..<gridSide {
                    var sum: Float32 = 0
                    var count: Float32 = 0
                    for dy in -1...1 {
                        let sampleY = y + dy
                        guard sampleY >= 0, sampleY < gridSide else { continue }
                        for dx in -1...1 {
                            let sampleX = x + dx
                            guard sampleX >= 0, sampleX < gridSide else { continue }
                            sum += grid[offset + sampleY * gridSide + sampleX]
                            count += 1
                        }
                    }
                    result[offset + y * gridSide + x] = sum / count
                }
            }
        }
        return result
    }

    private func render(source: PixelImage, grid: [Float32], scale: CGFloat) throws -> UIImage {
        let width = source.width
        let height = source.height
        let planeSize = gridSide * gridSide
        var output = [UInt8](repeating: 0, count: width * height * 4)

        for y in 0..<height {
            let gridY = height > 1
                ? Float32(y) * Float32(gridSide - 1) / Float32(height - 1)
                : 0
            for x in 0..<width {
                let gridX = width > 1
                    ? Float32(x) * Float32(gridSide - 1) / Float32(width - 1)
                    : 0

                let mapX = samplePlane(grid, offset: 0, x: gridX, y: gridY)
                let mapY = samplePlane(grid, offset: planeSize, x: gridX, y: gridY)
                let sourceX = (mapX + 1) * Float32(width - 1) / 2
                let sourceY = (mapY + 1) * Float32(height - 1) / 2
                let destination = (y * width + x) * 4

                guard sourceX >= 0, sourceX <= Float32(width - 1),
                      sourceY >= 0, sourceY <= Float32(height - 1) else {
                    output[destination + 3] = 255
                    continue
                }

                for channel in 0..<3 {
                    output[destination + channel] = samplePixel(
                        source.rgba,
                        width: width,
                        height: height,
                        x: sourceX,
                        y: sourceY,
                        channel: channel
                    )
                }
                output[destination + 3] = 255
            }
        }

        guard let provider = CGDataProvider(data: Data(output) as CFData),
              let cgImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(
                    rawValue: CGImageAlphaInfo.premultipliedLast.rawValue
                        | CGBitmapInfo.byteOrder32Big.rawValue
                ),
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
              ) else {
            throw DewarpError.renderingFailed
        }

        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }

    private func samplePlane(
        _ values: [Float32],
        offset: Int,
        x: Float32,
        y: Float32
    ) -> Float32 {
        let x0 = max(0, min(Int(floor(x)), gridSide - 1))
        let y0 = max(0, min(Int(floor(y)), gridSide - 1))
        let x1 = min(x0 + 1, gridSide - 1)
        let y1 = min(y0 + 1, gridSide - 1)
        let fx = x - Float32(x0)
        let fy = y - Float32(y0)

        let top = values[offset + y0 * gridSide + x0] * (1 - fx)
            + values[offset + y0 * gridSide + x1] * fx
        let bottom = values[offset + y1 * gridSide + x0] * (1 - fx)
            + values[offset + y1 * gridSide + x1] * fx
        return top * (1 - fy) + bottom * fy
    }

    private func samplePixel(
        _ rgba: [UInt8],
        width: Int,
        height: Int,
        x: Float32,
        y: Float32,
        channel: Int
    ) -> UInt8 {
        let x0 = max(0, min(Int(floor(x)), width - 1))
        let y0 = max(0, min(Int(floor(y)), height - 1))
        let x1 = min(x0 + 1, width - 1)
        let y1 = min(y0 + 1, height - 1)
        let fx = x - Float32(x0)
        let fy = y - Float32(y0)

        func value(_ px: Int, _ py: Int) -> Float32 {
            Float32(rgba[(py * width + px) * 4 + channel])
        }

        let top = value(x0, y0) * (1 - fx) + value(x1, y0) * fx
        let bottom = value(x0, y1) * (1 - fx) + value(x1, y1) * fx
        return UInt8(max(0, min(255, (top * (1 - fy) + bottom * fy).rounded())))
    }
}

private struct PixelImage {
    let width: Int
    let height: Int
    let rgba: [UInt8]

    init(image: UIImage) throws {
        guard let cgImage = image.cgImage else {
            throw DewarpError.invalidImage
        }
        self = try PixelImage(cgImage: cgImage)
    }

    init(cgImage: CGImage) throws {
        width = cgImage.width
        height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            throw DewarpError.invalidImage
        }
        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        rgba = pixels
    }

    func resized(width: Int, height: Int) throws -> PixelImage {
        guard let provider = CGDataProvider(data: Data(rgba) as CFData),
              let source = CGImage(
                width: self.width,
                height: self.height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: self.width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(
                    rawValue: CGImageAlphaInfo.premultipliedLast.rawValue
                        | CGBitmapInfo.byteOrder32Big.rawValue
                ),
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
              ) else {
            throw DewarpError.invalidImage
        }

        var resized = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &resized,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            throw DewarpError.invalidImage
        }
        context.interpolationQuality = .high
        context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
        return PixelImage(width: width, height: height, rgba: resized)
    }

    private init(width: Int, height: Int, rgba: [UInt8]) {
        self.width = width
        self.height = height
        self.rgba = rgba
    }
}
