import SwiftUI
import UIKit

struct PatchDetailView: View {
    @ObservedObject var viewModel: AppViewModel
    let itemID: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var replacement: String = ""
    @State private var copied = false

    private var item: PatchItem? {
        viewModel.items.first { $0.id == itemID }
    }

    private var replacementBytes: Int {
        replacement.data(using: .utf8)?.count ?? 0
    }

    private var isValid: Bool {
        guard let item else { return false }
        return replacementBytes <= item.byteLength
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.05, blue: 0.10), Color(red: 0.08, green: 0.03, blue: 0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if let item {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        titleCard(item)
                        originalCard(item)
                        replacementCard(item)
                        actionButtons(item)
                    }
                    .padding(18)
                }
            } else {
                Text("العنصر غير موجود")
                    .foregroundStyle(.white)
            }
        }
        .navigationTitle("تعديل العنصر")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if replacement.isEmpty {
                replacement = item?.replacement ?? ""
            }
        }
    }

    private func titleCard(_ item: PatchItem) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: item.kind.icon)
                        .font(.title2)
                        .foregroundStyle(.cyan)
                        .frame(width: 46, height: 46)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 15, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.kind.rawValue)
                            .font(.headline)
                        Text(item.detail)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.65))
                    }

                    Spacer()
                }

                HStack(spacing: 10) {
                    infoBadge(title: "Offset", value: item.offsetHex)
                    infoBadge(title: "Original", value: "\(item.byteLength) bytes")
                    infoBadge(title: "New", value: "\(replacementBytes) bytes")
                }
            }
        }
    }

    private func originalCard(_ item: PatchItem) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("النص الأصلي")
                        .font(.headline)
                    Spacer()
                    Button {
                        UIPasteboard.general.string = item.original
                        copied = true
                    } label: {
                        Label(copied ? "تم النسخ" : "نسخ", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .font(.caption.bold())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.cyan)
                }

                Text(item.original)
                    .font(.system(.subheadline, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private func replacementCard(_ item: PatchItem) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("التعديل الجديد")
                        .font(.headline)
                    Spacer()
                    Text("\(replacementBytes)/\(item.byteLength)")
                        .font(.caption.monospaced().bold())
                        .foregroundStyle(isValid ? .white.opacity(0.72) : .orange)
                }

                TextEditor(text: $replacement)
                    .font(.system(.subheadline, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .frame(minHeight: 150)
                    .background(.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(isValid ? .white.opacity(0.12) : .orange.opacity(0.65), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 7) {
                    if isValid {
                        Text("مقبول. المتبقي \(max(0, item.byteLength - replacementBytes)) bytes راح ينملئ بـ 0x00 إذا النص أقصر.")
                            .foregroundStyle(.green.opacity(0.88))
                    } else {
                        Text("غير مقبول: النص الجديد أطول من الأصلي. قصّره حتى يصير \(item.byteLength) bytes أو أقل.")
                            .foregroundStyle(.orange)
                    }

                    Text("الحساب هنا بالـ UTF-8 bytes، لذلك الحروف العربية تأخذ أكثر من byte واحد.")
                        .foregroundStyle(.white.opacity(0.58))
                }
                .font(.caption)
            }
        }
    }

    private func actionButtons(_ item: PatchItem) -> some View {
        VStack(spacing: 10) {
            PrimaryGradientButton(title: "حفظ التعديل", icon: "checkmark.seal.fill") {
                viewModel.updateReplacement(for: item.id, replacement: replacement)
                dismiss()
            }
            .disabled(!isValid)
            .opacity(isValid ? 1 : 0.45)

            HStack(spacing: 10) {
                Button {
                    replacement = item.original
                    viewModel.resetReplacement(for: item.id)
                } label: {
                    Label("إرجاع الأصل", systemImage: "arrow.uturn.backward")
                        .font(.footnote.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    replacement = ""
                } label: {
                    Label("تفريغ", systemImage: "trash")
                        .font(.footnote.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(.white)
    }

    private func infoBadge(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.55))
            Text(value)
                .font(.caption.monospaced().bold())
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
