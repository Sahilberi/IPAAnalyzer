//
//  FrameworkChangesView.swift
//  IPA Bundle Analyzer
//

import SwiftUI

struct FrameworkChangesView: View {
    let result: ComparisonResult
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if !result.frameworkChanges.added.isEmpty {
                    Section {
                        ForEach(result.frameworkChanges.added) { change in
                            FrameworkChangeCard(change: change)
                        }
                    } header: {
                        Text("Added Frameworks (\(result.frameworkChanges.added.count))")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                if !result.frameworkChanges.removed.isEmpty {
                    Section {
                        ForEach(result.frameworkChanges.removed) { change in
                            FrameworkChangeCard(change: change)
                        }
                    } header: {
                        Text("Removed Frameworks (\(result.frameworkChanges.removed.count))")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                if !result.frameworkChanges.modified.isEmpty {
                    Section {
                        ForEach(result.frameworkChanges.modified) { change in
                            FrameworkChangeCard(change: change)
                        }
                    } header: {
                        Text("Modified Frameworks (\(result.frameworkChanges.modified.count))")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Framework Changes")
    }
}

struct FrameworkChangeCard: View {
    let change: FrameworkChange
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "shippingbox.fill")
                .foregroundStyle(change.changeType == .added ? .green :
                    change.changeType == .removed ? .red : .orange)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(change.name)
                    .font(.headline)
                
                HStack(spacing: 12) {
                    if let oldVersion = change.oldVersion {
                        Text("v\(oldVersion)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    if change.versionChanged, let newVersion = change.newVersion {
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                        Text("v\(newVersion)")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if let diff = change.sizeDiff {
                    Text("\(diff > 0 ? "+" : "")\(diff.formattedSize)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(diff > 0 ? .red : .green)
                        .monospacedDigit()
                }
                
                if let size = change.newSize ?? change.oldSize {
                    Text(size.formattedSize)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}