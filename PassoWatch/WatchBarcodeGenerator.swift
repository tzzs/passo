import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

/// Generates a scannable barcode on the wrist from a ticket's `barcodeValue` /
/// `barcodeFormat`, entirely on-device with Core Image.
///
/// watchOS has no UIKit, so unlike the iOS `BarcodeImageView` this renders to a
/// `CGImage` and wraps it in a SwiftUI `Image(decorative:scale:)`. Two formats
/// are handled: QR (`CIFilter.qrCodeGenerator`) for matrix codes and Code128
/// (`CIFilter.code128BarcodeGenerator`) for everything linear — matching the
/// formats the iOS card view supports.
enum WatchBarcodeGenerator {

    /// Matrix formats render square; linear formats render as a wide strip.
    static func isLinear(_ format: String) -> Bool {
        format != "QR" && format != "DataMatrix" && format != "Aztec"
    }

    static func makeImage(value: String, format: String) -> Image? {
        guard !value.isEmpty, let cg = makeCGImage(value: value, format: format) else { return nil }
        return Image(decorative: cg, scale: 1)
    }

    private static func makeCGImage(value: String, format: String) -> CGImage? {
        let data = value.data(using: .utf8) ?? Data()
        let context = CIContext()

        let output: CIImage?
        let scale: CGFloat
        if format == "QR" || format == "DataMatrix" || format == "Aztec" {
            let filter = CIFilter.qrCodeGenerator()
            filter.message = data
            filter.correctionLevel = "M"
            output = filter.outputImage
            scale = 10
        } else {
            let filter = CIFilter.code128BarcodeGenerator()
            filter.message = data
            filter.quietSpace = 4
            output = filter.outputImage
            scale = 3
        }

        guard let ciImage = output else { return nil }
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        return context.createCGImage(scaled, from: scaled.extent)
    }
}
