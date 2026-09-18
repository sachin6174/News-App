import UIKit

/// Lets the reader choose which topics to follow and whether breaking-news
/// alerts are on. Presented modally from the main feed screen's topic bar.
final class TopicsViewController: UITableViewController {
    private let viewModel: NewsListViewModel
    private let notificationSwitch = UISwitch()

    private enum Section: Int, CaseIterable {
        case topics
        case notifications
    }

    init(viewModel: NewsListViewModel) {
        self.viewModel = viewModel
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        fatalError("TopicsViewController is created in Swift, not a storyboard.")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.text("topics.title")
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(doneTapped)
        )
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "topic.cell")

        notificationSwitch.isOn = NotificationScheduler.isBreakingNewsEnabled
        notificationSwitch.accessibilityIdentifier = "topics.notificationsSwitch"
        notificationSwitch.addTarget(self, action: #selector(notificationSwitchChanged), for: .valueChanged)
    }

    @objc private func doneTapped() {
        dismiss(animated: true)
    }

    /// Turning the switch on asks for notification permission right here, with
    /// this screen's context, instead of prompting automatically at launch.
    /// Turning it off never touches system permission — it just stops the app
    /// from scheduling alerts.
    @objc private func notificationSwitchChanged() {
        guard notificationSwitch.isOn else {
            NotificationScheduler.isBreakingNewsEnabled = false
            return
        }
        NotificationScheduler.shared.requestAuthorizationIfNeeded { [weak self] granted in
            NotificationScheduler.isBreakingNewsEnabled = granted
            self?.notificationSwitch.setOn(granted, animated: true)
        }
    }

    // MARK: UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .topics: return Topic.allCases.count
        case .notifications: return 1
        case .none: return 0
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .topics: return L10n.text("topics.section.follow")
        case .notifications: return L10n.text("topics.section.alerts")
        case .none: return nil
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        Section(rawValue: section) == .notifications ? L10n.text("topics.alerts.footer") : nil
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "topic.cell", for: indexPath)
        var configuration = cell.defaultContentConfiguration()

        switch Section(rawValue: indexPath.section) {
        case .topics:
            let topic = Topic.allCases[indexPath.row]
            let isFollowed = viewModel.followedTopics.contains(topic)
            configuration.text = topic.displayName
            configuration.image = UIImage(systemName: topic.symbolName)
            cell.contentConfiguration = configuration
            cell.accessoryType = isFollowed ? .checkmark : .none
            cell.accessibilityIdentifier = "topic.cell.\(topic.rawValue)"
            cell.accessibilityTraits = isFollowed ? [.button, .selected] : .button
        case .notifications:
            configuration.text = L10n.text("topics.alerts.toggle")
            cell.contentConfiguration = configuration
            cell.accessoryView = notificationSwitch
            cell.selectionStyle = .none
        case .none:
            break
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard Section(rawValue: indexPath.section) == .topics else { return }

        let topic = Topic.allCases[indexPath.row]
        let isNowFollowed = !viewModel.followedTopics.contains(topic)
        viewModel.setTopic(topic, followed: isNowFollowed)
        tableView.reloadRows(at: [indexPath], with: .automatic)
    }
}
