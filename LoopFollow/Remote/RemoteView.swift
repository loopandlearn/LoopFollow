//
//  RemoteView.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-07-19.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import Foundation
import SwiftUI

struct RemoteView: View {
    var body: some View {
        VStack {
            Text("Remote Control")
                .font(.largeTitle)
                .padding()

            // Your remote control UI components go here
            Spacer()
        }
    }
}

struct RemoteView_Previews: PreviewProvider {
    static var previews: some View {
        RemoteView()
    }
}
