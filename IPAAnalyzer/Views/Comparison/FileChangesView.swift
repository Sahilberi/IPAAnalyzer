//
//  FileChangesView.swift
//  IPA Bundle Analyzer
//

import SwiftUI

struct FileChangesView: View {
    let result: ComparisonResult
    @EnvironmentObject var viewModel: ComparisonViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar with filters
            HStack {
                TextField("Search...", text: $viewModel.searchText)
                    .textFieldStyle(.roundedBorder)
                
                Picker("Filter", selection: $viewModel.selectedFilter) {
                    Text("All").tag(ComparisonFilter.all)
                    Text("Changes Only").tag(ComparisonFilter.onlyChanges)
                    Text("Large (>1MB)").tag(ComparisonFilter.largeChangesOnly(threshold: 1_000_000))
                }
                .pickerStyle(.segmented)
            }
            .padding()
            
            Divider()
            
            // File changes list
            ScrollView {
                LazyVStack(spacing: 12) {
                    if !viewModel.filteredFileChanges.added.isEmpty {
                        Section {
                            ForEach(viewModel.filteredFileChanges.added) { change in
                                FileChangeRow(change: change)
                            }
                        } header: {
                            Text("Added Files (\(viewModel.filteredFileChanges.added.count))")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    if !viewModel.filteredFileChanges.removed.isEmpty {
                        Section {
                            ForEach(viewModel.filteredFileChanges.removed) { change in
                                FileChangeRow(change: change)
                            }
                        } header: {
                            Text("Removed Files (\(viewModel.filteredFileChanges.removed.count))")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    if !viewModel.filteredFileChanges.modified.isEmpty {
                        Section {
                            ForEach(viewModel.filteredFileChanges.modified) { change in
                                FileChangeRow(change: change)
                            }
                        } header: {
                            Text("Modified Files (\(viewModel.filteredFileChanges.modified.count))")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("File Changes")
    }
}

struct FileChangeRow: View {
    let change: FileChange
    
    var body: some View {
        HStack {
            Image(systemName: change.changeType == .added ? "plus.circle.fill" :
                    change.changeType == .removed ? "minus.circle.fill" : "pencil.circle.fill")
                .foregroundStyle(change.changeType == .added ? .green :
                    change.changeType == .removed ? .red : .orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(change.name)
                    .font(.subheadline)
                Text(change.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if let diff = change.sizeDiff {
                Text("\(diff > 0 ? "+" : "")\(diff.formattedSize)")
                    .font(.caption)
                    .foregroundStyle(diff > 0 ? .red : .green)
                    .monospacedDigit()
            } else if let size = change.newSize ?? change.oldSize {
                Text(size.formattedSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
    }
}