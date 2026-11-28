import SwiftUI

struct VoiceMicrophone: View {
    @ObservedObject var viewModel: VoiceSearchViewModel
    let compact: Bool

    private var ring: CGFloat {
        compact ? 112 : 168
    }

    private var problem: Bool {
        viewModel.status == .failed || viewModel.status == .notUnderstood
    }

    private var statusText: String {
        switch viewModel.status {
        case .listening:
            return "LISTENING…"
        case .notUnderstood:
            return "WE HEARD YOU, BUT…"
        case .failed:
            return "VOICE DID NOT WORK"
        case .ready:
            return "TAP TO SPEAK"
        }
    }

    private var message: String {
        switch viewModel.status {
        case .notUnderstood:
            return "We could not find a level, zone or type of spot in “\(viewModel.words)”. Try one of the phrases below."
        case .failed:
            switch viewModel.failure {
            case .noPermission:
                return "ParkWise needs the microphone to search by voice. You can allow it in the settings of the phone, or type your search."
            case .network:
                return "This phone needs internet to recognize voice. Type your search instead; it works with the spots saved on the phone."
            case .noMatch:
                return "We did not hear anything. Tap the microphone and try again."
            default:
                return "Voice search is not available on this phone. Type your search instead."
            }
        default:
            return viewModel.words.isEmpty ? "Say what spot you need" : viewModel.words
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(viewModel.isListening ? Palette.accentSoft : Palette.neutral)
                    .frame(width: ring, height: ring)

                Button {
                    if viewModel.isListening {
                        viewModel.stopListening()
                    } else {
                        viewModel.listen()
                    }
                } label: {
                    Image(systemName: viewModel.isListening ? "stop.fill" : "mic")
                        .font(.system(size: compact ? 28 : 36, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: ring * 0.55, height: ring * 0.55)
                        .background(Circle().fill(Palette.accent))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(viewModel.isListening ? "Stop listening" : "Speak")
            }

            Text(statusText)
                .font(AppFont.overline)
                .tracking(0.6)
                .foregroundStyle(problem ? Palette.amberText : Palette.accent)

            Text(message)
                .font(problem || viewModel.words.isEmpty ? AppFont.body : AppFont.display)
                .foregroundStyle(problem || viewModel.words.isEmpty ? Palette.muted : Palette.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if viewModel.heard.understood {
                VoiceChips(labels: viewModel.heard.chips)
            }
        }
    }
}

struct VoiceChips: View {
    let labels: [String]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                chips
            }
            VStack(spacing: 8) {
                chips
            }
        }
    }

    private var chips: some View {
        ForEach(labels, id: \.self) { label in
            Text(label)
                .font(AppFont.caption)
                .foregroundStyle(Palette.accent)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(Capsule().fill(Palette.accentSoft))
        }
    }
}

struct VoiceDestinationCard: View {
    let building: Building

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Palette.neutral)
                Image(systemName: "building.2")
                    .foregroundStyle(Palette.muted)
                LotPhoto(url: building.photoURL, cache: LotImageCache.buildings, width: 72, height: 72)
            }
            .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 4) {
                SectionLabel(text: "Destination")
                Text(building.name)
                    .font(AppFont.heading1)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .cardStyle()
    }
}

struct VoiceTryCard: View {
    let phrases: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Try saying")
            ForEach(phrases, id: \.self) { phrase in
                Text("“\(phrase)”")
                    .font(AppFont.body)
                    .foregroundStyle(Palette.ink)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(Palette.line, lineWidth: 1)
        )
    }
}

struct VoiceRecentList: View {
    let searches: [RecentSearch]
    let onTap: (RecentSearch) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Recent searches")
                    .font(AppFont.heading2)
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text("Saved on this phone")
                    .font(AppFont.caption)
                    .foregroundStyle(Palette.muted)
            }
            .padding(.bottom, 4)

            ForEach(searches) { search in
                Button {
                    onTap(search)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mic")
                            .font(.system(size: 14))
                            .foregroundStyle(Palette.muted)
                        Text(search.phrase)
                            .font(AppFont.body)
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text(when(search.searchedAt))
                            .font(AppFont.monoData)
                            .foregroundStyle(Palette.muted)
                    }
                    .frame(minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func when(_ date: Date) -> String {
        Calendar.current.isDateInToday(date)
            ? date.formatted(date: .omitted, time: .shortened)
            : date.formatted(.dateTime.day().month(.abbreviated))
    }
}

struct VoicePhraseCard: View {
    let phrase: String
    let onAgain: () -> Void

    var body: some View {
        Button(action: onAgain) {
            HStack(spacing: 12) {
                Image(systemName: "mic.fill")
                    .foregroundStyle(Palette.accent)
                VStack(alignment: .leading, spacing: 2) {
                    SectionLabel(text: "You said")
                    Text("“\(phrase)”")
                        .font(AppFont.body)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Text("Again")
                    .font(AppFont.button)
                    .foregroundStyle(Palette.accent)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .fill(Palette.accentSoft)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens voice search again")
    }
}
