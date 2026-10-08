// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
import AppKit
import Combine
import SwiftUI

/// Borrows the lock icon in the existing island without owning its window,
/// music or activity sources. An independent indicator is used only when that
/// surface is unavailable. Neither presentation ever takes input focus.
@MainActor
final class FaceUnlockOverlay {
    private var panel: NotchLockScreenPanel?
    private var space: NotchOverlaySpace?
    private let model = NotchLockScreenModel()
    private var islandService: NotchLockScreenService?
    private var islandSubscription: AnyCancellable?
    private var screenObserver: NSObjectProtocol?
    private var active = false
    private var phase = FaceUnlockIndicatorPhase.scanning

    func show() {
        hide()
        guard FaceUnlockSession.isLockedForCurrentUser else { return }
        active = true
        phase = .scanning
        if NotchSupport.isEnabled() {
            let service = NotchLockScreenService.shared
            islandService = service
            // Reconnect if the host creates its surface after this scan starts,
            // or replaces it as a display is attached or rearranged.
            islandSubscription = service.$hasIsland.receive(on: DispatchQueue.main).sink { [weak self] _ in
                MainActor.assumeIsolated { self?.refreshRoute() }
            }
        }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.closeFallback()
                self?.refreshRoute()
            }
        }
        refreshRoute()
    }

    func update(_ phase: FaceUnlockIndicatorPhase) {
        self.phase = phase
        refreshRoute()
    }

    func hide() {
        active = false
        islandSubscription = nil
        islandService?.setFaceUnlockPhase(nil)
        islandService = nil
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        screenObserver = nil
        model.faceUnlockPhase = nil
        closeFallback()
    }

    private func refreshRoute() {
        let route = FaceUnlockIndicatorRoute.resolve(
            active: active, locked: FaceUnlockSession.isLockedForCurrentUser,
            islandEnabled: NotchSupport.isEnabled(), islandVisible: islandService?.hasIsland == true)
        switch route {
        case .hidden:
            hide()
        case .island:
            closeFallback()
            islandService?.setFaceUnlockPhase(phase)
        case .fallback:
            islandService?.setFaceUnlockPhase(nil)
            model.faceUnlockPhase = phase
            if panel == nil { showFallback() }
        }
    }

    private func closeFallback() {
        panel?.orderOut(nil)
        panel = nil
        space?.close()
        space = nil
    }

    private func showFallback() {
        guard let screen = NSScreen.screens.first(where: { $0.notchDisplayID == CGMainDisplayID() }),
              let space = NotchOverlaySpace(absoluteLevel: NotchLockScreenSupport.spaceLevel) else { return }
        var frame: CGRect
        var content: AnyView
        if NotchSupport.isEnabled(), NotchService.shared.geometry.isNotched,
           let surface = NotchLockScreenLayout.islandSurface(
               in: NotchService.shared.geometry.screen,
               cameraWidth: NotchService.shared.geometry.bareCutout.width,
               cameraHeight: NotchService.shared.geometry.bareCutout.height,
               wing: NotchService.shared.geometry.lockScreenMusicGeometry.compactActivityWingWidth) {
            let geometry = NotchService.shared.geometry
            frame = NotchLockScreenLayout.islandFrame(around: surface)
            content = AnyView(NotchLockScreenIsland(
                model: model, size: surface.size, cameraWidth: geometry.bareCutout.width,
                geometry: geometry.lockScreenMusicGeometry, window: frame.size,
                origin: CGPoint(x: surface.minX - frame.minX, y: frame.maxY - surface.maxY)))
        } else {
            let width = min(CGFloat(300), screen.frame.width - 40)
            // With no physical notch, keep the capsule where the configured
            // island rests. With the island off, leave the central clock clear.
            if NotchSupport.isEnabled() {
                let geometry = NotchService.shared.geometry
                frame = geometry.frame(for: CGSize(width: width, height: 44))
                frame.origin.y -= 8
            } else {
                frame = CGRect(x: screen.frame.maxX - width - 20,
                               y: screen.frame.maxY - max(screen.safeAreaInsets.top, 16) - 52,
                               width: width, height: 44)
            }
            content = AnyView(FaceUnlockIndicator(model: model))
        }
        let panel = NotchLockScreenPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                                        backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = true
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.collectionBehavior = NotchPanel.overlayCollectionBehavior
        panel.level = NotchPanel.normalLevel
        let host = NSHostingView(rootView: content)
        host.sizingOptions = []
        panel.contentView = host
        panel.setFrame(frame, display: false)
        space.add(panel)
        self.space = space
        self.panel = panel
        panel.orderFrontRegardless()
    }
}

private struct FaceUnlockIndicator: View {
    @ObservedObject var model: NotchLockScreenModel
    @ObservedObject private var l10n = L10n.shared
    var body: some View {
        HStack(spacing: 10) {
            FaceUnlockIslandSymbol(phase: model.faceUnlockPhase)
            Text(FaceUnlockStrings(l10n.language)[model.faceUnlockPhase?.message ?? .title])
                .font(.system(size: 12, weight: .medium)).lineLimit(2)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16).padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black, in: Capsule())
        .padding(2)
    }
}
