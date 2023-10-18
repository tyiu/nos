//
//  AuthorCard.swift
//  Nos
//
//  Created by Matthew Lorentz on 6/5/23.
//

import SwiftUI

/// This view displays the information we have for an Author suitable for being used in a grid.
struct AuthorCard: View {
   
    @ObservedObject var author: Author 
    
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var currentUser: CurrentUser
    
    var followersRequest: FetchRequest<Follow>
    var followersResult: FetchedResults<Follow> { followersRequest.wrappedValue }

    var followers: Followed {
        followersResult.map { $0 }
    }

    private var knownFollowers: [Follow] {
        author.followers.filter {
            guard let source = $0.source else {
                return false
            }
            return source.hasHumanFriendlyName == true &&
                source != author &&
                (currentUser.isFollowing(author: source) || currentUser.isBeingFollowedBy(author: source))
        }
    }
    
    init(author: Author) {
        self.author = author
        self.followersRequest = FetchRequest(fetchRequest: Follow.followsRequest(destination: [author]))
    }
    
    var body: some View {
        Button {
            router.push(author)
        } label: {
            VStack(alignment: .center, spacing: 0) {
                if let profilePhotoURL = author.profilePhotoURL {
                    SquareImage(url: profilePhotoURL)
                        .aspectRatio(contentMode: .fit)
                        .layoutPriority(1)
                } else {
                    Image.emptyAvatar
                        .resizable()
                        .renderingMode(.original)
                        .aspectRatio(contentMode: .fit)
                        .padding(16)
                }
                
                Text(author.safeName)
                    .padding(EdgeInsets(top: 9, leading: 10, bottom: 5, trailing: 10))
                    .lineLimit(1)
                    .foregroundColor(.primaryTxt)
                    .font(.subheadline)
                
                if author.muted {
                    Text(Localized.muted.string)
                        .font(.subheadline)
                        .foregroundColor(Color.secondaryText)
                } else {
                    Text(author.nip05 ?? author.npubString ?? "")
                        .foregroundColor(.secondaryText)
                        .font(.footnote)
                        .lineLimit(1)
                        .padding(EdgeInsets(top: 0, leading: 10, bottom: 5, trailing: 10))
                    Text(author.about ?? "")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                        .allowsHitTesting(false)
                        .padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
                }
                Spacer(minLength: 9)
                
                if let first = knownFollowers[safe: 0]?.source {
                    AuthorCardKnownFollowersView(
                        first: first,
                        knownFollowers: knownFollowers,
                        followers: followers
                    )
                    Spacer(minLength: 9)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .aspectRatio(goldenRatio, contentMode: ContentMode.fill)
            .background(
                LinearGradient.cardBackground
            )
            .cornerRadius(15)
            .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        }
        .buttonStyle(CardButtonStyle(style: .golden))
    }
}

struct AuthorCard_Previews: PreviewProvider {
    static var previewData = PreviewData()
    static var previews: some View {
        StaggeredGrid(
            list: [previewData.alice, previewData.bob, previewData.eve], 
            columns: 2, 
            content: { author in
                AuthorCard(author: author)
            }
        ) 
    }
}
