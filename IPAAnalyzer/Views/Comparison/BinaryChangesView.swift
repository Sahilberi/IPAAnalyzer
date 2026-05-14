//
//  BinaryChangesView.swift
//  IPA Bundle Analyzer
//

import SwiftUI

struct BinaryChangesView: View {
    let result: ComparisonResult
    
    var body: some View {
        ScrollView {
            if let changes = result.binaryChanges {
                VStack(alignment: .leading, spacing: 24) {
                    // Size change
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Binary Size Change")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        HStack {
                            Text(result.secondIPA.binaryInfo?.size.formattedSize ?? "N/A")
                            Image(systemName: "arrow.right")
                            Text(result.firstIPA.binaryInfo?.size.formattedSize ?? "N/A")
                            
                            Spacer()
                            
                            Text("\(changes.sizeDiff > 0 ? "+" : "")\(changes.sizeDiff.formattedSize)")
                                .fontWeight(.medium)
                                .foregroundStyle(changes.sizeDiff > 0 ? .red : .green)
                        }
                        .padding()
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(8)
                    }
                    
                    // Architecture changes
                    if !changes.architectureChanges.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Architecture Changes")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            ForEach(changes.architectureChanges) { change in
                                HStack {
                                    Image(systemName: change.changeType == .added ? "plus.circle.fill" : "minus.circle.fill")
                                        .foregroundStyle(change.changeType == .added ? .green : .red)
                                    Text(change.name)
                                }
                                .padding()
                                .background(Color(nsColor: .controlBackgroundColor))
                                .cornerRadius(8)
                            }
                        }
                    }
                    
                    // Bitcode change
                    if changes.bitcodeChanged {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Bitcode Status Changed")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            HStack {
                                Image(systemName: "bolt.fill")
                                    .foregroundStyle(.orange)
                                Text("Bitcode presence has changed between versions")
                            }
                            .padding()
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(24)
            } else {
                VStack {
                    Text("No binary changes information available")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Binary Changes")
    }
}