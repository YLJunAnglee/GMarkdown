//
//  GMarkdownMultiView.swift
//  GMarkRender
//
//  Created by GIKI on 2024/7/25.
//

import Markdown
import MPITextKit
import UIKit

// MARK: - Protocols

protocol ChunkCellConfigurable {
    func configure(with chunk: GMarkChunk)
}

protocol ChunkCellProvider {
    static var cellClass: AnyClass { get }
    static var reuseIdentifier: String { get }
    func dequeueConfiguredCell(for collectionView: UICollectionView, at indexPath: IndexPath, with chunk: GMarkChunk) -> UICollectionViewCell
}

// MARK: - ChunkCellProvider Implementation

struct DefaultChunkCellProvider<T: UICollectionViewCell & ChunkCellConfigurable>: ChunkCellProvider {
    static var cellClass: AnyClass { T.self }
    static var reuseIdentifier: String { String(describing: T.self) }
    
    func dequeueConfiguredCell(for collectionView: UICollectionView, at indexPath: IndexPath, with chunk: GMarkChunk) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: Self.reuseIdentifier, for: indexPath) as! T
        cell.configure(with: chunk)
        return cell
    }
}

extension ChunkCellConfigurable {
    func configure(with _: GMarkChunk) {}
}

// MARK: - CellProvider Factory

class ChunkCellProviderFactory {
    
    static func provider(for chunk: GMarkChunk) -> ChunkCellProvider {
        switch chunk.chunkType {
        case .Text:
            return DefaultChunkCellProvider<GMarkTextCell>()
        case .Code:
            return DefaultChunkCellProvider<GMarkCodeCell>()
        case .Table:
            return DefaultChunkCellProvider<GMarkTableCell>()
        case .Thematic:
            return DefaultChunkCellProvider<GMarkThematicCell>()
        case .Latex:
            if chunk.latexImage != nil {
                return DefaultChunkCellProvider<GMarkLatexCell>()
            } else {
                return DefaultChunkCellProvider<GMarkTextCell>()
            }
        default:
            return DefaultChunkCellProvider<GMarkTextCell>()
        }
    }
    
    static var allProviders: [ChunkCellProvider.Type] {
        return [
            DefaultChunkCellProvider<GMarkTextCell>.self,
            DefaultChunkCellProvider<GMarkCodeCell>.self,
            DefaultChunkCellProvider<GMarkTableCell>.self,
            DefaultChunkCellProvider<GMarkThematicCell>.self,
            DefaultChunkCellProvider<GMarkLatexCell>.self,
        ]
    }
}

// MARK: - UICollectionView Extension

extension UICollectionView {
    func registerCells(_ providers: [ChunkCellProvider.Type]) {
        for provider in providers {
            register(provider.cellClass, forCellWithReuseIdentifier: provider.reuseIdentifier)
        }
    }
}

public class GMarkdownMultiView: UIView {
    // MARK: - Properties

    private typealias AttachmentSizes = [(NSRange, CGSize)]
    
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, GMarkChunk>!
    private var chunks: [GMarkChunk] = []
    private var sourceStyles: [ObjectIdentifier: Style] = [:]
    private var sourceAttributedTexts: [ObjectIdentifier: NSAttributedString] = [:]
    private var sourceTables: [ObjectIdentifier: GMarkTable] = [:]
    private var sourceAttachmentSizes: [ObjectIdentifier: [(NSRange, CGSize)]] = [:]
    private var sourceTableAttachmentSizes: [ObjectIdentifier: (headers: [AttachmentSizes], body: [[AttachmentSizes]])] = [:]
    private var lastContainerWidth: CGFloat = 0
    
    public var handlerChain: GMarkHandlerChain = .init()
    
    // MARK: - Initialization
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        GMarkCodeHighlight.shared.changeDark(traitCollection.userInterfaceStyle == .dark)
        addHandlers()
        setupCollectionView()
        configureDataSource()
    }

    override public func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        let appearanceChanged = previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle
        let dynamicTypeChanged = previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory
        guard appearanceChanged || dynamicTypeChanged else { return }
        if appearanceChanged {
            GMarkCodeHighlight.shared.changeDark(traitCollection.userInterfaceStyle == .dark)
        }
        applyDynamicTypeToChunks()
        guard collectionView != nil else { return }
        // MPITextKit and attachment cells retain layout/rendering snapshots.
        // A trait change must reconfigure visible cells immediately; waiting
        // for scrolling/reuse leaves a blank or stale middle section.
        collectionView.reloadData()
        collectionView.collectionViewLayout.invalidateLayout()
        collectionView.layoutIfNeeded()
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        let width = bounds.width
        guard width > 0, abs(width - lastContainerWidth) > 0.5 else { return }
        lastContainerWidth = width
        guard !chunks.isEmpty else { return }

        var changed = false
        for chunk in chunks {
            guard let originalStyle = sourceStyles[ObjectIdentifier(chunk)] else { continue }
            changed = chunk.relayout(for: width, preserving: originalStyle) || changed
        }
        guard changed else { return }
        applyDynamicTypeToChunks()
        collectionView.collectionViewLayout.invalidateLayout()
        collectionView.reloadData()
    }
    
    // MARK: - Setup
    
    private func setupCollectionView() {
        let layout = createLayout()
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        configureCollectionView()
        addCollectionViewConstraints()
        registerCells()
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.sectionInset = .zero
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        return layout
    }
    
    private func configureCollectionView() {
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.allowsSelection = false
        collectionView.delegate = self
        addSubview(collectionView)
    }
    
    private func addCollectionViewConstraints() {
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
    
    private func registerCells() {
        collectionView.registerCells(ChunkCellProviderFactory.allProviders)
    }
    
    private func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Section, GMarkChunk>(collectionView: collectionView) { [weak self] collectionView, indexPath, item in
            let provider = ChunkCellProviderFactory.provider(for: item)
            let cell = provider.dequeueConfiguredCell(for: collectionView, at: indexPath, with: item)
            self?.configureHandlerChain(for: cell)
            return cell
        }
    }
    
    private func configureHandlerChain(for cell: UICollectionViewCell) {
        if let textCell = cell as? GMarkTextCell {
            textCell.handlerChain = handlerChain
        } else if let codeCell = cell as? GMarkCodeCell {
            codeCell.handlerChain = handlerChain
        } else if let tableCell = cell as? GMarkTableCell {
            tableCell.handlerChain = handlerChain
        }
    }
    
    // MARK: - Public Methods
    
    public func updateMarkdown(_ items: [GMarkChunk]) {
        chunks = items
        sourceStyles = Dictionary(uniqueKeysWithValues: items.map { (ObjectIdentifier($0), $0.style) })
        sourceAttributedTexts = Dictionary(uniqueKeysWithValues: items.map { (ObjectIdentifier($0), $0.attributedText) })
        sourceAttachmentSizes = Dictionary(uniqueKeysWithValues: items.map {
            (ObjectIdentifier($0), $0.attributedText.attachmentSizes())
        })
        sourceTables = Dictionary(uniqueKeysWithValues: items.compactMap { item in
            guard let table = item.tableRender?.markTable else { return nil }
            return (ObjectIdentifier(item), table)
        })
        sourceTableAttachmentSizes = Dictionary(uniqueKeysWithValues: items.compactMap { item in
            guard let table = item.tableRender?.markTable else { return nil }
            return (
                ObjectIdentifier(item),
                (
                    headers: table.headers?.map { $0.attachmentSizes() } ?? [],
                    body: table.bodys?.map { $0.map { $0.attachmentSizes() } } ?? []
                )
            )
        })
        applyDynamicTypeToChunks()
        lastContainerWidth = 0
        var snapshot = NSDiffableDataSourceSnapshot<Section, GMarkChunk>()
        snapshot.appendSections([.main])
        snapshot.appendItems(items, toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    /// Releases the current chunk snapshot and associated style references.
    /// Call this on page exit or before dropping a large document. UIKit state
    /// changes are marshalled to the main thread when invoked by a host task.
    public func clearContent() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.clearContent()
            }
            return
        }

        chunks.removeAll(keepingCapacity: false)
        sourceStyles.removeAll(keepingCapacity: false)
        sourceAttributedTexts.removeAll(keepingCapacity: false)
        sourceTables.removeAll(keepingCapacity: false)
        sourceAttachmentSizes.removeAll(keepingCapacity: false)
        sourceTableAttachmentSizes.removeAll(keepingCapacity: false)
        lastContainerWidth = 0
        var snapshot = NSDiffableDataSourceSnapshot<Section, GMarkChunk>()
        snapshot.appendSections([.main])
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func applyDynamicTypeToChunks() {
        guard !chunks.isEmpty else { return }
        for chunk in chunks {
            let key = ObjectIdentifier(chunk)
            guard let originalStyle = sourceStyles[key] else { continue }
            var scaledStyle = originalStyle
            scaledStyle.fonts = DynamicTypeFontStyle(
                base: originalStyle.fonts,
                compatibleWith: traitCollection
            )
            chunk.applyDynamicType(
                style: scaledStyle,
                baseAttributedText: sourceAttributedTexts[key],
                baseTable: sourceTables[key],
                baseAttachmentSizes: sourceAttachmentSizes[key] ?? [],
                baseTableAttachmentSizes: sourceTableAttachmentSizes[key],
                compatibleWith: traitCollection
            )
        }
    }
}

extension GMarkdownMultiView: UICollectionViewDelegateFlowLayout {
    public func collectionView(_: UICollectionView, layout _: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard let item = dataSource.itemIdentifier(for: indexPath) else {
            return CGSize(width: max(bounds.width, 1), height: 0.00)
        }

        let width = min(item.style.maxContainerWidth, max(bounds.width, 1))
        return CGSize(width: width, height: item.itemSize.height)
    }
}

extension GMarkdownMultiView {
    func addHandlers() {
        let handler = DefaultMarkHandler()
        handlerChain.addHandler(handler)
    }
}

// MARK: - Supporting Types

enum Section {
    case main
}



class GMarkThematicCell: UICollectionViewCell, ChunkCellConfigurable {
    static let reuseIdentifier = "GMarkThematicCell"
    private let line = UIView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(line)
        line.backgroundColor = .lightGray
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        line.frame = CGRect(x: 4, y: 0.5 * (contentView.bounds.height - 1), width: contentView.bounds.width - 8, height: 1)
    }
    
    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(with _: GMarkChunk) {}
}
