//
//  ProfileView.swift
//  Nos
//
//  Created by Matthew Lorentz on 2/16/23.
//

import SwiftUI
import CoreData
import Dependencies
import SwiftUINavigation
import Logger

struct ProfileView: View {
    
    @ObservedObject var author: Author
    var addDoubleTapToPop = false

    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var relayService: RelayService
    @Environment(CurrentUser.self) private var currentUser
    @EnvironmentObject private var router: Router
    @Dependency(\.analytics) private var analytics
    @Dependency(\.unsAPI) private var unsAPI
    
    @State private var showingOptions = false
    @State private var showingReportMenu = false
    @State private var usbcAddress: USBCAddress?
    @State private var usbcBalance: Double?
    @State private var usbcBalanceTimer: Timer?
    
    @State private var subscriptionIds: [String] = []

    @State private var alert: AlertState<Never>?
    
    @FetchRequest
    private var events: FetchedResults<Event>

    @State private var unmutedEvents: [Event] = []

    private func computeUnmutedEvents() async {
        unmutedEvents = events.filter {
            if let author = $0.author {
                let notDeleted = $0.deletedOn.count == 0
                return !author.muted && notDeleted
            }
            return false
        }
    }
    
    var isShowingLoggedInUser: Bool {
        author.hexadecimalPublicKey == currentUser.publicKeyHex
    }
    
    init(author: Author, addDoubleTapToPop: Bool = false) {
        self.author = author
        self.addDoubleTapToPop = addDoubleTapToPop
        _events = FetchRequest(fetchRequest: author.allPostsRequest())
    }
    
    func refreshProfileFeed() async {
        // Close out stale requests
        if !subscriptionIds.isEmpty {
            await relayService.decrementSubscriptionCount(for: subscriptionIds)
            subscriptionIds.removeAll()
        }
        
        guard let authorKey = author.hexadecimalPublicKey else {
            return
        }
        
        let authors = [authorKey]
        let textFilter = Filter(authorKeys: authors, kinds: [.text, .delete, .repost, .longFormContent], limit: 50)
        async let textSub = relayService.openSubscription(with: textFilter)
        subscriptionIds.append(await textSub)
        subscriptionIds.append(
            contentsOf: await relayService.requestProfileData(
                for: authorKey, 
                lastUpdateMetadata: author.lastUpdatedMetadata, 
                lastUpdatedContactList: nil // always grab contact list because we purge follows aggressively
            )
        )
        
        // reports
        let reportFilter = Filter(kinds: [.report], pTags: [authorKey])
        subscriptionIds.append(await relayService.openSubscription(with: reportFilter))
    }
    
    func loadUSBCBalance() async {
        guard let unsName = author.uns, !unsName.isEmpty else {
            usbcAddress = nil
            usbcBalance = nil
            usbcBalanceTimer?.invalidate()
            usbcBalanceTimer = nil
            return
        }
        do {
            usbcAddress = try await unsAPI.usbcAddress(for: unsName)
            if isShowingLoggedInUser {
                usbcBalance = try await unsAPI.usbcBalance(for: unsName)
                currentUser.usbcAddress = usbcAddress
                usbcBalanceTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                    Task { @MainActor in 
                        usbcBalance = try await unsAPI.usbcBalance(for: unsName) 
                    }
                }
            }
        } catch {
            Log.optional(error, "Failed to load USBC balance for \(author.hexadecimalPublicKey ?? "null")")
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                ProfileHeader(author: author)
                    .compositingGroup()
                    .shadow(color: .profileShadow, radius: 10, x: 0, y: 4)
                    .id(author.id)

                LazyVStack {
                    if unmutedEvents.isEmpty {
                        Text(.localizable.noEventsOnProfile)
                            .padding()
                    } else {
                        ForEach(unmutedEvents) { event in
                            VStack {
                                NoteButton(note: event, hideOutOfNetwork: false, displayRootMessage: true)
                                .padding(.bottom, 15)
                            }
                        }
                    }
                }
                .padding(.top, 10)
            }
            .background(Color.appBg)
            .doubleTapToPop(tab: .profile, enabled: addDoubleTapToPop) { proxy in
                proxy.scrollTo(author.id)
            }
        }
        .nosNavigationBar(title: .localizable.profileTitle)
        .navigationDestination(for: Event.self) { note in
            RepliesView(note: note)
        }                  
        .navigationDestination(for: URL.self) { url in URLView(url: url) }
        .navigationDestination(for: ReplyToNavigationDestination.self) { destination in
            RepliesView(note: destination.note, showKeyboard: true)
        }
        .navigationDestination(for: MutesDestination.self) { _ in
            MutesView()
        }
        .navigationDestination(for: FollowsDestination.self) { destination in
            FollowsView(title: .localizable.follows, authors: destination.follows)
        }
        .navigationDestination(for: FollowersDestination.self) { destination in
            FollowsView(title: .localizable.followers, authors: destination.followers)
        }
        .navigationDestination(for: RelaysDestination.self) { destination in
            RelayView(author: destination.author, editable: false)
        }
        .navigationBarItems(
            trailing:
                HStack {
                    if usbcBalance != nil {
                        USBCBalanceBarButtonItem(balance: $usbcBalance)
                    } else if let usbcAddress, !isShowingLoggedInUser {
                        SendUSBCBarButtonItem(destinationAddress: usbcAddress, destinationAuthor: author)
                    }
                    Button(
                        action: {
                            showingOptions = true
                        },
                        label: {
                            Image(systemName: "ellipsis")
                        }
                    )
                    .confirmationDialog(String(localized: .localizable.share), isPresented: $showingOptions) {
                        Button(String(localized: .localizable.copyUserIdentifier)) {
                            UIPasteboard.general.string = author.publicKey?.npub ?? ""
                        }
                        Button(String(localized: .localizable.copyLink)) {
                            UIPasteboard.general.string = author.webLink
                        }
                        if isShowingLoggedInUser {
                            Button(
                                action: {
                                    currentUser.editing = true
                                    router.push(author)
                                },
                                label: {
                                    Text(.localizable.editProfile)
                                }
                            )
                            Button(
                                action: {
                                    router.push(MutesDestination())
                                },
                                label: {
                                    Text(.localizable.mutedUsers)
                                }
                            )
                        } else {
                            if author.muted {
                                Button(String(localized: .localizable.unmuteUser)) {
                                    Task {
                                        do {
                                            try await author.unmute(viewContext: viewContext)
                                        } catch {
                                            alert = AlertState(title: {
                                                TextState(String(localized: .localizable.error))
                                            }, message: {
                                                TextState(error.localizedDescription)
                                            })
                                        }
                                    }
                                }
                            } else {
                                Button(String(localized: .localizable.mute)) {
                                    Task { @MainActor in
                                        do {
                                            try await author.mute(viewContext: viewContext)
                                        } catch {
                                            alert = AlertState(title: {
                                                TextState(String(localized: .localizable.error))
                                            }, message: {
                                                TextState(error.localizedDescription)
                                            })
                                        }
                                    }
                                }
                            }
                            
                            Button(String(localized: .localizable.reportUser), role: .destructive) {
                                showingReportMenu = true
                            }
                        }
                    }
                }
        )
        .reportMenu($showingReportMenu, reportedObject: .author(author))
        .task {
            await refreshProfileFeed()
        }
        .task {
            await computeUnmutedEvents()
        }
        .onChange(of: author.uns) { 
            Task {
                await loadUSBCBalance()
            }
        }
        .alert(unwrapping: $alert)
        .onAppear {
            Task { await loadUSBCBalance() }
            analytics.showedProfile()
        }
        .refreshable {
            await refreshProfileFeed()
            await computeUnmutedEvents()
        }
        .onChange(of: author.muted) { 
            Task {
                await computeUnmutedEvents()
            }
        }
        .onChange(of: author.events.count) { 
            Task {
                await computeUnmutedEvents()
            }
        }
        .onDisappear {
            Task(priority: .userInitiated) {
                await relayService.decrementSubscriptionCount(for: subscriptionIds)
                subscriptionIds.removeAll()
            }
        }
    }
}

#Preview("Generic user") {
    var previewData = PreviewData()
    
    return NavigationStack {
        ProfileView(author: previewData.previewAuthor)
    }
    .inject(previewData: previewData)
}

#Preview("UNS") {
    var previewData = PreviewData()
    
    return NavigationStack {
        ProfileView(author: previewData.eve)
    }
    .inject(previewData: previewData)
}

#Preview("Logged in User") {
    
    @Dependency(\.persistenceController) var persistenceController 
    
    lazy var previewContext: NSManagedObjectContext = {
        persistenceController.container.viewContext  
    }()

    lazy var currentUser: CurrentUser = {
        let currentUser = CurrentUser()
        currentUser.viewContext = previewContext
        Task { await currentUser.setKeyPair(KeyFixture.eve) }
        return currentUser
    }() 
    
    var previewData = PreviewData(currentUser: currentUser)
    
    return NavigationStack {
        ProfileView(author: previewData.eve)
    }
    .inject(previewData: previewData)
}
