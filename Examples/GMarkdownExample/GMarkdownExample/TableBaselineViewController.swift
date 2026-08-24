import GMarkdown
import QuartzCore
import UIKit

enum TableBaselineFixture: String, CaseIterable {
    case a = "A"
    case b = "B"
    case c = "C"

    var resourceName: String {
        switch self {
        case .a: return "table_baseline_a"
        case .b: return "table_baseline_b"
        case .c: return "table_baseline_c"
        }
    }

    static func fromProcessArguments(_ arguments: [String]) -> TableBaselineFixture? {
        guard let flagIndex = arguments.firstIndex(of: "--table-baseline"),
              arguments.indices.contains(flagIndex + 1) else {
            return nil
        }
        return TableBaselineFixture(rawValue: arguments[flagIndex + 1].uppercased())
    }
}

final class TableBaselineViewController: UIViewController {
    private let markdownView = GMarkdownMultiView()
    private let metricsLabel = UILabel()
    private let fixtureControl = UISegmentedControl(items: TableBaselineFixture.allCases.map(\.rawValue))
    private var selectedFixture: TableBaselineFixture = .a
    private var renderGeneration = 0
    private var didLoadInitialFixture = false
    private var lastContainerWidth: CGFloat = 0
    private let shouldFocusBottom = ProcessInfo.processInfo.arguments.contains("--focus-bottom")
    private let shouldFocusRight = ProcessInfo.processInfo.arguments.contains("--focus-right")

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didLoadInitialFixture else { return }
        didLoadInitialFixture = true
        loadSelectedFixture()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = markdownView.bounds.width
        guard didLoadInitialFixture, width > 0, abs(width - lastContainerWidth) > 1 else { return }
        loadSelectedFixture()
    }

    func selectFixture(_ fixture: TableBaselineFixture) {
        selectedFixture = fixture
        guard isViewLoaded else { return }
        fixtureControl.selectedSegmentIndex = TableBaselineFixture.allCases.firstIndex(of: fixture) ?? 0
        if didLoadInitialFixture {
            loadSelectedFixture()
        }
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "TABLE Baseline"

        fixtureControl.selectedSegmentIndex = TableBaselineFixture.allCases.firstIndex(of: selectedFixture) ?? 0
        fixtureControl.addTarget(self, action: #selector(fixtureChanged), for: .valueChanged)

        metricsLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        metricsLabel.textColor = .secondaryLabel
        metricsLabel.numberOfLines = 0
        metricsLabel.text = "Waiting for baseline render…"

        let metricsPanel = UIView()
        metricsPanel.backgroundColor = .secondarySystemBackground
        metricsPanel.layer.cornerRadius = 10
        metricsPanel.addSubview(metricsLabel)

        view.addSubview(fixtureControl)
        view.addSubview(metricsPanel)
        view.addSubview(markdownView)

        fixtureControl.translatesAutoresizingMaskIntoConstraints = false
        metricsPanel.translatesAutoresizingMaskIntoConstraints = false
        metricsLabel.translatesAutoresizingMaskIntoConstraints = false
        markdownView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            fixtureControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            fixtureControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            fixtureControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            metricsPanel.topAnchor.constraint(equalTo: fixtureControl.bottomAnchor, constant: 10),
            metricsPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            metricsPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            metricsLabel.topAnchor.constraint(equalTo: metricsPanel.topAnchor, constant: 10),
            metricsLabel.leadingAnchor.constraint(equalTo: metricsPanel.leadingAnchor, constant: 12),
            metricsLabel.trailingAnchor.constraint(equalTo: metricsPanel.trailingAnchor, constant: -12),
            metricsLabel.bottomAnchor.constraint(equalTo: metricsPanel.bottomAnchor, constant: -10),

            markdownView.topAnchor.constraint(equalTo: metricsPanel.bottomAnchor, constant: 10),
            markdownView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            markdownView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            markdownView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .refresh,
            target: self,
            action: #selector(reloadBaseline)
        )
    }

    @objc private func fixtureChanged() {
        let fixtures = TableBaselineFixture.allCases
        guard fixtures.indices.contains(fixtureControl.selectedSegmentIndex) else { return }
        selectedFixture = fixtures[fixtureControl.selectedSegmentIndex]
        loadSelectedFixture()
    }

    @objc private func reloadBaseline() {
        loadSelectedFixture()
    }

    private func loadSelectedFixture() {
        let containerWidth = markdownView.bounds.width
        guard containerWidth > 0 else { return }
        lastContainerWidth = containerWidth
        renderGeneration += 1
        let generation = renderGeneration
        let fixture = selectedFixture

        guard let url = Bundle.main.url(forResource: fixture.resourceName, withExtension: "md"),
              let markdown = try? String(contentsOf: url, encoding: .utf8) else {
            metricsLabel.text = "Fixture \(fixture.rawValue) could not be loaded."
            return
        }

        metricsLabel.text = "Fixture \(fixture.rawValue) • parsing…"
        let totalStart = CACurrentMediaTime()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var style = MarkdownStyle.defaultStyle()
            style.maxContainerWidth = containerWidth
            let generator = GMarkChunkGenerator()
            generator.style = style
            generator.addLaTexHandler()
            let processor = GMarkProcessor(parser: GMarkParser(), chunkGenerator: generator)
            let parseStart = CACurrentMediaTime()
            let chunks = processor.process(markdown: markdown)
            let parseMilliseconds = (CACurrentMediaTime() - parseStart) * 1_000

            DispatchQueue.main.async {
                guard let self, generation == self.renderGeneration else { return }
                self.markdownView.updateMarkdown(chunks)
                self.markdownView.layoutIfNeeded()
                let collectionView = self.descendantCollectionView(in: self.markdownView)
                collectionView?.layoutIfNeeded()
                let firstLayoutMilliseconds = (CACurrentMediaTime() - totalStart) * 1_000
                let tableChunks = chunks.filter { $0.chunkType == .Table }
                let tableHeights = tableChunks.map { $0.itemSize.height }
                self.sampleHeights(
                    fixture: fixture,
                    generation: generation,
                    parseMilliseconds: parseMilliseconds,
                    firstLayoutMilliseconds: firstLayoutMilliseconds,
                    chunkCount: chunks.count,
                    tableHeights: tableHeights,
                    collectionView: collectionView
                )
            }
        }
    }

    private func sampleHeights(
        fixture: TableBaselineFixture,
        generation: Int,
        parseMilliseconds: Double,
        firstLayoutMilliseconds: Double,
        chunkCount: Int,
        tableHeights: [CGFloat],
        collectionView: UICollectionView?
    ) {
        var samples: [(milliseconds: Int, height: CGFloat)] = []
        let delays: [(milliseconds: Int, seconds: TimeInterval)] = [(0, 0), (100, 0.1), (500, 0.5)]

        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay.seconds) { [weak self, weak collectionView] in
                guard let self, generation == self.renderGeneration else { return }
                collectionView?.layoutIfNeeded()
                samples.append((delay.milliseconds, collectionView?.contentSize.height ?? 0))
                guard samples.count == delays.count else { return }

                let heightsText = samples
                    .sorted { $0.milliseconds < $1.milliseconds }
                    .map { "\($0.milliseconds)ms=\(String(format: "%.1f", $0.height))pt" }
                    .joined(separator: " • ")
                let tableHeightText = tableHeights.isEmpty
                    ? "none"
                    : tableHeights.map { String(format: "%.1f", $0) }.joined(separator: ", ") + "pt"
                let report = [
                    "Fixture \(fixture.rawValue) • width \(String(format: "%.1f", self.markdownView.bounds.width))pt",
                    "Parse \(String(format: "%.2f", parseMilliseconds))ms • first layout \(String(format: "%.2f", firstLayoutMilliseconds))ms",
                    "Chunks \(chunkCount) • tables \(tableHeights.count) • table heights \(tableHeightText)",
                    "Content height: \(heightsText)",
                ].joined(separator: "\n")
                self.metricsLabel.text = report
                print("[TableBaseline] \(report.replacingOccurrences(of: "\n", with: " | "))")
                self.applyRequestedFocus(collectionView: collectionView)
            }
        }
    }

    private func applyRequestedFocus(collectionView: UICollectionView?) {
        if shouldFocusBottom, let collectionView {
            let maximumOffset = max(
                0,
                collectionView.contentSize.height - collectionView.bounds.height + collectionView.adjustedContentInset.bottom
            )
            collectionView.setContentOffset(CGPoint(x: 0, y: maximumOffset), animated: false)
        }

        if shouldFocusRight,
           let horizontalScrollView = descendantScrollViews(in: markdownView).first(where: {
               $0 !== collectionView && $0.isScrollEnabled && $0.contentSize.width > $0.bounds.width + 1
           }) {
            let maximumOffset = max(
                0,
                horizontalScrollView.contentSize.width - horizontalScrollView.bounds.width + horizontalScrollView.adjustedContentInset.right
            )
            horizontalScrollView.setContentOffset(CGPoint(x: maximumOffset, y: 0), animated: false)
        }
    }

    private func descendantCollectionView(in view: UIView) -> UICollectionView? {
        if let collectionView = view as? UICollectionView {
            return collectionView
        }
        for subview in view.subviews {
            if let collectionView = descendantCollectionView(in: subview) {
                return collectionView
            }
        }
        return nil
    }

    private func descendantScrollViews(in view: UIView) -> [UIScrollView] {
        var scrollViews = view.subviews.compactMap { $0 as? UIScrollView }
        for subview in view.subviews {
            scrollViews.append(contentsOf: descendantScrollViews(in: subview))
        }
        return scrollViews
    }
}
