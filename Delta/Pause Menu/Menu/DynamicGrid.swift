//
//  DynamicGrid.swift
//  Delta
//
//  Created by Riley Testut on 3/4/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import SwiftUI

@available(iOS 26, *)
struct DynamicGrid: Layout
{
    var pageWidth: Double
    
    var itemWidth: Double = 145
    var edgeInsets: EdgeInsets = EdgeInsets(top: 25, leading: 25, bottom: 25, trailing: 25)
    
    var horizontalSpacing: Double = 15
    var verticalSpacing: Double = 15
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize
    {
        guard !subviews.isEmpty else { return .zero }
        
        guard var proposedWidth = proposal.width ?? pageWidth, var proposedHeight = proposal.height else {
            // What's ideal size for a grid without constraints? ¯\_(ツ)_/¯
            return .zero
        }
        
        
        
//        if let proposedWidth = proposal.width, proposal.height == nil
//        {
//            // Known width, but unknown height
//            
//            
//        }
        
        
        
        let maxSize = maxSize(subviews: subviews)
        
        if proposedWidth < maxSize.width
        {
            // Replace with ideal width (max item width)
            proposedWidth = maxSize.width
        }
        
        if proposedHeight < maxSize.height
        {
            // Replace with ideal height (max item height)
            proposedHeight = maxSize.height
        }
        
        let pageSize = pageSize(for: subviews, itemSize: maxSize, proposedSize: CGSize(width: proposedWidth, height: proposedHeight))
        
        // Assume we can always fit 1 item thanks to above check
        let itemsPerRow = Int((pageSize.width + horizontalSpacing) / (maxSize.width + horizontalSpacing))
        let itemsPerColumn = Int((pageSize.height + verticalSpacing) / (maxSize.height + verticalSpacing))
        
        let itemsPerPage = itemsPerRow * itemsPerColumn
        let numberOfPages = Int((Double(subviews.count) / Double(itemsPerPage)).rounded(.up)) //TODO: Clean up
        
        
//        // Assume we can always fit 1 item thanks to above check
//        let itemsPerRow = Int((proposedWidth - maxSize.width) / (maxSize.width + horizontalSpacing)) + 1
//        let itemsPerColumn = Int((proposedHeight - maxSize.height) / (maxSize.height + verticalSpacing)) + 1
//
//        // So much simpler alas
////        let itemsPerRow = Int(proposedWidth / (maxSize.width + horizontalSpacing))
////        let itemsPerColunn = Int(proposedHeight / (maxSize.height + verticalSpacing))
//
//
//        let itemsPerPage = itemsPerRow * itemsPerColumn
////        let numberOfPages = (subviews.count + 1) / itemsPerPage
//        let numberOfPages = Int((Double(subviews.count) / Double(itemsPerPage)).rounded(.up)) //TODO: Clean up

        let preferredWidth = proposedWidth * Double(numberOfPages) // TODO: Account for between page spacing
        let preferredHeight = proposedHeight
        let sizeThatFits = CGSize(width: preferredWidth, height: preferredHeight)
        return CGSize(width: proposedWidth * 2, height: proposedHeight)
    }
    
    func sizeThatFits2(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize
    {
        guard !subviews.isEmpty else { return .zero }
        
        guard var proposedWidth = proposal.width, var proposedHeight = proposal.height else {
            // What's ideal size for a grid without constraints? ¯\_(ツ)_/¯
            return .zero
        }
        
        let maxSize = maxSize(subviews: subviews)
        
        if proposedWidth < maxSize.width
        {
            // Replace with ideal width (max item width)
            proposedWidth = maxSize.width
        }
        
        if proposedHeight < maxSize.height
        {
            // Replace with ideal height (max item height)
            proposedHeight = maxSize.height
        }
        
        
        
//        if proposedWidth == 0 && proposedHeight != 0
//        {
//            // Minimum width, TODO:
//            
//            proposedWidth =
//            
//            let height = (maxSize.height + verticalSpacing)
//            return CGSize(width: itemWidth, height: height)
//        }
//        else if proposedWidth == 0 && proposedHeight == 0
//        {
//            
//        }
//        else if proposedWidth != 0 && proposedHeight == 0
//        {
//            // Minimum height
//            
//        }
        
        // Regular Proposal Size (both dimensions specified)
        
        // * FOR NOW assume all items have same width (maxWidth)
        // * get maximum height of all subviews (maxHeight)
        // * calculates how many fit in a row: proposed width / (maxWidth + horizontalSpacing)
        // * calc how many fit in a column: proposed height / (maxHeight + verticalSpacing)
        
        
        // We try to stay within proposal bounds
        // However, if we have more than what fits in proposal, we start a second page -- which is a full other proposal width
        
        
        // 320 width
        // item == 100
        // spacing == 10
        // 100 + 10 + 100 + 10 + 100 (3 perfectly)
        
        // How many times can width go into
       // 320 - item width == 220
        // 220 - (item width + spacing) * subviews.count - 1
        
        
        
        var numberOfRows = 1.0
        var numberOfItemsPerCurrentRow = 1.0
        var maxNumberOfItemsPerRow = 1.0
        
//        var contentWidth = maxSize.width
        
        // Start at 1 because we know we have at least one subview and it makes math simpler.
        for index in 1 ..< subviews.count
        {
            numberOfItemsPerCurrentRow += 1
            
            if numberOfItemsPerCurrentRow > maxNumberOfItemsPerRow
            {
                // If new maximum, record it
                maxNumberOfItemsPerRow = numberOfItemsPerCurrentRow
            }
                        
            if (numberOfItemsPerCurrentRow / numberOfRows) > (proposedWidth / proposedHeight)
            {
                // Aspect ratio is too wide, reset and add a row
                numberOfRows += 1
                numberOfItemsPerCurrentRow = 0
                maxNumberOfItemsPerRow -= 1
            }
        }
        
        // We now know max number of items per row, use that to calculate width
        let preferredWidth = maxSize.width + (maxSize.width + horizontalSpacing) * CGFloat(maxNumberOfItemsPerRow - 1)
        let preferredHeight = numberOfRows * maxSize.height
        
        
        // Assume we can always fit 1 item thanks to above check
//        let itemsPerRow = Int((proposedWidth - maxSize.width) / (maxSize.width + horizontalSpacing)) + 1
//        let itemsPerColumn = Int((proposedHeight - maxSize.height) / (maxSize.height + verticalSpacing)) + 1
//        
//        // So much simpler alas
////        let itemsPerRow = Int(proposedWidth / (maxSize.width + horizontalSpacing))
////        let itemsPerColunn = Int(proposedHeight / (maxSize.height + verticalSpacing))
//        
//        
//        let itemsPerPage = itemsPerRow * itemsPerColumn
////        let numberOfPages = (subviews.count + 1) / itemsPerPage
//        let numberOfPages = Int((Double(subviews.count) / Double(itemsPerPage)).rounded(.up)) //TODO: Clean up
//        
//        let preferredWidth = proposedWidth * Double(numberOfPages) // TODO: Account for between page spacing
//        let preferredHeight = proposedHeight
        
        let sizeThatFits = CGSize(width: preferredWidth, height: preferredHeight)
        return sizeThatFits
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void)
    {
        guard !subviews.isEmpty else { return }
        
        guard var proposedWidth = proposal.width ?? pageWidth, var proposedHeight = proposal.height else {
            // What's ideal size for a grid without constraints? ¯\_(ツ)_/¯
            return
        }
        
        let maxSize = maxSize(subviews: subviews)
        
        // Find page size offset from bounds
        let pageSize = pageSize(for: subviews, itemSize: maxSize, proposedSize: CGSize(width: proposedWidth, height: proposedHeight))
        let offsetX = (bounds.midX - (pageSize.width / 2)) - bounds.minX
        let offsetY = (bounds.midY - (pageSize.height / 2)) - bounds.minY
        
        let placementProposal = ProposedViewSize(width: maxSize.width, height: maxSize.height)
        
        let pageWidth = pageSize.width
        let pageHeight = pageSize.height
        
        let itemsPerRow = Int((pageWidth + horizontalSpacing) / (maxSize.width + horizontalSpacing))
        let itemsPerColumn = max(Int((pageHeight + verticalSpacing) / (maxSize.height + verticalSpacing)), 1)
        let itemsPerPage = itemsPerRow * itemsPerColumn
        
        let pageOffset = (self.pageWidth/2.0 - pageSize.width/2.0)
        let edgeOfPageToEnd: Double = self.pageWidth - (pageSize.width + pageOffset)
        
        for (subview, index) in zip(subviews, 0...)
        {
            let page = index / itemsPerPage
            let indexInPage = index % itemsPerPage
            let row = indexInPage / itemsPerRow
            let column = indexInPage % itemsPerRow
            
            // Page width * index of page + column offset
            let x = (pageWidth * Double(page)) + Double(column) * (maxSize.width + horizontalSpacing) + (edgeOfPageToEnd * Double(page)) + pageOffset + (pageOffset * Double(page))
            let y = Double(row) * (maxSize.height + verticalSpacing)
            
            subview.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y), proposal: placementProposal)
        }
    }
    
    func placeSubviews2(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void)
    {
        guard !subviews.isEmpty else { return }
        
        // Lays out horizontally left to right, top to bottom
        
        let maxSize = maxSize(subviews: subviews)
        
        let placementProposal = ProposedViewSize(width: maxSize.width, height: maxSize.height)
        
        let pageWidth = bounds.width
        let pageHeight = bounds.height
        
        let itemsPerRow = Int((pageWidth + horizontalSpacing) / (maxSize.width + horizontalSpacing))
        let itemsPerColumn = max(Int((pageHeight + verticalSpacing) / (maxSize.height + verticalSpacing)), 1)
        let itemsPerPage = itemsPerRow * itemsPerColumn
        
        for (subview, index) in zip(subviews, 0...)
        {
            let page = index / itemsPerPage
            let indexInPage = index % itemsPerPage
            let row = indexInPage / itemsPerRow
            let column = indexInPage % itemsPerRow
            
            // Page width * index of page + column offset
            let x = (pageWidth * Double(page)) + Double(column) * (maxSize.width + horizontalSpacing)
            let y = Double(row) * (maxSize.height + verticalSpacing)
            
            subview.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y), proposal: placementProposal)
        }
    }
}

@available(iOS 26, *)
private extension DynamicGrid
{
    /// Finds the largest ideal size of the subviews.
    func maxSize(subviews: Subviews) -> CGSize {
        let subviewSizes = subviews.map { $0.sizeThatFits(.init(width: itemWidth, height: nil)) }
        let maxSize: CGSize = subviewSizes.reduce(.zero) { currentMax, subviewSize in
            CGSize(
                width: max(currentMax.width, itemWidth),
                height: max(currentMax.height, subviewSize.height))
        }

        return maxSize
    }
    
    func pageSize(for subviews: Subviews, itemSize: CGSize, proposedSize: CGSize) -> CGSize
    {
        var numberOfRows = 1.0
        var numberOfItemsPerCurrentRow = 1.0
        var maxNumberOfItemsPerRow = 1.0
        
        let proposedWidth = proposedSize.width - edgeInsets.leading - edgeInsets.trailing
        let proposedHeight = proposedSize.height - edgeInsets.top - edgeInsets.bottom
        
        let proposedAspectRatio = (proposedSize.width  / proposedSize.height) // Use proposedSize directly
        
//        var contentWidth = maxSize.width
        
        // Start at 1 because we know we have at least one subview and it makes math simpler.
        for index in 1 ..< subviews.count
        {
            let pageWidth = (itemSize.width + horizontalSpacing) * CGFloat(numberOfItemsPerCurrentRow) - horizontalSpacing
            
            let isWiderThanAspectRatio = (numberOfItemsPerCurrentRow / numberOfRows) > proposedAspectRatio && (numberOfItemsPerCurrentRow / numberOfRows != 1.0)
            let isTooWideInGeneral = pageWidth > proposedWidth
            
            if isWiderThanAspectRatio || isTooWideInGeneral
            {
                // Aspect ratio is too wide, reset and add a row
                numberOfRows += 1
                numberOfItemsPerCurrentRow = 0
//                maxNumberOfItemsPerRow -= 1
                
                continue
            }
            
            let pageHeight = (itemSize.height + verticalSpacing) * numberOfRows - verticalSpacing
            if pageHeight > proposedHeight
            {
                // We've grown too large, time to start paginating
//                numberOfRows -= 1
//                maxNumberOfItemsPerRow += 1
                break
            }
            
            numberOfItemsPerCurrentRow += 1
            
            if numberOfItemsPerCurrentRow > maxNumberOfItemsPerRow
            {
                // If new maximum, record it
                maxNumberOfItemsPerRow = numberOfItemsPerCurrentRow
            }
            
            
                   
//            if (numberOfItemsPerCurrentRow / numberOfRows) == 1.0 && pageWidth < proposedWidth
//            {
//                // Always prefer squares, if they can fit.
//            }
            

        }
        
        let pageWidth = (itemSize.width + horizontalSpacing) * CGFloat(maxNumberOfItemsPerRow) - horizontalSpacing
        let pageHeight = (itemSize.height + verticalSpacing) * numberOfRows - verticalSpacing
        
        return CGSize(width: pageWidth, height: pageHeight)
    }
}

//@available(iOS 26, *)
//private struct MenuItemButton: View
//{
//    @State
//    var item: MenuItem
//    
//    var itemWidth: Double = 145
//    
//    var body: some View {
//        Button {
//            item.action(item)
//        } label: {
//            VStack(spacing: 10) {
//                if let image = item.image
//                {
//                    Image(uiImage: image)
//                        .font(.headline)
////                        .frame(width: 44, height: 44)
//                }
//                
//                Text(item.text)
//                    .font(.headline)
//            }
//            .foregroundStyle(.white)
//        }
//        .padding()
//        .frame(width: itemWidth)
//        .frame(maxHeight: .infinity)
//        .glassEffect(.clear.interactive(), in: .rect(cornerRadius: 32))
//    }
//}

@available(iOS 26, *)
#Preview {
    GeometryReader { geometry in
        ScrollView(.horizontal) {
            DynamicGrid(pageWidth: geometry.size.width, itemWidth: 145) {
                let saveStateItem = MenuItem(text: NSLocalizedString("Save State", comment: ""), image: #imageLiteral(resourceName: "SaveSaveState"), action: { _ in })
                
                let loadStateItem = MenuItem(text: NSLocalizedString("Load State", comment: ""), image: #imageLiteral(resourceName: "LoadSaveState"), action: { _ in })
                
                let cheatCodesItem = MenuItem(text: NSLocalizedString("Cheat Codes", comment: ""), image: #imageLiteral(resourceName: "CheatCodes"), action: { _ in })
                
                let fastForwardItem = MenuItem(text: NSLocalizedString("Fast Forward", comment: ""), image: #imageLiteral(resourceName: "FastForward"), action: { _ in })
                let sustainButtonsItem = MenuItem(text: NSLocalizedString("Hold Buttons", comment: ""), image: #imageLiteral(resourceName: "SustainButtons"), action: { _ in })
                let screenshotItem = MenuItem(text: NSLocalizedString("Screenshot", comment: ""), image: #imageLiteral(resourceName: "Screenshot"), action: { _ in })
                
                let optionA = MenuItem(text: NSLocalizedString("Option A", comment: ""), image: #imageLiteral(resourceName: "Screenshot"), action: { _ in })
                let optionB = MenuItem(text: NSLocalizedString("Option B", comment: ""), image: #imageLiteral(resourceName: "Screenshot"), action: { _ in })
                let optionC = MenuItem(text: NSLocalizedString("Option C", comment: ""), image: #imageLiteral(resourceName: "Screenshot"), action: { _ in })
                let optionD = MenuItem(text: NSLocalizedString("Option D", comment: ""), image: #imageLiteral(resourceName: "Screenshot"), action: { _ in })
                let optionE = MenuItem(text: NSLocalizedString("Option E", comment: ""), image: #imageLiteral(resourceName: "Screenshot"), action: { _ in })
                let optionF = MenuItem(text: NSLocalizedString("Option F", comment: ""), image: #imageLiteral(resourceName: "Screenshot"), action: { _ in })
                let optionG = MenuItem(text: NSLocalizedString("Option G", comment: ""), image: #imageLiteral(resourceName: "Screenshot"), action: { _ in })
                let optionH = MenuItem(text: NSLocalizedString("Option H", comment: ""), image: #imageLiteral(resourceName: "Screenshot"), action: { _ in })
                
                let menuItems = [saveStateItem, loadStateItem, cheatCodesItem, fastForwardItem, sustainButtonsItem, screenshotItem, optionA, optionB, optionC, optionD, optionE, optionF, optionG, optionH]
                ForEach(menuItems, id: \.text) { item in
                    MenuItemButton(item: item, isHidden: false)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.yellow)
                }
            }
            .background(Color.red)
        }
    //    .containerRelativeFrame(.vertical) { (length, axis) in length * 0.75 }
        .background(Color.purple)
    }
    
}


// Once the aspect ratio is WIDER than container's, we move onto new row
