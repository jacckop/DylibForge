import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()
    @State private var showImporter = false

    private var dylibContentTypes: [UTType] {
        [UTType(filenameExtension: "dylib") ?? .data, .data, .item]
    }

    private var hasInvalidChanges: Bool {
        viewModel.items.contains { $0.isChanged && !$0.canPatch }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                background
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        header

                        if viewModel.fileURL == nil && !viewModel.isScanning {
                            EmptyStateView { showImporter = true }
                        } else {
                            filePanel
                            statsPanel
                            editorPanel
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 30)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: dylibContentTypes,
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    viewModel.importFile(from: url)
                case .failure(let error):
                    viewModel.banner = error.localizedDescription
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.05, blue: 0.10), Color(red: 0.08, green: 0.03, blue: 0.16), Color(red: 0.01, green: 0.08, blue: 0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(.cyan.opacity(0.20))
                .frame(width: 260, height: 260)
                .blur(radius: 80)
                .offset(x: -120, y: -240)
            Circle()
                .fill(.purple.opacity(0.20))
                .frame(width: 320, height: 320)
                .blur(radius: 100)
                .offset(x: 160, y: 220)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("DylibForge")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("فحص وتعديل نصوص dylib بدون تخريب الباينري")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.68))
                }

                Spacer()

                Button { showImporter = true } label: {
                    Image(systemName: "plus")
                        .font(.headline.bold())
                        .frame(width: 46, height: 46)
                        .background(.white.opacity(0.10), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.16), lineWidth: 1))
                }
                .foregroundStyle(.white)
                .buttonStyle(.plain)
            }

            Text("ملاحظة: أي نص جديد لازم يكون نفس حجم النص الأصلي بالـ bytes أو أقصر. إذا أقصر يتم تعويض الفرق بـ 0x00 تلقائياً.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.58))
        }
    }

    private var filePanel: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "shippingbox.and.arrow.backward.fill")
                        .font(.title2)
                        .foregroundStyle(.cyan)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.fileName.isEmpty ? "لا يوجد ملف" : viewModel.fileName)
                            .font(.headline)
                            .lineLimit(1)
                        Text(viewModel.fileSizeText.isEmpty ? "جاهز للفحص" : viewModel.fileSizeText)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.64))
                    }

                    Spacer()

                    if viewModel.isScanning {
                        ProgressView()
                            .tint(.cyan)
                    }
                }

                if let banner = viewModel.banner {
                    Text(banner)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.white.opacity(0.78))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                HStack(spacing: 10) {
                    Button { showImporter = true } label: {
                        Label("استيراد ملف", systemImage: "folder")
                            .font(.footnote.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button { viewModel.resetAllChanges() } label: {
                        Label("تصفير", systemImage: "arrow.counterclockwise")
                            .font(.footnote.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.stats.changed == 0)
                    .opacity(viewModel.stats.changed == 0 ? 0.45 : 1)
                }
            }
        }
    }

    private var statsPanel: some View {
        let stats = viewModel.stats
        return GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("نتائج الفحص")
                    .font(.headline)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    StatTile(title: "كل العناصر", value: "\(stats.total)", icon: "list.bullet.rectangle")
                    StatTile(title: "روابط", value: "\(stats.urls)", icon: "link")
                    StatTile(title: "عربي", value: "\(stats.arabic)", icon: "character.book.closed")
                    StatTile(title: "تعديلات", value: "\(stats.changed)", icon: "wand.and.stars")
                }
            }
        }
    }

    private var editorPanel: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("العناصر القابلة للتعديل")
                        .font(.headline)
                    Spacer()
                    Text("\(viewModel.filteredItems.count)")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.72))
                }

                searchBox
                filterBar

                if viewModel.filteredItems.isEmpty && !viewModel.isScanning {
                    Text("ماكو نتائج بهذا الفلتر.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.62))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 24)
                } else {
                    VStack(spacing: 10) {
                        ForEach(viewModel.filteredItems) { item in
                            NavigationLink {
                                PatchDetailView(viewModel: viewModel, itemID: item.id)
                            } label: {
                                PatchRow(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(spacing: 10) {
                    PrimaryGradientButton(title: "إنشاء dylib معدل", icon: "square.and.arrow.down") {
                        viewModel.buildPatchedDylib()
                    }
                    .disabled(viewModel.stats.changed == 0 || hasInvalidChanges)
                    .opacity(viewModel.stats.changed == 0 || hasInvalidChanges ? 0.45 : 1)

                    if let exportedURL = viewModel.exportedURL {
                        ShareLink(item: exportedURL) {
                            Label("مشاركة / حفظ الملف الجديد", systemImage: "square.and.arrow.up")
                                .font(.footnote.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    private var searchBox: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.55))
            TextField("ابحث عن رابط، كلمة، offset…", text: $viewModel.searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(.white)
        }
        .padding(12)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "الكل", icon: "sparkles", isSelected: viewModel.selectedKind == nil) {
                    viewModel.selectedKind = nil
                }

                ForEach(PatchKind.allCases) { kind in
                    FilterChip(title: kind.rawValue, icon: kind.icon, isSelected: viewModel.selectedKind == kind) {
                        viewModel.selectedKind = kind
                    }
                }
            }
        }
    }
}

struct PatchRow: View {
    let item: PatchItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.kind.icon)
                .font(.headline)
                .foregroundStyle(item.canPatch ? .cyan : .orange)
                .frame(width: 36, height: 36)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Text(item.kind.rawValue)
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.10), in: Capsule())

                    if item.isChanged {
                        Text(item.canPatch ? "معدل" : "طويل")
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background((item.canPatch ? Color.green : Color.orange).opacity(0.22), in: Capsule())
                    }

                    Spacer()

                    Text(item.offsetHex)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.white.opacity(0.55))
                }

                Text(item.preview)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)

                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(1)

                Text("\(item.replacementByteLength)/\(item.byteLength) bytes")
                    .font(.caption2.monospaced())
                    .foregroundStyle(item.canPatch ? .white.opacity(0.54) : .orange)
            }

            Image(systemName: "chevron.left")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.36))
                .padding(.top, 10)
        }
        .padding(12)
        .background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(item.canPatch ? .white.opacity(0.08) : .orange.opacity(0.35), lineWidth: 1)
        )
    }
}
