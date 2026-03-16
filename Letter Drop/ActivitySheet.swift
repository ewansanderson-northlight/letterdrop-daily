//
//  ActivitySheet.swift
//  Letter Drop
//
//  Minimal UIViewControllerRepresentable wrapper around UIActivityViewController.
//  Used for both the image score-card share and the challenge text share.
//

import SwiftUI

struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.completionWithItemsHandler = { _, _, _, _ in isPresented = false }
        return vc
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
