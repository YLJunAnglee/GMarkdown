//
//  MarkdownListProcessor.swift
//  GMarkdown
//
//  Created by 巩柯 on 2025/7/3.
//

import Foundation
import UIKit
import Markdown

// MARK: - List Processor
public struct MarkdownListProcessor {
    
    // MARK: - Public Static Methods
    
    public static func processOrderedList(_ orderedList: OrderedList,
                                        style: Style,
                                        visitor: inout any MarkupVisitor) -> NSMutableAttributedString {
        let result = MarkdownStyleProcessor.buildDefaultAttributedString(from: "", style: style)
        
        for (index, listItem) in orderedList.listItems.enumerated() {
            let listItemString = createOrderedListItemString(
                listItem: listItem,
                index: index,
                orderedList: orderedList,
                style: style,
                visitor: &visitor
            )
            result.append(listItemString)
        }
        
    
        return result
    }
    
    public static func processUnorderedList(_ unorderedList: UnorderedList,
                                          style: Style,
                                          visitor: inout any MarkupVisitor) -> NSMutableAttributedString {
        let result = MarkdownStyleProcessor.buildDefaultAttributedString(from: "", style: style)
        
        for listItem in unorderedList.listItems {
            let listItemString = createUnorderedListItemString(
                listItem: listItem,
                depth: unorderedList.listDepth,
                style: style,
                visitor: &visitor
            )
            result.append(listItemString)
        }
        return result
    }
    
    // MARK: - Private Static Methods
    
    private static func createOrderedListItemString(listItem: ListItem,
                                                  index: Int,
                                                  orderedList: OrderedList,
                                                  style: Style,
                                                  visitor: inout any MarkupVisitor) -> NSAttributedString {
        
        let listItemAttributedString = (visitor.visit(listItem) as AnyObject).mutableCopy() as! NSMutableAttributedString
        
        let isRTL = TextDirectionDetector.isRTLLanguage(text: listItemAttributedString.string)
        let number = Int(orderedList.startIndex) > 0
            ? Int(orderedList.startIndex) + index
            : index + 1
        
        let listItemAttributes = createListItemAttributes(
            depth: orderedList.listDepth,
            isRTL: isRTL,
            marker: "\(number).",
            style: style
        )
        
        let numberPrefix = createOrderedListPrefix(
            number: number,
            attributes: listItemAttributes,
            style: style
        )
        
        listItemAttributedString.insert(numberPrefix, at: 0)
        applyListParagraphStyle(to: listItemAttributedString, attributes: listItemAttributes)
        return listItemAttributedString
    }
    
    private static func createUnorderedListItemString(listItem: ListItem,
                                                    depth: Int,
                                                    style: Style,
                                                    visitor: inout any MarkupVisitor) -> NSAttributedString {
        let listItemAttributedString = (visitor.visit(listItem) as AnyObject).mutableCopy() as! NSMutableAttributedString
        let isRTL = TextDirectionDetector.isRTLLanguage(text: listItemAttributedString.string)
        
        let bulletSymbol = getBulletSymbol(for: listItem)
        
        let listItemAttributes = createListItemAttributes(
            depth: depth,
            isRTL: isRTL,
            marker: bulletSymbol,
            style: style
        )
        
        let bulletPrefix = createBulletPrefix(
            symbol: bulletSymbol,
            attributes: listItemAttributes
        )
        
        listItemAttributedString.insert(bulletPrefix, at: 0)
        applyListParagraphStyle(to: listItemAttributedString, attributes: listItemAttributes)
        return listItemAttributedString
    }
    
    private static func getBulletSymbol(for listItem: ListItem) -> String {
        if let checkBox = listItem.checkbox {
            switch checkBox {
            case .checked:
                return "☑"
            case .unchecked:
                return "☐"
            }
        } else {
            return "•"
        }
    }
    
    private static func createListItemAttributes(depth: Int,
                                               isRTL: Bool,
                                               marker: String,
                                               style: Style) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [:]
        let paragraphStyle = NSMutableParagraphStyle()
        
        let font = style.fonts.current
        paragraphStyle.lineSpacing = 25 - font.pointSize
        paragraphStyle.paragraphSpacing = 14
        paragraphStyle.baseWritingDirection = isRTL ? .rightToLeft : .leftToRight
        paragraphStyle.alignment = isRTL ? .right : .left
        
        let baseLeftMargin: CGFloat = 5.0
        let leftMarginOffset = baseLeftMargin + (20.0 * CGFloat(depth))
        let spacingFromIndex: CGFloat = 8.0
        
        // The marker must follow the same Dynamic Type scale as the list body.
        // Using the fixed-size bullet font here makes the old tab-stop layout
        // unstable when the body font becomes large.
        let markerFont = font
        let markerWidth = ceil(NSAttributedString(string: marker,
                                                   attributes: [.font: markerFont]).size().width)
        
        let markerEndX = leftMarginOffset + markerWidth
        let contentStartX = markerEndX + spacingFromIndex
        paragraphStyle.firstLineHeadIndent = leftMarginOffset
        paragraphStyle.headIndent = contentStartX
        
        attributes[.paragraphStyle] = paragraphStyle
        attributes[.font] = font
        attributes[.foregroundColor] = style.colors.current
        attributes[.listDepth] = depth
        
        return attributes
    }

    private static func applyListParagraphStyle(to attributedString: NSMutableAttributedString,
                                                attributes: [NSAttributedString.Key: Any]) {
        guard attributedString.length > 0,
              let paragraphStyle = attributes[.paragraphStyle] as? NSParagraphStyle else { return }
        attributedString.addAttribute(.paragraphStyle,
                                      value: paragraphStyle,
                                      range: NSRange(location: 0, length: attributedString.length))
    }
    
    private static func createOrderedListPrefix(number: Int,
                                              attributes: [NSAttributedString.Key: Any],
                                              style: Style) -> NSAttributedString {
        var numberAttributes = attributes
        numberAttributes[.font] = attributes[.font] ?? style.fonts.current
        numberAttributes[.foregroundColor] = style.colors.current

        return NSAttributedString(string: "\(number). ", attributes: numberAttributes)
    }
    
    private static func createBulletPrefix(symbol: String,
                                         attributes: [NSAttributedString.Key: Any]) -> NSAttributedString {
        return NSAttributedString(string: "\(symbol) ", attributes: attributes)
    }
}
