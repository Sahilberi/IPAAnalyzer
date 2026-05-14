//
//  SizeChangesView.swift
//  IPA Bundle Analyzer
//

import SwiftUI
import Charts

struct SizeChangesView: View {
    let result: ComparisonResult
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Detailed size changes analysis")
                    .font(.title2)
                // Additional implementation would go here
            }
            .padding(24)
        }
        .navigationTitle("Size Changes")
    }
}