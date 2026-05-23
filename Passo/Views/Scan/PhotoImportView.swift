import SwiftUI
import PhotosUI
import Vision

// MARK: - Photo Import View

/// Pick an image from the photo library, detect barcodes + OCR, then confirm.
struct PhotoImportView: View {
    @Environment(\.dismiss)      private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedItem: PhotosPickerItem?
    @State private var phase: Phase = .picking
    @State private var detectedTicket: Ticket?

    private enum Phase {
        case picking
        case analyzing
        case failed(String)
        case confirmed
    }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .picking:
                    pickerBody

                case .analyzing:
                    analyzingOverlay

                case .failed(let msg):
                    failedView(message: msg)

                case .confirmed:
                    EmptyView()
                }
            }
            .navigationTitle("从相册导入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .sheet(item: $detectedTicket) { ticket in
                RecognitionConfirmView(ticket: ticket)
                    .onDisappear { dismiss() }
            }
        }
    }

    // MARK: Picker Body

    private var pickerBody: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 72, weight: .ultraLight))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("选择票据截图")
                    .font(.system(size: 20, weight: .semibold))
                Text("支持电影票、火车票、演出票等各类截图")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            PhotosPicker(
                selection: $selectedItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label("打开相册", systemImage: "photo.badge.plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(height: 52)
                    .frame(maxWidth: 220)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 32)
        .onChange(of: selectedItem) { _, item in
            guard let item else { return }
            Task { await analyze(item: item) }
        }
    }

    // MARK: Analyzing Overlay

    private var analyzingOverlay: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.4)
            Text("正在识别票据信息…")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: Failed View

    private func failedView(message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(.orange)

            VStack(spacing: 8) {
                Text("识别失败")
                    .font(.system(size: 18, weight: .semibold))
                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("重新选择图片") {
                selectedItem = nil
                phase = .picking
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(.white)
            .frame(height: 50)
            .frame(maxWidth: 200)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: Analysis Pipeline

    private func analyze(item: PhotosPickerItem) async {
        phase = .analyzing

        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data),
              let cgImage = uiImage.cgImage
        else {
            phase = .failed("无法读取图片，请重试")
            return
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        // Run barcode detection + OCR in a single pass
        let barcodeReq = VNDetectBarcodesRequest()
        barcodeReq.symbologies = [.qr, .dataMatrix, .aztec, .code128, .ean13, .itf14, .code39]

        let ocrReq = VNRecognizeTextRequest()
        ocrReq.recognitionLevel = .accurate
        ocrReq.recognitionLanguages = ["zh-Hans", "en-US"]
        ocrReq.usesLanguageCorrection = true

        do {
            try handler.perform([barcodeReq, ocrReq])
        } catch {
            phase = .failed("图像分析失败：\(error.localizedDescription)")
            return
        }

        let barcodeValue = (barcodeReq.results?.first as? VNBarcodeObservation)?.payloadStringValue ?? ""
        let barcodeFormat = formatString(for: barcodeReq.results?.first as? VNBarcodeObservation)
        let ocrText = (ocrReq.results as? [VNRecognizedTextObservation] ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: " ")

        if barcodeValue.isEmpty && ocrText.isEmpty {
            phase = .failed("未在图片中检测到票据信息，请确认图片包含条码或二维码")
            return
        }

        let ticket = TicketParser.parse(barcodeValue: barcodeValue, ocrText: ocrText)
        ticket.barcodeFormat = barcodeFormat

        // Capture thumbnail from selected image
        ticket.thumbnailData = await thumbnailData(from: uiImage)

        phase = .confirmed
        detectedTicket = ticket
    }

    private func formatString(for obs: VNBarcodeObservation?) -> String {
        guard let obs else { return "QR" }
        switch obs.symbology {
        case .qr:         return "QR"
        case .code128:    return "Code128"
        case .ean13:      return "EAN13"
        case .ean8:       return "EAN8"
        case .dataMatrix: return "DataMatrix"
        case .aztec:      return "Aztec"
        case .itf14:      return "ITF14"
        case .code39:     return "Code39"
        default:          return "QR"
        }
    }

    private func thumbnailData(from image: UIImage) async -> Data? {
        await Task.detached(priority: .utility) {
            // Preserve aspect ratio — max 400pt on the longer edge
            let maxSide: CGFloat = 400
            let scale = min(maxSide / image.size.width, maxSide / image.size.height)
            let targetSize = CGSize(
                width:  image.size.width  * scale,
                height: image.size.height * scale
            )
            return image.preparingThumbnail(of: targetSize)?.jpegData(compressionQuality: 0.75)
        }.value
    }
}
