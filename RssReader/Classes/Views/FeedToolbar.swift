import SwiftUI

struct FeedToolbar: View {
    let title: String
    let showMenu: () -> Void
    let addFeed: () -> Void

    var body: some View {
        controls
            .background(Color(uiColor: .systemBackground))
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button(action: showMenu) { Image(systemName: "line.3.horizontal").frame(width: 44, height: 44) }
                .accessibilityLabel("Feeds")
            Text(title).font(.headline).lineLimit(1).frame(maxWidth: .infinity)
            Button(action: addFeed) { Image(systemName: "plus").frame(width: 44, height: 44) }
                .accessibilityLabel("Add RSS Feed")
                .accessibilityIdentifier("addRSSFeed")
        }
        .font(.system(size: 20, weight: .medium))
        .foregroundStyle(.primary)
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
    }
}

struct AddFeedSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var url = ""
    @State private var name = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    let onAdded: (ValidatedFeed) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://example.com/feed", text: $url)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityLabel("RSS Feed URL")
                        .accessibilityIdentifier("rssFeedURL")
                        .disabled(isSaving)
                    TextField("Name (optional)", text: $name)
                        .accessibilityIdentifier("rssFeedName")
                        .disabled(isSaving)
                } header: {
                    Text("RSS Feed")
                } footer: {
                    Text("Paste an RSS or Atom feed URL. Leave the name empty to use the feed’s title. Saved feeds appear in Οι ροές μου.")
                }
                if isSaving {
                    HStack { ProgressView(); Text("Checking feed…") }
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).accessibilityIdentifier("rssFeedError")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemGroupedBackground))
            .toolbarBackground(Color(uiColor: .systemGroupedBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationTitle("Add RSS Feed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isSaving = false; dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { errorMessage = nil; isSaving = true }
                        .disabled(isSaving || url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("saveRSSFeed")
                }
            }
        }
        .presentationBackground(Color(uiColor: .systemGroupedBackground))
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(isSaving)
        .task(id: isSaving) {
            guard isSaving else { return }
            do {
                let normalized = try FeedValidator.normalizedURL(url).absoluteString
                guard !ConfigurationManager.containsFeed(normalized) else { throw FeedSubscriptionError.duplicate }
                let feed = try await FeedValidator.validate(url, name: name)
                try Task.checkCancellation()
                guard !ConfigurationManager.containsFeed(feed.url) else { throw FeedSubscriptionError.duplicate }
                try ArticleStore.shared.get().addSubscription(feed)
                NotificationCenter.default.post(name: .feedSubscriptionsChanged, object: nil)
                onAdded(feed)
            } catch is CancellationError {
                // Dismissing the sheet cancels the request without saving.
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}

@MainActor
extension UIViewController {
    func presentAddFeedSheet(onAdded: @escaping (ValidatedFeed) -> Void) {
        let host = UIHostingController(rootView: AddFeedSheet { [weak self] feed in
            self?.dismiss(animated: true) { onAdded(feed) }
        })
        host.modalPresentationStyle = .pageSheet
        host.view.backgroundColor = .systemGroupedBackground
        host.sheetPresentationController?.detents = [.medium(), .large()]
        host.sheetPresentationController?.prefersGrabberVisible = true
        present(host, animated: true)
    }
}

extension Notification.Name {
    static let feedSubscriptionsChanged = Notification.Name("FeedSubscriptionsChanged")
}
