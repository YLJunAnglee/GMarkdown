import GMarkdown
import UIKit

private enum NativeTableAPIFixture: String, CaseIterable {
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

    static func fromProcessArguments(_ arguments: [String]) -> NativeTableAPIFixture? {
        guard let flagIndex = arguments.firstIndex(of: "--native-table-api"),
              arguments.indices.contains(flagIndex + 1) else {
            return nil
        }
        return NativeTableAPIFixture(rawValue: arguments[flagIndex + 1].uppercased())
    }
}

final class NativeTableAPIViewController: UIViewController {
    private let fixtureControl = UISegmentedControl(items: NativeTableAPIFixture.allCases.map(\.rawValue))
    private let resultLabel = UILabel()
    private let tableView = NativeMarkdownTableView()
    private var tableHeightConstraint: NSLayoutConstraint!
    private var selectedFixture: NativeTableAPIFixture = .a
    private var lastRenderedWidth: CGFloat = 0
    private var renderTask: NativeMarkdownTableRenderTask?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        renderSelectedFixtureIfNeeded(force: true)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        renderSelectedFixtureIfNeeded(force: false)
    }

    func selectFixture(_ fixture: String) {
        guard let fixture = NativeTableAPIFixture(rawValue: fixture.uppercased()) else { return }
        selectedFixture = fixture
        guard isViewLoaded else { return }
        fixtureControl.selectedSegmentIndex = NativeTableAPIFixture.allCases.firstIndex(of: fixture) ?? 0
        renderSelectedFixtureIfNeeded(force: true)
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Native TABLE API"

        fixtureControl.selectedSegmentIndex = NativeTableAPIFixture.allCases.firstIndex(of: selectedFixture) ?? 0
        fixtureControl.addTarget(self, action: #selector(fixtureChanged), for: .valueChanged)

        resultLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        resultLabel.textColor = .secondaryLabel
        resultLabel.numberOfLines = 0
        resultLabel.text = "Waiting for render…"

        let resultPanel = UIView()
        resultPanel.backgroundColor = .secondarySystemBackground
        resultPanel.layer.cornerRadius = 10
        resultPanel.addSubview(resultLabel)

        view.addSubview(fixtureControl)
        view.addSubview(resultPanel)
        view.addSubview(tableView)

        fixtureControl.translatesAutoresizingMaskIntoConstraints = false
        resultPanel.translatesAutoresizingMaskIntoConstraints = false
        resultLabel.translatesAutoresizingMaskIntoConstraints = false
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableHeightConstraint = tableView.heightAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            fixtureControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            fixtureControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            fixtureControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            resultPanel.topAnchor.constraint(equalTo: fixtureControl.bottomAnchor, constant: 10),
            resultPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            resultPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            resultLabel.topAnchor.constraint(equalTo: resultPanel.topAnchor, constant: 10),
            resultLabel.leadingAnchor.constraint(equalTo: resultPanel.leadingAnchor, constant: 12),
            resultLabel.trailingAnchor.constraint(equalTo: resultPanel.trailingAnchor, constant: -12),
            resultLabel.bottomAnchor.constraint(equalTo: resultPanel.bottomAnchor, constant: -10),

            tableView.topAnchor.constraint(equalTo: resultPanel.bottomAnchor, constant: 16),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            tableHeightConstraint,
        ])
    }

    @objc private func fixtureChanged() {
        let fixtures = NativeTableAPIFixture.allCases
        guard fixtures.indices.contains(fixtureControl.selectedSegmentIndex) else { return }
        selectedFixture = fixtures[fixtureControl.selectedSegmentIndex]
        renderSelectedFixtureIfNeeded(force: true)
    }

    private func renderSelectedFixtureIfNeeded(force: Bool) {
        let width = tableView.bounds.width
        guard width > 0, force || abs(width - lastRenderedWidth) > 1 else { return }
        lastRenderedWidth = width

        guard let markdown = markdown(for: selectedFixture) else {
            renderTask?.cancel()
            tableView.clear()
            tableHeightConstraint.constant = 0
            resultLabel.text = "Fixture \(selectedFixture.rawValue) could not be loaded."
            return
        }

        let fixture = selectedFixture
        renderTask = tableView.renderAsync(markdown: markdown, containerWidth: width) { [weak self] result in
            self?.apply(result, fixture: fixture)
        }
    }

    private func apply(_ result: NativeMarkdownTableRenderResult, fixture: NativeTableAPIFixture) {
        switch result {
        case let .success(metrics):
            tableHeightConstraint.constant = metrics.requiredSize.height
            let performance = metrics.performance
            resultLabel.text = [
                "Fixture \(fixture.rawValue) • public NativeMarkdownTableView",
                "Columns \(metrics.columnCount) • body rows \(metrics.bodyRowCount)",
                "Required size \(String(format: "%.1f", metrics.requiredSize.width)) × \(String(format: "%.1f", metrics.requiredSize.height))pt",
                "Cache \(performance.cacheHit ? "hit" : "miss") • parse \(milliseconds(performance.parseDuration))ms • formula \(milliseconds(performance.formulaRenderDuration))ms",
                "Layout \(milliseconds(performance.layoutDuration))ms • total \(milliseconds(performance.totalDuration))ms • ΔH \(heightDelta(metrics.heightDelta))",
                "Warnings \(metrics.warnings.count) • cancellable reuse-safe task",
            ].joined(separator: "\n")
        case let .failure(failure):
            tableHeightConstraint.constant = 0
            resultLabel.text = "Fixture \(fixture.rawValue) failed: \(failure)"
        }
    }

    private func milliseconds(_ duration: TimeInterval) -> String {
        String(format: "%.2f", duration * 1_000)
    }

    private func heightDelta(_ value: CGFloat?) -> String {
        guard let value else { return "first" }
        return String(format: "%+.1fpt", value)
    }

    private func markdown(for fixture: NativeTableAPIFixture) -> String? {
        guard let url = Bundle.main.url(forResource: fixture.resourceName, withExtension: "md"),
              let markdown = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        guard fixture == .c else {
            return markdown
        }

        let marker = "## Known long LaTeX issue"
        guard let markerRange = markdown.range(of: marker) else { return nil }
        let remainder = markdown[markerRange.upperBound...]
        let end = remainder.range(of: "\n## ")?.lowerBound ?? markdown.endIndex
        return String(markdown[markerRange.upperBound..<end])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension NativeTableAPIViewController {
    static func fixtureFromProcessArguments(_ arguments: [String]) -> String? {
        NativeTableAPIFixture.fromProcessArguments(arguments)?.rawValue
    }
}
