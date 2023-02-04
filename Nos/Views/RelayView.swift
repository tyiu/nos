//
//  RelayView.swift
//  Nos
//
//  Created by Matthew Lorentz on 1/31/23.
//

import SwiftUI
import CoreData

struct RelayView: View {
    
    @Environment(\.managedObjectContext) private var viewContext
    
    @State var newRelayAddress: String = ""
    
    @FetchRequest(fetchRequest: Relay.allRelaysRequest(), animation: .default)
    private var relays: FetchedResults<Relay>
    
    var body: some View {
        NavigationView {
            List {
                ForEach(relays) { relay in
                    Text(relay.address!)
                }
                
                Section {
                    TextField("relay address", text: $newRelayAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.none)
                        .keyboardType(.URL)
                    Button("Add Relay") {
                        addRelay()
                    }
                }
            }
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
#endif
            }
        }
        .navigationTitle("Relays")
    }
    
    private func addRelay() {
        withAnimation {
            let relay = Relay(entity: NSEntityDescription.entity(forEntityName: "Relay", in: viewContext)!, insertInto: viewContext)
            relay.address = newRelayAddress.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

            do {
                try viewContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct RelayView_Previews: PreviewProvider {
    
    static var previewContext = PersistenceController.preview.container.viewContext
    
    static var previews: some View {
        NavigationStack {
            RelayView()
        }.environment(\.managedObjectContext, previewContext)
    }
}