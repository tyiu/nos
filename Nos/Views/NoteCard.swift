//
//  NoteCard.swift
//  Planetary
//
//  Created by Martin Dutra on 25/10/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI
import Logger
import CoreData
import Dependencies

/// This view displays the information we have for an message suitable for being used in a list or grid.
///
/// Use this view inside MessageButton to have nice borders.
struct NoteCard: View {
    
    @ObservedObject var note: Event
    
    var style = CardStyle.compact
    
    @State private var subscriptionIDs = [RelaySubscription.ID]()
    @State private var userTappedShowOutOfNetwork = false
    @State private var replyCount = 0
    @State private var replyAvatarURLs = [URL]()
    @State private var reports = [Event]()
    @State private var warningController = NoteWarningController()
    
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var relayService: RelayService
    @Environment(CurrentUser.self) private var currentUser
    @Dependency(\.persistenceController) var persistenceController
    
    private var showFullMessage: Bool
    private let showReplyCount: Bool
    private var hideOutOfNetwork: Bool
    private var replyAction: ((Event) -> Void)?
    
    private var attributedReplies: AttributedString? {
        if replyCount == 0 {
            return nil
        }
        let string = String(localized: .reply.replies(replyCount))
        do {
            var attributed = try AttributedString(markdown: string)
            if let range = attributed.range(of: "\(replyCount)") {
                attributed[range].foregroundColor = .primaryTxt
            }
            return attributed
        } catch {
            return nil
        }
    }

    init(
        note: Event,
        style: CardStyle = .compact,
        showFullMessage: Bool = false,
        hideOutOfNetwork: Bool = true,
        showReplyCount: Bool = true,
        replyAction: ((Event) -> Void)? = nil,
        reported: Bool = false,
        labeled: Bool = false
    ) {
        self.note = note
        self.style = style
        self.showFullMessage = showFullMessage
        self.hideOutOfNetwork = hideOutOfNetwork
        self.showReplyCount = showReplyCount
        self.replyAction = replyAction
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch style {
            case .compact:
                VStack(spacing: 0) {
                    HStack(alignment: .center, spacing: 0) {
                        if !warningController.showWarning, let author = note.author {
                            Button {
                                router.currentPath.wrappedValue.append(author)
                            } label: {
                                NoteCardHeader(note: note, author: author)
                            }
                            NoteOptionsButton(note: note)
                        } else {
                            Spacer()
                        }
                    }
                    Divider().overlay(Color.cardDividerTop).shadow(color: .cardDividerTopShadow, radius: 0, x: 0, y: 1)
                    Group {
                        if note.isStub {
                            HStack {
                                Spacer()
                                ProgressView().foregroundColor(.primaryTxt)
                                Spacer()
                            }
                            .padding(30)
                        } else {
                            CompactNoteView(
                                note: note, 
                                showFullMessage: showFullMessage, 
                                loadLinks: !warningController.showWarning
                            )
                            .blur(radius: warningController.showWarning ? 6 : 0)
                            .frame(maxWidth: .infinity)
                        }
                        BeveledSeparator()
                        HStack(spacing: 0) {
                            if showReplyCount {
                                StackedAvatarsView(avatarUrls: replyAvatarURLs, size: 20, border: 0)
                                    .padding(.trailing, 8)
                                if let replies = attributedReplies {
                                    Text(replies)
                                        .font(.subheadline)
                                        .foregroundColor(Color.secondaryTxt)
                                }
                            }
                            Spacer()
                            RepostButton(note: note) 
                            LikeButton(note: note)
                            ReplyButton(note: note, replyAction: replyAction)
                        }
                        .padding(.leading, 13)
                    }
                }
                .blur(radius: warningController.showWarning ? 6 : 0)
                .opacity(warningController.showWarning ? 0.3 : 1)
                .frame(minHeight: warningController.showWarning ? 300 : nil)
                .overlay(WarningView(controller: warningController))
            case .golden:
                if let author = note.author {
                    GoldenPostView(author: author, note: note)
                } else {
                    EmptyView()
                }
            }
        }
        .task {
            warningController.note = note
            warningController.shouldHideOutOfNetwork = hideOutOfNetwork
        }
        .task {
            if note.isStub {
                _ = await relayService.requestEvent(with: note.identifier)
            } 
        }
        .onAppear {
            Task(priority: .userInitiated) {
                await subscriptionIDs += Event.requestAuthorsMetadataIfNeeded(
                    noteID: note.identifier,
                    using: relayService,
                    in: persistenceController.backgroundViewContext
                )
            }
        }
        .onDisappear {
            Task(priority: .userInitiated) {
                await relayService.decrementSubscriptionCount(for: subscriptionIDs)
                subscriptionIDs.removeAll()
            }
        }
        .background(LinearGradient.cardBackground)
        .task {
            if showReplyCount {
                let (replyCount, replyAvatarURLs) = await Event.replyMetadata(
                    for: note.identifier, 
                    context: persistenceController.backgroundViewContext
                )
                self.replyCount = replyCount
                self.replyAvatarURLs = replyAvatarURLs
            }
        }
        .listRowInsets(EdgeInsets())
        .cornerRadius(cornerRadius)
    }

    var cornerRadius: CGFloat {
        switch style {
        case .golden:
            return 15
        case .compact:
            return 20
        }
    }
}

struct NoteCard_Previews: PreviewProvider {
    
    static var previewData = PreviewData()
    static var previews: some View {
        Group {
            ScrollView {
                VStack {
                    NoteCard(note: previewData.longFormNote, hideOutOfNetwork: false)
                    NoteCard(note: previewData.shortNote, hideOutOfNetwork: false)
                    NoteCard(note: previewData.longNote, hideOutOfNetwork: false)
                    NoteCard(note: previewData.imageNote, hideOutOfNetwork: false)
                    NoteCard(note: previewData.expiringNote, hideOutOfNetwork: false)
                    NoteCard(note: previewData.verticalImageNote, hideOutOfNetwork: false)
                    NoteCard(note: previewData.veryWideImageNote, hideOutOfNetwork: false)
                    NoteCard(note: previewData.imageNote, style: .golden, hideOutOfNetwork: false)
                    NoteCard(note: previewData.linkNote, hideOutOfNetwork: false)
                }
            }
        }
        .environment(\.managedObjectContext, previewData.previewContext)
        .environmentObject(previewData.relayService)
        .environmentObject(previewData.router)
        .environment(previewData.currentUser)
        .padding()
        .background(Color.appBg)
    }
}
