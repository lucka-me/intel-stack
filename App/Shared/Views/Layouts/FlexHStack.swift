//
//  FlexHStack.swift
//  Intel Stack
//
//  Created by Lucka on 2024-02-01.
//

import SwiftUI

struct FlexHStack: Layout {
    let alignment: HorizontalAlignment
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat
    
    init(alignment: HorizontalAlignment = .center, horizontalSpacing: CGFloat = 6, verticalSpacing: CGFloat = 6) {
        self.alignment = alignment
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
    }

    func makeCache(subviews: Subviews) -> Cache {
        .init(rows: [ ])
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        guard !subviews.isEmpty else {
            return .init(width: proposal.width ?? .infinity, height: 0)
        }
        let rowWidthLimitation = proposal.width ?? .infinity
        
        var rows: [ Cache.RowData ] = [ ]
        
        var first = true
        var totalHeight: CGFloat = 0
        var rowData = Cache.RowData()
        
        subviews.forEach { subview in
            let subviewSize = subview.sizeThatFits(.unspecified)
            if first {
                rowData.maxHeight = subviewSize.height
                rowData.width = subviewSize.width
                first = false
                return
            }
            
            if rowData.width + horizontalSpacing + subviewSize.width <= rowWidthLimitation {
                rowData.maxHeight = max(rowData.maxHeight, subviewSize.height)
                rowData.subviewsCount += 1
                rowData.width += horizontalSpacing + subviewSize.width
            } else {
                // Break
                rows.append(rowData)
                totalHeight += verticalSpacing + rowData.maxHeight
                rowData = .init(maxHeight: subviewSize.height, width: subviewSize.width)
            }
        }
        rows.append(rowData)
        totalHeight += rowData.maxHeight
        
        cache = .init(rows: rows)
        
        return .init(width: proposal.width ?? .infinity, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        guard !subviews.isEmpty else { return }
        
        var row = 0
        
        var position = CGPoint(x: bounds.minX, y: bounds.minY)
        switch alignment {
        case .center:
            position.x = (bounds.minX + bounds.maxX - cache.rows[row].width) / 2
        case .trailing:
            position.x = bounds.maxX - cache.rows[row].width
        default:
            break
        }
        
        var indexInRow = 0
        
        subviews.forEach { subview in
            if indexInRow == cache.rows[row].subviewsCount {
                position.y += cache.rows[row].maxHeight + verticalSpacing
                row += 1
                switch alignment {
                case .center:
                    position.x = (bounds.minX + bounds.maxX - cache.rows[row].width) / 2
                case .trailing:
                    position.x = bounds.maxX - cache.rows[row].width
                default:
                    position.x = bounds.minX
                }
                
                indexInRow = 0
            }
            
            let proposal = ProposedViewSize(width: nil, height: cache.rows[row].maxHeight)
            subview.place(at: position, proposal: proposal)
            position.x += subview.sizeThatFits(proposal).width + horizontalSpacing
            
            indexInRow += 1
        }
    }
}

extension FlexHStack {
    struct Cache {
        struct RowData {
            var maxHeight: CGFloat = 0
            var subviewsCount: Int = 1
            var width: CGFloat = 0
        }
        
        var rows: [ RowData ]
    }
}
