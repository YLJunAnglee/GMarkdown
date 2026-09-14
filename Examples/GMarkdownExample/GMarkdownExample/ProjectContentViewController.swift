//
//  ProjectContentViewController.swift
//  GMarkdownExample
//  Created on 2026/9/8.
//

import UIKit
import GMarkdown

final class ProjectContentViewController: UITableViewController, UISearchResultsUpdating {
    private var books: [ProjectBookExport] = []
    private var visibleBooks: [ProjectBookExport] = []
    private let search = UISearchController(searchResultsController: nil)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "项目书籍"
        navigationItem.largeTitleDisplayMode = .never
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 64
        search.searchResultsUpdater = self
        search.obscuresBackgroundDuringPresentation = false
        search.searchBar.placeholder = "搜索书名"
        navigationItem.searchController = search
        definesPresentationContext = true
        showMessage("正在读取书籍…")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result { try ProjectBookLibrary.load() }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                switch result {
                case let .success(books):
                    self.books = books
                    self.visibleBooks = books
                    self.tableView.backgroundView = nil
                    self.tableView.reloadData()
                case let .failure(error):
                    self.showMessage(error.localizedDescription)
                }
            }
        }
    }

    func updateSearchResults(for searchController: UISearchController) {
        let query = (searchController.searchBar.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        visibleBooks = query.isEmpty ? books : books.filter {
            $0.title.localizedCaseInsensitiveContains(query) || $0.sourceName.localizedCaseInsensitiveContains(query)
        }
        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        visibleBooks.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "book")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "book")
        let book = visibleBooks[indexPath.row]
        cell.textLabel?.text = book.title
        cell.textLabel?.numberOfLines = 0
        cell.detailTextLabel?.text = "\(book.chapters.count) 章 · \(book.sourceName)"
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let book = visibleBooks[indexPath.row]
        navigationController?.pushViewController(
            ProjectBookChapterListViewController(book: book), animated: true
        )
    }

    private func showMessage(_ text: String) {
        let label = UILabel()
        label.text = text
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        tableView.backgroundView = label
    }
}

private final class ProjectBookChapterListViewController: UITableViewController, UISearchResultsUpdating {
    private let book: ProjectBookExport
    private var visibleChapters: [ProjectBookChapter]
    private let search = UISearchController(searchResultsController: nil)

    init(book: ProjectBookExport) {
        self.book = book
        visibleChapters = book.chapters
        super.init(style: .plain)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = book.title
        navigationItem.largeTitleDisplayMode = .never
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 64
        search.searchResultsUpdater = self
        search.obscuresBackgroundDuringPresentation = false
        search.searchBar.placeholder = "搜索章节名称或序号"
        navigationItem.searchController = search
        definesPresentationContext = true
        if book.sourceName == "projectBook.jsonl" {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "公式对照", style: .plain, target: self, action: #selector(openFormulaComparison)
            )
        }
    }

    @objc private func openFormulaComparison() {
        guard let chapter = book.chapters.first(where: { $0.position == 20 }),
              let source = chapter.contents.first else { return }
        do {
            navigationController?.pushViewController(try ProjectFormulaComparisonController(source: source), animated: true)
        } catch {
            let alert = UIAlertController(title: "无法创建对照", message: error.localizedDescription,
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "好", style: .default))
            present(alert, animated: true)
        }
    }

    func updateSearchResults(for searchController: UISearchController) {
        let query = (searchController.searchBar.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        visibleChapters = query.isEmpty ? book.chapters : book.chapters.filter {
            $0.title.localizedCaseInsensitiveContains(query) || String($0.position).contains(query)
        }
        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { visibleChapters.count }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "chapter")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "chapter")
        let chapter = visibleChapters[indexPath.row]
        cell.textLabel?.text = "\(chapter.position). \(chapter.title)"
        cell.textLabel?.numberOfLines = 0
        cell.detailTextLabel?.text = "\(chapter.contents.count) 个内容块"
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        navigationController?.pushViewController(
            ProjectChapterRenderController(chapter: visibleChapters[indexPath.row]), animated: true
        )
    }
}

private struct ProjectBookChapter {
    let position: Int
    let title: String
    let contents: [String]
}

private struct ProjectBookExport {
    let sourceName: String
    let title: String
    let chapters: [ProjectBookChapter]

    /// Only unwrap transport fields. Never normalize HTML, formulas, or Markdown.
    static func load(sourceName: String, url: URL) throws -> ProjectBookExport {
        let source = try String(contentsOf: url, encoding: .utf8)
        var title = "项目书籍"
        var catalog: [(id: String, title: String)] = []
        var chapterIDs: [String] = []
        var chapters: [ProjectBookChapter] = []
        var summary: [String: Any]?
        var lastRecord = ""
        var manifestCount = 0
        var summaryCount = 0
        for line in source.split(whereSeparator: \.isNewline) {
            guard let row = try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                  let record = row["record"] as? String else {
                throw failure("导出文件存在无效记录。")
            }
            lastRecord = record
            switch record {
            case "manifest":
                manifestCount += 1
                guard row["schemaVersion"] as? Int == 1 else { throw failure("不支持的导出版本。") }
                title = row["bookTitle"] as? String ?? title
            case "catalog":
                guard let response = row["response"] as? [String: Any],
                      let data = response["data"] as? [String: Any],
                      let list = data["list"] as? [[String: Any]] else { throw failure("章节目录无效。") }
                for item in list {
                    guard let id = item["id"] as? String else { throw failure("目录缺少章节 ID。") }
                    catalog.append((id, item["title"] as? String ?? "未命名章节"))
                }
            case "chapter":
                guard row["status"] as? String == "success",
                      let id = row["chapterID"] as? String,
                      let position = row["position"] as? Int, position == chapters.count + 1,
                      let response = row["response"] as? [String: Any],
                      let data = response["data"] as? [String: Any], data["dataId"] as? String == id,
                      let blocks = data["bookDataList"] as? [[String: Any]] else {
                    throw failure("章节数据不完整。")
                }
                let contents = try blocks.map { block -> String in
                    guard let bean = block["dataBaseBean"] as? [String: Any],
                          let kind = bean["bookDataType"] as? String,
                          ["TXT", "TABLE"].contains(kind), let text = bean["txt"] as? String else {
                        throw failure("第 \(position) 章包含尚未接入的内容类型，未跳过该内容。")
                    }
                    return text
                }
                chapterIDs.append(id)
                chapters.append(ProjectBookChapter(position: position,
                    title: catalog.first(where: { $0.id == id })?.title ?? data["title"] as? String ?? "未命名章节",
                    contents: contents))
            case "summary":
                summary = row
                summaryCount += 1
            default:
                throw failure("导出包含失败或未知记录，无法作为完整书籍加载。")
            }
        }
        guard manifestCount == 1, summaryCount == 1, lastRecord == "summary",
              summary?["status"] as? String == "completed",
              summary?["failed"] as? Int == 0,
              summary?["succeeded"] as? Int == chapters.count,
              summary?["expectedChapters"] as? Int == chapters.count,
              catalog.map({ $0.id }) == chapterIDs,
              Set(chapterIDs).count == chapterIDs.count else {
            throw failure("导出未完成，或章节数量、顺序不一致。")
        }
        return ProjectBookExport(sourceName: sourceName, title: title, chapters: chapters)
    }

    private static func failure(_ message: String) -> NSError {
        NSError(domain: "ProjectBookExport", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

private enum ProjectBookLibrary {
    static func load() throws -> [ProjectBookExport] {
        guard let originalURL = Bundle.main.url(forResource: "projectBook", withExtension: "jsonl") else {
            throw failure("找不到 projectBook.jsonl，请检查 Demo 资源。")
        }
        let extraURLs = Bundle.main.urls(forResourcesWithExtension: "jsonl", subdirectory: "Books")?
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending } ?? []
        var books = [try ProjectBookExport.load(sourceName: originalURL.lastPathComponent, url: originalURL)]
        books.append(contentsOf: try extraURLs.map {
            try ProjectBookExport.load(sourceName: $0.lastPathComponent, url: $0)
        })
        return books
    }

    private static func failure(_ message: String) -> NSError {
        NSError(domain: "ProjectBookLibrary", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

private final class ProjectChapterRenderController: UIViewController {
    private let contents: [String]
    private let diagnoseFormula: Bool
    private let modeControl = UISegmentedControl(items: ["分块渲染", "TextView 渲染"])
    private let container = UIView()
    private let imageLoader = NukeImageLoader()
    private var renderedWidth: CGFloat = 0
    private var renderedMode: Int = -1

    init(chapter: ProjectBookChapter, diagnoseFormula: Bool = false) {
        self.diagnoseFormula = diagnoseFormula
        contents = chapter.contents
        super.init(nibName: nil, bundle: nil)
        title = "\(chapter.position). \(chapter.title)"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = .systemBackground
        var buttons = [UIBarButtonItem(
            title: "原始内容", style: .plain, target: self, action: #selector(openRawContent)
        )]
        if diagnoseFormula {
            buttons.append(UIBarButtonItem(
                title: "后端对照", style: .plain, target: self, action: #selector(openBackendComparison)
            ))
        }
        navigationItem.rightBarButtonItems = buttons
        modeControl.selectedSegmentIndex = 0
        modeControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        for subview in [modeControl, container] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }
        let safeArea = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            modeControl.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 12),
            modeControl.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: 16),
            modeControl.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -16),
            container.topAnchor.constraint(equalTo: modeControl.bottomAnchor, constant: 12),
            container.leadingAnchor.constraint(equalTo: modeControl.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: modeControl.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        renderIfNeeded()
    }

    @objc private func modeChanged() {
        renderIfNeeded()
    }

    private func renderIfNeeded() {
        let width = container.bounds.width
        let mode = modeControl.selectedSegmentIndex
        guard width > 0, abs(width - renderedWidth) > 0.5 || mode != renderedMode else { return }
        renderedWidth = width
        renderedMode = mode
        container.subviews.forEach { $0.removeFromSuperview() }

        // Each comparison starts fresh so formula images from another style do not leak in.
        GMarkCachedManager.shared.clearAllCache()
        var style = MarkdownStyle.defaultStyle()
        style.maxContainerWidth = width
        let preview: UIView
        if mode == 0 {
            let markdownView = GMarkdownMultiView()
            let chunks = contents.flatMap { content -> [GMarkChunk] in
                // A separate generator keeps each source block independent, including its IDs.
                let blockGenerator = GMarkChunkGenerator()
                blockGenerator.style = style
                blockGenerator.imageLoader = imageLoader
                blockGenerator.addLaTexHandler()
                return GMarkProcessor(parser: GMarkParser(), chunkGenerator: blockGenerator)
                    .process(markdown: content)
            }
            markdownView.updateMarkdown(chunks)
            if diagnoseFormula {
                for content in contents { reportFormula(content, style: style, chunks: chunks) }
            }
            preview = markdownView
        } else {
            let markdownView = MarkdownTextView()
            markdownView.textContainerInset = .zero
            style.useMPTextKit = false
            style.codeBlockStyle.customRender = false
            GMarkupPluginManager.shared.resetToDefault()
            let result = NSMutableAttributedString(string: "")
            for (index, content) in contents.enumerated() {
                GMarkupPluginManager.shared.resetToDefault()
                var visitor = GMarkupAttachVisitor(style: style)
                visitor.imageLoader = imageLoader
                if index > 0 { result.append(NSAttributedString(string: "\n\n")) }
                result.append(visitor.visit(GMarkParser().parseMarkdown(from: content)))
            }
            markdownView.attributedText = result
            preview = markdownView
        }
        preview.frame = container.bounds
        preview.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(preview)
    }
    @objc private func openBackendComparison() {
        guard let source = contents.first else { return }
        navigationController?.pushViewController(ProjectFormulaBackendController(source: source), animated: true)
    }

    @objc private func openRawContent() {
        navigationController?.pushViewController(
            ProjectRawContentViewController(title: title ?? "原始内容", contents: contents), animated: true
        )
    }

    /// Demo-only evidence: distinguish recognition, payload changes, and image-render failure.
    private func reportFormula(_ source: String, style: MarkdownStyle, chunks: [GMarkChunk]) {
        let parser = GMarkParser()
        let nodes = parser.parseMarkdownToMarkups(markdown: source)
        let handler = LaTexMarkupHandler()
        let originalBody = GMarkLaTexRender.trimBrackets(from: source)
        print("[FormulaComparison] case=\(title ?? "")")
        print("[FormulaComparison] nodes=\(nodes.count), blockHandlerMatches=\(nodes.filter { handler.canHandle($0) }.count)")
        for node in nodes {
            var stringifier = GMarkupStringifier()
            let payload = GMarkLaTexRender.trimBrackets(from: stringifier.visit(node))
            print("[FormulaComparison] node=\(type(of: node)), payloadUnchanged=\(payload == originalBody)")
            print("[FormulaComparison] payload=\(payload.debugDescription)")
        }
        for chunk in chunks {
            print("[FormulaComparison] chunk=\(chunk.chunkType), formulaImage=\(chunk.latexImage != nil), size=\(chunk.itemSize)")
        }
        // Clear between probes to avoid an earlier image hiding a payload or backend difference.
        GMarkCachedManager.shared.clearAllCache()
        let direct = GMarkLaTexRender.renderLatexSmart(from: source, style: style)
        print("[FormulaComparison] directOriginal success=\(direct.success), size=\(direct.size), error=\(direct.error?.localizedDescription ?? "none")")
        GMarkCachedManager.shared.clearAllCache()
    }

}


/// Shows the exported `txt` fields verbatim, with only a separate label for each source block.
private final class ProjectRawContentViewController: UIViewController {
    private let chapterTitle: String
    private let contents: [String]

    init(title: String, contents: [String]) {
        chapterTitle = title
        self.contents = contents
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "原始内容"
        view.backgroundColor = .systemBackground
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.text = contents.enumerated().map { index, content in
            "===== 第 \(index + 1) 块 · 原始 txt =====\n\(content)"
        }.joined(separator: "\n\n")
        textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.textColor = .label
        textView.backgroundColor = .secondarySystemBackground
        textView.isEditable = false
        textView.isSelectable = true
        textView.textContainerInset = .init(top: 16, left: 16, bottom: 24, right: 16)
        textView.accessibilityLabel = "\(chapterTitle) 原始内容"
        view.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            textView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}


/// Variants are derived from the exported source. The book resource is never rewritten.
private final class ProjectFormulaComparisonController: UITableViewController {
    private let cases: [ProjectBookChapter]

    init(source: String) throws {
        guard let tag = source.range(of: #"\tag{4.1}"#),
              let opening = source.range(of: "$$", options: .backwards, range: source.startIndex..<tag.lowerBound),
              let closing = source.range(of: "$$", range: tag.upperBound..<source.endIndex) else {
            throw NSError(domain: "FormulaComparison", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "未找到第 20 章的公式 (4.1)。"])
        }
        let original = String(source[opening.lowerBound..<closing.upperBound])
        let withoutTag = original.replacingOccurrences(of: #"\tag{4.1}"#, with: "")
        let singleLine = original.replacingOccurrences(of: "\n", with: " ")
        let body = String(original.dropFirst(2).dropLast(2))
        let inputs: [(String, String)] = [
            ("简单公式 · 单美元", "$x^2$"),
            ("简单公式 · 双美元同一行", "$$x^2$$"),
            ("简单公式 · 双美元换行", "$$\nx^2\n$$"),
            ("公式 (4.1) · 原文", original),
            ("公式 (4.1) · 仅去掉编号", withoutTag),
            ("公式 (4.1) · 仅换行改为空格", singleLine),
            ("公式 (4.1) · 仅双美元改单美元", "$" + body + "$"),
            ("编号 · x² 加编号", #"$$x^2 \tag{4.1}$$"#),
            ("文字 · 英文 text", #"$$A \text{ event count}$$"#),
            ("文字 · 中文 text", #"$$A \text{ 包含的基本事件数}$$"#),
            ("集合 · 显示花括号", #"$$P(\{e_i\})$$"#),
            ("集合 · 普通分组括号", #"$$P({e_i})$$"#),
            ("组合 · 中文加编号", #"$$A \text{ 包含的基本事件数} \tag{4.1}$$"#),
            ("排版 · 行内随正文", #"前文 $\sum_{i=1}^n i=\frac{n(n+1)}{2}$ 后文，仍在同一段。"#),
            ("排版 · 双美元独立成块", #"前文。$$\sum_{i=1}^n i=\frac{n(n+1)}{2}$$后文。"#),
            ("排版 · 连续两个公式块", #"前文。$$x^2$$$$y^2$$后文。"#),
            ("排版 · 超宽行内", "前文 $" + String(withoutTag.dropFirst(2).dropLast(2)) + "$ 后文。"),
            ("排版 · 超宽块级", "前文。" + original + "后文。"),
            ("排版 · 表格内两种公式", "| 类型 | 内容 |\n| --- | --- |\n| 行内 | 前 $x^2$ 后 |\n| 块级 | 前 $$x^2$$ 后 |"),
            ("排版 · 列表与引用", "- 前 $$x^2$$ 后\n\n> 前 $$y^2$$ 后")
        ]
        cases = inputs.enumerated().map {
            ProjectBookChapter(position: $0.offset + 1, title: $0.element.0, contents: [$0.element.1])
        }
        super.init(style: .plain)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "第20章 · 公式对照"
        navigationItem.largeTitleDisplayMode = .never
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 60
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { cases.count }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "formulaCase")
            ?? UITableViewCell(style: .default, reuseIdentifier: "formulaCase")
        cell.textLabel?.text = "\(indexPath.row + 1). \(cases[indexPath.row].title)"
        cell.textLabel?.numberOfLines = 0
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        navigationController?.pushViewController(
            ProjectChapterRenderController(chapter: cases[indexPath.row], diagnoseFormula: indexPath.row < 13), animated: true
        )
    }
}


/// Show the actual images, because a successful image result can still omit glyphs.
private final class ProjectFormulaBackendController: UIViewController {
    private let source: String
    private let stack = UIStackView()

    init(source: String) {
        self.source = source
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "原文 / 解析后 · 后端对照"
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = .systemBackground
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -16),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -32)
        ])
        addText("同一公式分别直接交给 SwiftMath 和 SVG 路径。图片可左右滚动，请核对中文、花括号和编号是否完整。")
        let original = GMarkLaTexRender.trimBrackets(from: source)
        addPair(name: "原文", body: original, mode: GMarkFormulaMode.detect(source))
        let nodes = GMarkParser().parseMarkdownToMarkups(markdown: source)
        for (index, node) in nodes.enumerated() {
            var visitor = GMarkupStringifier()
            let raw = visitor.visit(node)
            let payload = GMarkLaTexRender.trimBrackets(from: raw)
            addPair(name: "解析后节点 \(index + 1)（\(type(of: node))）", body: payload, mode: GMarkFormulaMode.detect(raw))
        }
        GMarkCachedManager.shared.clearAllCache()
    }

    private func addPair(name: String, body: String, mode: GMarkFormulaMode) {
        addText("\(name)\n\(body)")
        for preferSVG in [false, true] {
            let backend = preferSVG ? "SVG" : "SwiftMath"
            // renderLatexImage selects one backend; unlike .fast, it does not auto-fallback.
            GMarkCachedManager.shared.clearAllCache()
            let result = GMarkLaTexRender.renderLatexImage(body, fontSize: 16,
                                                         textColor: .black, preferSVG: preferSVG, mode: mode)
            let status = result.success ? "已出图（需核对内容）" : "失败"
            let detail = "\(name) / \(backend)：\(status)，尺寸 \(result.size)，错误：\(result.error?.localizedDescription ?? "无")"
            addText(detail)
            print("[FormulaBackend] \(detail)")
            print("[FormulaBackend] mode=\(mode.rawValue) input=\(body.debugDescription)")
            if let image = result.image { addImage(image) }
        }
    }

    private func addText(_ text: String) {
        let label = UILabel()
        label.text = text
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 14)
        stack.addArrangedSubview(label)
    }

    private func addImage(_ image: UIImage) {
        let scroll = UIScrollView()
        scroll.backgroundColor = .white
        scroll.heightAnchor.constraint(equalToConstant: max(44, image.size.height + 16)).isActive = true
        let imageView = UIImageView(image: image)
        imageView.frame = CGRect(origin: CGPoint(x: 8, y: 8), size: image.size)
        scroll.addSubview(imageView)
        scroll.contentSize = CGSize(width: image.size.width + 16, height: image.size.height + 16)
        stack.addArrangedSubview(scroll)
    }
}
