import SwiftUI
import PhotosUI
import Vision
import Photos

// MARK: - Screenshot Import View

/// Scans the user's recent screenshots for ticket barcodes.
/// iOS sandbox prevents background screenshot monitoring; this view
/// lets users manually trigger a scan of the last N screenshots.
struct ScreenshotImportView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var permissionStatus: PHAuthorizationStatus = .notDetermined
    @State private var isScanning = false
    @State private var results: [ScreenshotScanResult] = []
    @State private var selectedResult: ScreenshotScanResult?
    @State private var scanComplete = false

    var body: some View {
        List {
            howItWorksSection
            scanSection

            if scanComplete && results.isEmpty {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "rectangle.slash")
                                .font(.system(size: 36, weight: .light))
                                .foregroundStyle(.secondary)
                            Text("未在近期截图中发现票据")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 20)
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)
            }

            if !results.isEmpty {
                resultSection
            }
        }
        .navigationTitle("截图快速导入")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { checkPermission() }
        .sheet(item: $selectedResult) { result in
            RecognitionConfirmView(ticket: result.makeTicket())
        }
    }

    // MARK: Sections

    private var howItWorksSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Label("如何使用", systemImage: "info.circle")
                    .font(.system(size: 14, weight: .medium))
                Text("Passo 将扫描你相册中最近 20 张截图，自动识别其中包含的票据二维码或条形码。授权后点击「立即扫描」开始。")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private var scanSection: some View {
        Section {
            switch permissionStatus {
            case .authorized, .limited:
                Button {
                    Task { await scanRecentScreenshots() }
                } label: {
                    HStack {
                        Label(isScanning ? "扫描中…" : "立即扫描近期截图", systemImage: "rectangle.dashed.badge.record")
                        Spacer()
                        if isScanning { ProgressView() }
                    }
                }
                .disabled(isScanning)

            case .denied, .restricted:
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("需要相册访问权限")
                            .font(.system(size: 14, weight: .medium))
                        Text("请在系统设置中允许 Passo 访问你的相册")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("去设置") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.system(size: 13))
                }

            default:
                Button("授权访问相册") {
                    Task { await requestPermission() }
                }
            }
        } footer: {
            Text("仅扫描截图类型的图片，不会访问其他照片内容")
                .font(.caption)
        }
    }

    private var resultSection: some View {
        Section("发现 \(results.count) 张票据") {
            ForEach(results) { (result: ScreenshotScanResult) in
                Button {
                    selectedResult = result
                } label: {
                    HStack(spacing: 12) {
                        if let data = result.thumbnailData, let image = UIImage(data: data) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 52, height: 52)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(uiColor: .secondarySystemBackground))
                                .frame(width: 52, height: 52)
                                .overlay(
                                    Image(systemName: result.ticketType.iconName)
                                        .foregroundStyle(.secondary)
                                )
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(result.title.isEmpty ? "未识别到标题" : result.title)
                                .font(.system(size: 15, weight: .medium))
                                .lineLimit(1)
                            Text(result.ticketType.displayName + "  ·  " + result.barcodeFormat)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
    }

    // MARK: - Logic

    private func checkPermission() {
        permissionStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    private func requestPermission() async {
        permissionStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    private func scanRecentScreenshots() async {
        isScanning = true
        results = []
        scanComplete = false

        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(
            format: "mediaSubtype & %d != 0",
            PHAssetMediaSubtype.photoScreenshot.rawValue
        )
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 20

        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        var found: [ScreenshotScanResult] = []

        for i in 0..<assets.count {
            let asset = assets[i]
            if let result = await analyzeAsset(asset) {
                found.append(result)
            }
        }

        results = found
        isScanning = false
        scanComplete = true
    }

    private func analyzeAsset(_ asset: PHAsset) async -> ScreenshotScanResult? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isSynchronous = false
            options.isNetworkAccessAllowed = false

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 800, height: 800),
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                guard let image, let cgImage = image.cgImage else {
                    continuation.resume(returning: nil)
                    return
                }

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                let barcodeReq = VNDetectBarcodesRequest()
                barcodeReq.symbologies = [.qr, .dataMatrix, .aztec, .code128, .ean13, .itf14, .code39]

                let ocrReq = VNRecognizeTextRequest()
                ocrReq.recognitionLevel = .fast
                ocrReq.recognitionLanguages = ["zh-Hans", "en-US"]
                ocrReq.usesLanguageCorrection = false

                try? handler.perform([barcodeReq, ocrReq])

                let barcodeValue = (barcodeReq.results?.first as? VNBarcodeObservation)?.payloadStringValue ?? ""
                let ocrText = (ocrReq.results ?? [])
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: " ")

                guard !barcodeValue.isEmpty || ocrText.count > 20 else {
                    continuation.resume(returning: nil)
                    return
                }

                let ticket = TicketParser.parse(barcodeValue: barcodeValue, ocrText: ocrText)
                let thumbData = image.preparingThumbnail(
                    of: CGSize(width: 104, height: 104)
                )?.jpegData(compressionQuality: 0.7)

                continuation.resume(returning: ScreenshotScanResult(
                    id: asset.localIdentifier,
                    thumbnailData: thumbData,
                    ticketType: ticket.ticketType,
                    title: ticket.title,
                    barcodeFormat: ticket.barcodeFormat,
                    barcodeValue: barcodeValue
                ))
            }
        }
    }
}

// MARK: - Scan Result Model

struct ScreenshotScanResult: Identifiable {
    let id: String
    let thumbnailData: Data?
    // Plain-value snapshot for display — avoids holding a @Model in a @State array
    let ticketType: TicketType
    let title: String
    let barcodeFormat: String
    // Raw data for lazy Ticket creation when the user taps a result
    let barcodeValue: String

    func makeTicket() -> Ticket {
        let ticket = TicketParser.parse(barcodeValue: barcodeValue, ocrText: "")
        ticket.barcodeFormat = barcodeFormat
        ticket.sourceApp = "截图导入"
        ticket.thumbnailData = thumbnailData
        return ticket
    }
}

// MARK: - TicketType icon name helper

private extension TicketType {
    var iconName: String {
        switch self {
        case .movie:   return "film"
        case .concert: return "music.note"
        case .train:   return "train.side.front.car"
        case .scenic:  return "mountain.2"
        case .member:  return "creditcard"
        case .generic: return "ticket"
        }
    }
}
