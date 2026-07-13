import SwiftUI

struct WorkspaceView: View {
    @StateObject private var viewModel = WorkspaceViewModel()
    let spaceID: String
    let spaceName: String
    @State private var showFilePreview: FileItem?

    var body: some View {
        List {
            if viewModel.files.isEmpty {
                Text("No files")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            }
            ForEach(viewModel.files) { file in
                Button(action: { showFilePreview = file }) {
                    HStack {
                        Image(systemName: file.filename.fileIcon())
                            .foregroundColor(.accentTeal)
                        VStack(alignment: .leading) {
                            Text(file.filename).fontWeight(.medium)
                            Text(file.relativePath).font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                    }
                }
                .foregroundColor(.primary)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        Task { await viewModel.deleteFile(filename: file.filename, projectID: spaceID) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle(spaceName)
        .sheet(item: $showFilePreview) { file in
            FilePreviewView(file: file)
        }
        .onAppear { viewModel.loadFiles(projectID: spaceID) }
    }
}

struct FilePreviewView: View {
    let file: FileItem
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.accentTeal)
                Text(file.filename).font(.title2)
                Text(file.relativePath).font(.caption).foregroundColor(.secondary)
                if let url = URL(string: file.url) {
                    Link("Open File", destination: url)
                        .padding()
                }
            }
            .navigationTitle("File Preview")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - String Extension for File Icons
extension String {
    func fileIcon() -> String {
        let ext = (self as NSString).pathExtension.lowercased()
        switch ext {
        case "swift", "py", "js", "ts", "tsx", "jsx", "go", "rs", "rb", "java", "kt", "c", "cpp", "h", "cs":
            return "doc.code"
        case "json", "yaml", "yml", "xml", "toml", "plist":
            return "doc.text"
        case "md", "txt", "rtf":
            return "doc.plaintext"
        case "png", "jpg", "jpeg", "gif", "svg", "webp", "ico":
            return "photo"
        case "pdf":
            return "doc.viewfinder"
        case "zip", "tar", "gz", "bz2", "7z":
            return "doc.zipper"
        case "mp3", "wav", "aac", "flac", "ogg":
            return "music.note"
        case "mp4", "mov", "avi", "mkv":
            return "film"
        case "html", "css", "scss", "less":
            return "globe"
        default:
            return "doc.fill"
        }
    }
}