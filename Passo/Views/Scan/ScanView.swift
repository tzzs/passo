import SwiftUI
import AVFoundation

// MARK: - Scan View

/// Full-screen camera + split-view scan result sheet.
/// Design reference: HiFiScan in hifi-screens.jsx
struct ScanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @StateObject private var camera = CameraService()

    @State private var isFlashOn = false
    @State private var scanLineOffset: CGFloat = -60
    @State private var detectedTicket: Ticket?
    @State private var showConfirmSheet = false

    // The theme used for scan-frame accent color — updates when a ticket is detected
    private var scanAccent: Color {
        detectedTicket?.ticketType.theme.accent ?? TicketType.movie.theme.accent
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Camera + result sheet fill from physical top edge
            VStack(spacing: 0) {
                cameraRegion
                if detectedTicket != nil {
                    resultSheet
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .ignoresSafeArea(edges: .top)

            // iOS-standard top bar — floats over camera, safe area respected automatically
            VStack(spacing: 6) {
                HStack {
                    closeButton
                    Spacer()
                    flashButton
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, 8)

                if detectedTicket != nil {
                    detectedBadge
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                }

                Spacer()
            }
        }
        .statusBarHidden()
        // Sheet bound to showConfirmSheet so dismiss works independently from detectedTicket.
        // onDismiss: if the ticket was persisted (storeIdentifier non-nil), auto-dismiss ScanView.
        .sheet(isPresented: $showConfirmSheet, onDismiss: {
            if detectedTicket?.persistentModelID.storeIdentifier != nil {
                dismiss()
            }
        }) {
            if let ticket = detectedTicket {
                RecognitionConfirmView(ticket: ticket)
            }
        }
        .onAppear {
            camera.requestPermissionAndStart()
            startScanAnimation()
        }
        .onDisappear {
            camera.stop()
        }
        .onChange(of: camera.detectedBarcode) { _, result in
            guard let result, detectedTicket == nil else { return }
            let ticket = TicketParser.parse(barcodeValue: result.value, ocrText: camera.latestOCRText)
            ticket.barcodeFormat = result.format
            ticket.sourceApp = "相机扫描"
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                detectedTicket = ticket
            }
        }
    }

    // MARK: Camera Region

    private var cameraRegion: some View {
        ZStack {
            switch camera.authorizationStatus {
            case .authorized, .notDetermined:
                CameraPreviewView(previewLayer: camera.previewLayer)
            case .denied, .restricted:
                permissionDeniedOverlay
            @unknown default:
                Color.black
            }

            scanFrame
        }
        .frame(maxWidth: .infinity)
        .frame(height: UIScreen.main.bounds.height * 0.52)
    }

    // MARK: Controls

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.12))
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
        }
    }

    private var flashButton: some View {
        Button {
            isFlashOn.toggle()
            camera.setTorch(isFlashOn)
        } label: {
            Image(systemName: isFlashOn ? "bolt.fill" : "bolt")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.12))
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
        }
    }

    private var detectedBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(scanAccent)
                .frame(width: 7, height: 7)
                .shadow(color: scanAccent, radius: 4)
            Text("已检测到票据")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(scanAccent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .background(scanAccent.opacity(0.13))
        .overlay(Capsule().strokeBorder(scanAccent.opacity(0.27), lineWidth: 1))
        .clipShape(Capsule())
        .animation(AppAnimation.themeChange, value: detectedTicket?.ticketType.rawValue)
    }

    private var scanFrame: some View {
        GeometryReader { geo in
            let frameLeft   = geo.size.width  * 0.14
            let frameTop    = geo.size.height * 0.22
            let frameRight  = geo.size.width  * 0.14
            let frameBottom = geo.size.height * 0.14
            let frameWidth  = geo.size.width  - frameLeft - frameRight
            let frameHeight = geo.size.height - frameTop  - frameBottom

            ZStack {
                ScanCornerBrackets(
                    rect: CGRect(x: frameLeft, y: frameTop, width: frameWidth, height: frameHeight),
                    color: scanAccent
                )

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, scanAccent, .clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: frameWidth - 24, height: 2)
                    .shadow(color: scanAccent.opacity(0.6), radius: 6)
                    .position(x: geo.size.width / 2, y: frameTop + frameHeight / 2 + scanLineOffset)
                    .clipped()

                Text("对准条码或二维码")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .position(x: geo.size.width / 2, y: frameTop + frameHeight + 30)
            }
            .animation(AppAnimation.themeChange, value: detectedTicket?.ticketType.rawValue)
        }
    }

    // MARK: Permission Denied

    private var permissionDeniedOverlay: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.slash")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.white.opacity(0.5))
            Text("需要相机权限")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
            Text("前往「设置 → Passo → 相机」开启")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
            Button("打开设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.15))
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }

    // MARK: Result Sheet

    private var resultSheet: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(uiColor: .systemGray4))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 10)

            HStack {
                HStack(spacing: 6) {
                    Circle().fill(Color.green).frame(width: 8, height: 8)
                    Text("识别成功")
                        .font(.system(size: 14, weight: .medium))
                }
                Spacer()
                Button {
                    withAnimation {
                        detectedTicket = nil
                        camera.resetDetection()   // B2: clear lastDetectedValue so same barcode re-triggers
                        startScanAnimation()      // B3: restart scan line
                    }
                } label: {
                    Text("重新扫描")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.bottom, 10)

            if let ticket = detectedTicket {
                TicketCardView(ticket: ticket, size: .full, isDark: false)
                    .padding(.horizontal, AppSpacing.md)
            }

            HStack(spacing: 10) {
                // B1: both buttons now open showConfirmSheet which is correctly sheet-bound
                Button {
                    showConfirmSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "wallet.pass.fill")
                        Text("添加到 Wallet")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                }

                Button {
                    showConfirmSheet = true
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 18, weight: .medium))
                        .frame(width: 50, height: 50)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .foregroundStyle(.primary)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 12)
            .padding(.bottom, 40)
        }
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 16, y: -4)
    }

    // MARK: Animation

    private func startScanAnimation() {
        withAnimation(AppAnimation.scanPulse) {
            scanLineOffset = 60
        }
    }
}

// MARK: - Scan Corner Brackets

private struct ScanCornerBrackets: View {
    let rect: CGRect
    let color: Color

    var body: some View {
        let bracketSize: CGFloat = 32
        let strokeWidth: CGFloat = 3

        ZStack {
            Path { p in
                p.move(to: CGPoint(x: rect.minX, y: rect.minY + bracketSize))
                p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
                p.addLine(to: CGPoint(x: rect.minX + bracketSize, y: rect.minY))
            }
            .stroke(color, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
            .shadow(color: color.opacity(0.4), radius: 6)

            Path { p in
                p.move(to: CGPoint(x: rect.maxX - bracketSize, y: rect.minY))
                p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
                p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + bracketSize))
            }
            .stroke(color, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
            .shadow(color: color.opacity(0.4), radius: 6)

            Path { p in
                p.move(to: CGPoint(x: rect.minX, y: rect.maxY - bracketSize))
                p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
                p.addLine(to: CGPoint(x: rect.minX + bracketSize, y: rect.maxY))
            }
            .stroke(color, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
            .shadow(color: color.opacity(0.4), radius: 6)

            Path { p in
                p.move(to: CGPoint(x: rect.maxX - bracketSize, y: rect.maxY))
                p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bracketSize))
            }
            .stroke(color, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
            .shadow(color: color.opacity(0.4), radius: 6)
        }
    }
}

#Preview {
    ScanView()
}
