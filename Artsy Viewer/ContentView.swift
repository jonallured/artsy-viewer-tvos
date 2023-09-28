//
//  ContentView.swift
//  Artsy Viewer
//
//  Created by Jonathan Allured on 11/15/22.
//

import SwiftUI

struct ContentView: View {
    @State private var artworks: [ArtworkInfo] = []
    @State private var showDebug = false
    @State private var messages: [SocketMessage] = []
    
    var body: some View {
        ScrollView(.horizontal) {
            HStack() {
                if showDebug {
                    ScrollView(.vertical) {
                        ScrollViewReader { value in
                            VStack(alignment: .leading) {
                                ForEach(messages, id: \.receivedAt) { message in
                                    Text(message.asLog())
                                        .lineLimit(1)
                                        .font(.custom("Courier", size: 10))
                                }
                                .onChange(of: messages.count) { _newValue in
                                    guard let lastMessage = messages.last else { return }
                                    value.scrollTo(lastMessage.receivedAt)
                                }
                            }
                        }
                    }
                    .frame(width: 600)
                    .foregroundColor(Color.black)
                    .background(Color.white)
                    .focusable()
                }
                ForEach(artworks, id: \.id) { artwork in
                    AsyncImage(url: URL(string: artwork.payload.image.url)) { image in
                        VStack(alignment: .leading) {
                            Spacer()
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                            Text(artwork.payload.blurb)
                                .frame(maxWidth: 600)
                                .lineLimit(2)
                        }
                        .focusable()
                    } placeholder: {
                        ProgressView()
                    }
                }
            }
            
        }
        .background(Color.black)
        .onLongPressGesture(minimumDuration: 10) {
            showDebug.toggle()
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .task {
            Something.omg(callback: stopLoading)
        }
    }
    
    func stopLoading(message: SocketMessage) {
        messages.append(message)
        
        guard let channelMessage = message.decoded as? ChannelMessage else { return }
        artworks = channelMessage.message
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
