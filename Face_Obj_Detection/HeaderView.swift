//
//  HeaderView.swift
//  Face_Obj_Detection
//
//  Created by Rohan Kumar on 9/2/22.
//


import SwiftUI

struct HeaderView: View {
    @State private var infoButtonPressed = false
    @EnvironmentObject var globals : GlobalVars
    
    
    var body: some View {
        VStack {
            ZStack {
                
                // Background Color (Defined in ContentView)
                UIPink.ignoresSafeArea()
                
                // App Title Text
                HStack {
                    Text("Age Predictor")
                        .foregroundColor(.white)
                        .font(.system(size: 35))
                        .multilineTextAlignment(.center)
                }
                
                // Information Button
                HStack {
                    Spacer()
                    Button(action: {
                        self.infoButtonPressed.toggle()
                    }) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 24, weight: .regular))
                            .accentColor(.white)
                    }
                    .offset(x: -20)
        
                    
                    
                }
            }
            .frame(height:70, alignment:.top)
            
            if self.infoButtonPressed {
                Toggle("Object Detection", isOn: $globals.doObjectDetection)
                    .toggleStyle(SwitchToggleStyle(tint: UIPink))
                    .padding()
                    .background(Color.init(white: 0.97))
                    .offset(y:-8)
            }
        }
    }
}

struct HeaderView_Previews: PreviewProvider {
    static var previews: some View {
        HeaderView()
            .environmentObject(GlobalVars())
    }
}
