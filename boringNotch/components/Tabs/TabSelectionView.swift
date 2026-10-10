//
//  TabSelectionView.swift
//  boringNotch
//
//  Created by Hugo Persson on 2024-08-25.
//

import SwiftUI

/// The notch tab bar. Renders every enabled `NotchViews` tab as a full-width
/// strip: Home and Shelf today, tools as they ship. Scrolls horizontally when
/// the enabled tabs outgrow the panel, so no tab is ever clipped.
struct TabSelectionView: View {
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @Namespace var animation

    private var tabs: [NotchViews] {
        NotchViews.allCases.filter(\.isEnabled)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(tabs) { tab in
                    TabButton(label: tab.label, icon: tab.icon, selected: coordinator.currentView == tab) {
                        withAnimation(.smooth) {
                            coordinator.currentView = tab
                        }
                    }
                    .frame(height: 26)
                    .foregroundStyle(tab == coordinator.currentView ? .white : .gray)
                    .background {
                        if tab == coordinator.currentView {
                            Capsule()
                                .fill(Color(nsColor: .secondarySystemFill))
                                .matchedGeometryEffect(id: "capsule", in: animation)
                        } else {
                            Capsule()
                                .fill(Color.clear)
                                .matchedGeometryEffect(id: "capsule", in: animation)
                                .hidden()
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
        }
    }
}

#Preview {
    BoringHeader().environmentObject(BoringViewModel(camera: CameraModel()))
}
