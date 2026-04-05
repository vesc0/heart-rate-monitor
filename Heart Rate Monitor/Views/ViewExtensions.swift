//
//  ViewExtensions.swift
//  Heart Rate Monitor
//

import SwiftUI
import UIKit

private struct AppTopGradientNavigationBarModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    private var topGradient: some View {
        ZStack {
            LinearGradient(
                colors: gradientStops,
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: leadingAccentStops,
                center: .topLeading,
                startRadius: 8,
                endRadius: 210
            )

            RadialGradient(
                colors: trailingAccentStops,
                center: .topTrailing,
                startRadius: 10,
                endRadius: 240
            )
        }
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0.00),
                    .init(color: .black.opacity(0.94), location: 0.22),
                    .init(color: .black.opacity(0.62), location: 0.56),
                    .init(color: .clear, location: 1.00)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .frame(height: 230)
        .offset(y: -10)
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
    }

    private var gradientStops: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.67, green: 0.10, blue: 0.16).opacity(0.90),
                Color(red: 0.86, green: 0.20, blue: 0.30).opacity(0.58),
                Color(red: 1.00, green: 0.52, blue: 0.60).opacity(0.22),
                .clear
            ]
        }

        return [
            Color(red: 0.78, green: 0.08, blue: 0.14).opacity(0.92),
            Color(red: 0.94, green: 0.20, blue: 0.30).opacity(0.62),
            Color(red: 1.00, green: 0.54, blue: 0.60).opacity(0.24),
            .clear
        ]
    }

    private var leadingAccentStops: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 1.00, green: 0.40, blue: 0.48).opacity(0.24),
                .clear
            ]
        }

        return [
            Color(red: 1.00, green: 0.38, blue: 0.45).opacity(0.30),
            .clear
        ]
    }

    private var trailingAccentStops: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 1.00, green: 0.46, blue: 0.54).opacity(0.36),
                .clear
            ]
        }

        return [
            Color(red: 1.00, green: 0.44, blue: 0.50).opacity(0.42),
            .clear
        ]
    }

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                topGradient
            }
            .background {
                AppNavigationBarBehaviorConfigurator()
                    .frame(width: 0, height: 0)
            }
    }
}

private struct AppNavigationBarBehaviorConfigurator: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> NavigationBarBehaviorViewController {
        NavigationBarBehaviorViewController()
    }

    func updateUIViewController(_ uiViewController: NavigationBarBehaviorViewController, context: Context) {
        DispatchQueue.main.async {
            uiViewController.applyBehaviorIfPossible()
        }
    }
}

private final class NavigationBarBehaviorViewController: UIViewController {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyBehaviorIfPossible()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        applyBehaviorIfPossible()
    }

    func applyBehaviorIfPossible() {
        guard let navigationBar = navigationController?.navigationBar else {
            return
        }

        let textAttributes: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.label]

        let scrollEdge = UINavigationBarAppearance()
        scrollEdge.configureWithTransparentBackground()
        scrollEdge.shadowColor = .clear
        scrollEdge.titleTextAttributes = textAttributes
        scrollEdge.largeTitleTextAttributes = textAttributes

        let standard = UINavigationBarAppearance()
        standard.configureWithDefaultBackground()
        standard.shadowColor = .clear
        standard.titleTextAttributes = textAttributes
        standard.largeTitleTextAttributes = textAttributes

        navigationBar.prefersLargeTitles = true
        navigationBar.tintColor = .label
        navigationBar.scrollEdgeAppearance = scrollEdge
        navigationBar.standardAppearance = standard
        navigationBar.compactAppearance = standard
        if #available(iOS 15.0, *) {
            navigationBar.compactScrollEdgeAppearance = standard
        }
    }
}

extension View {
    // Conditionally applies a transform to a view.
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, @ViewBuilder then transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    func appTopGradientNavigationBar() -> some View {
        modifier(AppTopGradientNavigationBarModifier())
    }
}
