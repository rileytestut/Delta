//
//  ContainerRelativeGrid.swift
//  Delta
//
//  Created by Riley Testut on 3/6/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import SwiftUI

@available(iOS 26, *)
struct ContainerRelativeGrid: Layout
{
    var pageWidth: Double
    
    var itemWidth: Double = 145
    var edgeInsets: EdgeInsets = EdgeInsets(top: 15, leading: 15, bottom: 15, trailing: 15)
    
    var horizontalSpacing: Double = 15
    var verticalSpacing: Double = 15
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize
    {
        guard !subviews.isEmpty else { return .zero }
        
        let proposedHeight: Double = proposal.height ?? self.pageWidth // Minimum size == square
        let itemSize = self.maxSize(subviews: subviews)
        
        let (columns, rows) = self.gridDimensions(itemCount: subviews.count, itemSize: itemSize, proposedHeight: proposedHeight)
        
        let itemsPerPage = columns * rows
        let numberOfPages = max(1, Int(ceil(Double(subviews.count) / Double(itemsPerPage))))
        
        return CGSize(width: self.pageWidth * Double(numberOfPages), height: proposedHeight)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void)
    {
        guard !subviews.isEmpty else { return }
        
        let proposedHeight = bounds.height
        let itemSize = self.maxSize(subviews: subviews)
        
        let (columns, rows) = self.gridDimensions(itemCount: subviews.count, itemSize: itemSize, proposedHeight: proposedHeight)
        
        let itemsPerPage = columns * rows
        
        let gridWidth = Double(columns) * (itemSize.width + self.horizontalSpacing) - self.horizontalSpacing
        let gridHeight = Double(rows) * (itemSize.height + self.verticalSpacing) - self.verticalSpacing
        
        let placementProposal = ProposedViewSize(width: itemSize.width, height: itemSize.height)
        
        for (index, subview) in subviews.enumerated()
        {
            let (page, indexOnPage) = index.quotientAndRemainder(dividingBy: itemsPerPage)
            let (row, column) = indexOnPage.quotientAndRemainder(dividingBy: columns)
            
            let pageOriginX = bounds.minX + Double(page) * self.pageWidth
            let offsetX = (self.pageWidth - gridWidth) / 2.0
            let offsetY = (proposedHeight - gridHeight) / 2.0
            
            let x = pageOriginX + offsetX + Double(column) * (itemSize.width + self.horizontalSpacing)
            let y = bounds.minY + offsetY + Double(row) * (itemSize.height + self.verticalSpacing)
            
            subview.place(at: CGPoint(x: x, y: y), proposal: placementProposal)
        }
    }
}

@available(iOS 26, *)
private extension ContainerRelativeGrid
{
    func maxSize(subviews: Subviews) -> CGSize
    {
        let subviewSizes = subviews.map { $0.sizeThatFits(.init(width: self.itemWidth, height: nil)) }
        let maxSize: CGSize = subviewSizes.reduce(.zero) { currentMax, subviewSize in
            CGSize(
                width: max(currentMax.width, self.itemWidth),
                height: max(currentMax.height, subviewSize.height))
        }
        
        return maxSize
    }
    
    func gridDimensions(itemCount: Int, itemSize: CGSize, proposedHeight: Double) -> (columns: Int, rows: Int)
    {
        guard itemCount > 0 else { return (1, 1) }
        
        let availableWidth = self.pageWidth - self.edgeInsets.leading - self.edgeInsets.trailing
        let availableHeight = proposedHeight - self.edgeInsets.top - self.edgeInsets.bottom
        
        guard availableWidth > 0 && availableHeight > 0 else { return (1, 1) }
        
        let maxColumns = Int((availableWidth + self.horizontalSpacing) / (itemSize.width + self.horizontalSpacing))
        let maxRows = Int((availableHeight + self.verticalSpacing) / (itemSize.height + self.verticalSpacing))
        
        // Special case: prefer 2x2 square for exactly 4 items
        if itemCount == 4 && maxColumns >= 2 && maxRows >= 2
        {
            return (2, 2)
        }
        
        let containerAspectRatio = availableWidth / availableHeight
        let maxItemsPerPage = maxColumns * maxRows
        let effectiveCount = min(itemCount, maxItemsPerPage) // The count of items, or the max items if we need to paginate onto multiple pages
        
        // Prefer multi-row, multi-column layouts over single row/column when possible
        let canFitSquare = maxColumns >= 2 && maxRows >= 2 && effectiveCount >= 3
        
        var bestColumns = 1
        var bestRows = min(effectiveCount, maxRows)
        var bestAspectDiff = Double.infinity
        
        for columns in 1...maxColumns
        {
            let neededRows = Int(ceil(Double(effectiveCount) / Double(columns)))
            guard neededRows >= 1 && neededRows <= maxRows else { continue }
            
            if canFitSquare && (columns == 1 || neededRows == 1)
            {
                // Skip single row/column when a square layout fits
                continue
            }
            
            let contentWidth = (Double(columns) * (itemSize.width + self.horizontalSpacing)) - self.horizontalSpacing
            let contentHeight = (Double(neededRows) * (itemSize.height + self.verticalSpacing)) - self.verticalSpacing
            
            let fillRatio = contentWidth / availableWidth
            if fillRatio < 0.5 && columns < maxColumns
            {
                // Skip configurations that are less than half the width of the screen
                continue
            }
            
            guard contentHeight > 0 else { continue }
            
            let contentAspectRatio = contentWidth / contentHeight
            let aspectDiff = abs(contentAspectRatio - containerAspectRatio)
            
            if aspectDiff < bestAspectDiff
            {
                bestAspectDiff = aspectDiff
                bestColumns = columns
                bestRows = neededRows
            }
        }
        
        return (bestColumns, bestRows)
    }
}

// MARK: - Previews

@available(iOS 26, *)
private struct ContainerRelativeGridPreview: View
{
    var itemCount: Int
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal) {
                ContainerRelativeGrid(pageWidth: geometry.size.width) {
                    ForEach(0..<itemCount, id: \.self) { index in
                        MenuItemButton(item: .init(text: "Item \(index + 1)", image: UIImage(systemName: "star.fill"), action: { _ in }))
                    }
                }
                .frame(height: geometry.size.height)
            }
            .background(Color.pink)
        }
    }
}

@available(iOS 26, *)
#Preview("4 Items (2x2 Square)") {
    ContainerRelativeGridPreview(itemCount: 4)
}

@available(iOS 26, *)
#Preview("5 Items") {
    ContainerRelativeGridPreview(itemCount: 5)
}

@available(iOS 26, *)
#Preview("6 Items") {
    ContainerRelativeGridPreview(itemCount: 6)
}

@available(iOS 26, *)
#Preview("7 Items") {
    ContainerRelativeGridPreview(itemCount: 7)
}

@available(iOS 26, *)
#Preview("8 Items") {
    ContainerRelativeGridPreview(itemCount: 8)
}

@available(iOS 26, *)
#Preview("9 Items") {
    ContainerRelativeGridPreview(itemCount: 9)
}

@available(iOS 26, *)
#Preview("10 Items") {
    ContainerRelativeGridPreview(itemCount: 10)
}

@available(iOS 26, *)
#Preview("11 Items") {
    ContainerRelativeGridPreview(itemCount: 11)
}

@available(iOS 26, *)
#Preview("12 Items") {
    ContainerRelativeGridPreview(itemCount: 12)
}

@available(iOS 26, *)
#Preview("20 Items") {
    ContainerRelativeGridPreview(itemCount: 20)
}

@available(iOS 26, *)
#Preview("48 Items") {
    ContainerRelativeGridPreview(itemCount: 48)
}
