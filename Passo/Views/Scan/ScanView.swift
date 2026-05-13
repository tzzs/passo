import SwiftUI
import AVFoundation

// MARK: - Scan View

/// Full-screen camera + split-view scan result sheet.
/// Design reference: HiFiScan in hifi-screens.jsx
struct ScanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var detectedBarcode: String?
    @State private var isFlashOn = false
    @State private var showConfirmSheet = false
    @State private var scanLineOffset: CGFloat = -60
    @State private var detectedTicket: Ticket?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Camera region (top ~52%)
                cameraRegion

                // Bottom result sheet
                if detectedBarcode != nil {
                    resultSheet
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .statusBarHidden()
        .sheet(item: $detectedTicket) { ticket in
            RecognitionConfirmView(ticket: ticket)
        }
        .onAppear { startScanAnimation() }
    }

    // MARK: Camera Region

    private var cameraRegion: some View {
        ZStack {
            // Camera preview placeholder
            // Production: replace with UIViewRepresentable wrapping AVCaptureVideoPreviewLayer
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#0a0a0e"), Color(hex: "#111118")],
                        startPoint: .top, endPoint: .bottom
                    )
                )

            // Noise texture overlay
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: stride(from: 0, to: 20, by: 1).flatMap { _ in
                            [Color.white.opacity(0.03), Color.clear]
                        },
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .opacity(0.06)

            // Top controls
            VStack {
                HStack {
                    closeButton
                    Spacer()
                    flashButton
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, 58)
                Spacer()
            }

            // Detection indicator
            if detectedBarcode != nil {
                VStack {
                    detectedBadge
                        .padding(.top, 102)
                    Spacer()
                }
            }

            // Scan frame
            scanFrame
        }
        .frame(maxWidth: .infinity)
        .frame(height: UIScreen.main.bounds.height * 0.52)
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
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
            // TODO: toggle AVCaptureDevice torch
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
                .fill(TicketType.movie.theme.accent)
                .frame(width: 7, height: 7)
                .shadow(color: TicketType.movie.theme.accent, radius: 4)
            Text("已检测到票据")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(TicketType.movie.theme.accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .background(TicketType.movie.theme.accent.opacity(0.13))
        .overlay(
            Capsule().strokeBorder(TicketType.movie.theme.accent.opacity(0.27), lineWidth: 1)
        )
        .clipShape(Capsule())
    }

    private var scanFrame: some View {
        GeometryReader { geo in
            let frameLeft   = geo.size.width * 0.14
            let frameTop    = geo.size.height * 0.22
            let frameRight  = geo.size.width * 0.14
            let frameBottom = geo.size.height * 0.14
            let frameWidth  = geo.size.width  - frameLeft - frameRight
            let frameHeight = geo.size.height - frameTop  - frameBottom

            ZStack {
                // Corner brackets
                ScanCornerBrackets(
                    rect: CGRect(x: frameLeft, y: frameTop, width: frameWidth, height: frameHeight),
                    color: TicketType.movie.theme.accent
                )

                // Animated scan line
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, TicketType.movie.theme.accent, .clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: frameWidth - 24, height: 2)
                    .shadow(color: TicketType.movie.theme.accent.opacity(0.6), radius: 6)
                    .position(x: geo.size.width / 2, y: frameTop + frameHeight / 2 + scanLineOffset)
                    .clipped()

                // Hint label
                Text("对准条码或二维码")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .position(x: geo.size.width / 2, y: frameTop + frameHeight + 30)
            }
        }
    }

    // MARK: Result Sheet

    private var resultSheet: some View {
        VStack(spacing: 0) {
            // Grabber
            Capsule()
                .fill(Color(uiColor: .systemGray4))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 10)

            // Status
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(Color.green).frame(width: 8, height: 8)
                    Text("识别成功")
                        .font(.system(size: 14, weight: .medium))
                }
                Spacer()
                Text("轻触编辑")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.bottom, 10)

            // Ticket preview
            if let ticket = detectedTicket {
                TicketCardView(ticket: ticket, size: .full, isDark: false)
                    .padding(.horizontal, AppSpacing.md)
            }

            // Action buttons
            HStack(spacing: 10) {
                // Primary: Add to Wallet
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

                // Secondary: Expand
                Button {
                    showConfirmSheet = true
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
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
            // Top-left
            Path { p in
                p.move(to: CGPoint(x: rect.minX, y: rect.minY + bracketSize))
                p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
                p.addLine(to: CGPoint(x: rect.minX + bracketSize, y: rect.minY))
            }
            .stroke(color, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
            .shadow(color: color.opacity(0.4), radius: 6)

            // Top-right
            Path { p in
                p.move(to: CGPoint(x: rect.maxX - bracketSize, y: rect.minY))
                p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
                p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + bracketSize))
            }
            .stroke(color, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
            .shadow(color: color.opacity(0.4), radius: 6)

            // Bottom-left
            Path { p in
                p.move(to: CGPoint(x: rect.minX, y: rect.maxY - bracketSize))
                p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
                p.addLine(to: CGPoint(x: rect.minX + bracketSize, y: rect.maxY))
            }
            .stroke(color, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
            .shadow(color: color.opacity(0.4), radius: 6)

            // Bottom-right
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
