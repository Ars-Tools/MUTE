//
//  App.swift
//  MUTE
//
//  Created by Kota on 12/2/25.
//
import SwiftUI
import GSP
import Artwork
@main
struct App: SwiftUI.App {
    var body: some Scene {
        WindowGroup {
//            Exhibit(artwork: MTLClearColor(red: 1, green: 1, blue: 0, alpha: 1))
            Exhibit(artwork: Visualise.AxesXY())
        }
    }
}
