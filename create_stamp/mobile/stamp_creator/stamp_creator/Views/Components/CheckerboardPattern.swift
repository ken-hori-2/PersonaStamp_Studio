//
//  CheckerboardPattern.swift
//  stamp_creator
//
//  透過を視覚化するチェッカーパターン背景
//

import SwiftUI

struct CheckerboardPattern: View {
    var body: some View {
        GeometryReader { geometry in
            let tileSize: CGFloat = 20
            let rows = Int(geometry.size.height / tileSize) + 1
            let cols = Int(geometry.size.width / tileSize) + 1
            
            ZStack {
                ForEach(0..<rows, id: \.self) { row in
                    ForEach(0..<cols, id: \.self) { col in
                        Rectangle()
                            .fill((row + col) % 2 == 0 ? Color.white.opacity(0.1) : Color.gray.opacity(0.1))
                            .frame(width: tileSize, height: tileSize)
                            .offset(x: CGFloat(col) * tileSize, y: CGFloat(row) * tileSize)
                    }
                }
            }
        }
    }
}
