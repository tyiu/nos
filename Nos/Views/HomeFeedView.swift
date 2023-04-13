//
//  HomeFeedView.swift
//  Nos
//
//  Created by Matthew Lorentz on 1/31/23.
//

import SwiftUI
import CoreData
import Combine
import Dependencies

struct HomeFeedView: View {
    
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var relayService: RelayService
    @EnvironmentObject var router: Router
    @EnvironmentObject var currentUser: CurrentUser
    @Dependency(\.analytics) private var analytics
    
    @StateObject var dataSource = PaginatedHomeFeedDataSource()

    // Probably the logged in user should be in the @Environment eventually
    @ObservedObject var user: Author
    
    init(user: Author) {
        self.user = user
    }

    var body: some View {
        NavigationStack(path: $router.homeFeedPath) {
            VStack {
                if dataSource.eventIDs.isEmpty {
                    VStack {
                        Spacer()
                        ProgressView()
                        .foregroundColor(.primaryTxt)
                        .background(Color.appBg)
                        .scaleEffect(2)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack {
                            ForEach(dataSource.eventIDs, id: \.self) { eventID in
                                LazyVStack {
                                    NoteButton(noteID: eventID, hideOutOfNetwork: false)
                                    .padding(.horizontal)
                                    .onAppear {
                                        if eventID == dataSource.eventIDs.last {
                                            Task {
                                                await dataSource.loadMore()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .background(Color.appBg)
            .padding(.top, 1)
            .navigationDestination(for: Event.self) { note in
                RepliesView(note: note)
            }
            .navigationDestination(for: Author.self) { author in
                if router.currentPath.wrappedValue.count == 1 {
                    ProfileView(author: author)
                } else {
                    if author == CurrentUser.shared.author, CurrentUser.shared.editing {
                        ProfileEditView(author: author)
                    } else {
                        ProfileView(author: author)
                    }
                }
            }
//            .overlay(Group {
//                if dataSource.eventIDs.isEmpty {
//                    Localized.noEvents.view
//                        .padding()
//                }
//            })
            .navigationBarItems(leading: SideMenuButton())
            .nosNavigationBar(title: .homeFeed)
        }
        .refreshable {
            await dataSource.refreshHomeFeed()
        }
        .onAppear {
            analytics.showedHome()
        }
        .onDisappear {
            // TODO: close subscriptions
        }
        .task {
            self.dataSource.user = user
        }
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

struct ContentView_Previews: PreviewProvider {
    
    static var persistenceController = PersistenceController.preview
    static var previewContext = persistenceController.container.viewContext
    static var relayService = RelayService(persistenceController: persistenceController)
    
    static var emptyPersistenceController = PersistenceController.empty
    static var emptyPreviewContext = emptyPersistenceController.container.viewContext
    static var emptyRelayService = RelayService(persistenceController: emptyPersistenceController)
    
    static var router = Router()
    
    static var currentUser: CurrentUser = {
        let currentUser = CurrentUser(persistenceController: persistenceController)
        currentUser.viewContext = previewContext
        currentUser.relayService = relayService
        Task { await currentUser.setKeyPair(KeyFixture.keyPair) }
        return currentUser
    }()
    
    static var shortNote: Event {
        let note = Event(context: previewContext)
        note.kind = 1
        note.content = "Hello, world!"
        note.author = user
        return note
    }
    
    static var longNote: Event {
        let note = Event(context: previewContext)
        note.kind = 1
        note.content = .loremIpsum(5)
        note.author = user
        return note
    }
    
    static var user: Author {
        let author = Author(context: previewContext)
        author.hexadecimalPublicKey = "d0a1ffb8761b974cec4a3be8cbcb2e96a7090dcf465ffeac839aa4ca20c9a59e"
        return author
    }
    
    static var previews: some View {
        HomeFeedView(user: user)
            .environment(\.managedObjectContext, previewContext)
            .environmentObject(relayService)
            .environmentObject(router)
            .environmentObject(currentUser)
        
        HomeFeedView(user: user)
            .environment(\.managedObjectContext, emptyPreviewContext)
            .environmentObject(emptyRelayService)
            .environmentObject(router)
    }
}
