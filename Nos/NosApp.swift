//
//  NosApp.swift
//  Nos
//
//  Created by Matthew Lorentz on 1/31/23.
//

import SwiftUI

@main
struct NosApp: App {
    let persistenceController = PersistenceController.shared
    let relayService = RelayService(persistenceController: PersistenceController.shared)

    var body: some Scene {
        WindowGroup {
            AppView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(relayService)
        }
    }
}
