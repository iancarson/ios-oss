import KsApi
import Library
import Prelude
import ReactiveSwift
import UIKit

internal final class ActivitiesViewController: UITableViewController {
  fileprivate let viewModel: ActivitiesViewModelType = ActivitiesViewModel()
  fileprivate let dataSource = ActivitiesDataSource()
  private var sessionEndedObserver: Any?
  private var sessionStartedObserver: Any?
  private var userUpdatedObserver: Any?

  fileprivate var emptyStatesController: EmptyStatesViewController?

  internal static func instantiate() -> ActivitiesViewController {
    return Storyboard.Activity.instantiate(ActivitiesViewController.self)
  }

  internal required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)

    self.sessionStartedObserver = NotificationCenter.default
      .addObserver(forName: .ksr_sessionStarted, object: nil, queue: nil) { [weak self] _ in
        self?.viewModel.inputs.userSessionStarted()
      }

    self.sessionEndedObserver = NotificationCenter.default
      .addObserver(forName: .ksr_sessionEnded, object: nil, queue: nil) { [weak self] _ in
        self?.viewModel.inputs.userSessionEnded()
      }

    self.userUpdatedObserver = NotificationCenter.default
      .addObserver(forName: Notification.Name.ksr_userUpdated, object: nil, queue: nil) { [weak self] _ in
        self?.viewModel.inputs.currentUserUpdated()
      }
  }

  deinit {
    [
      self.sessionEndedObserver,
      self.sessionStartedObserver,
      self.userUpdatedObserver
    ]
    .compact()
    .forEach(NotificationCenter.default.removeObserver)
  }

  internal override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()

    self.emptyStatesController?.view.frame = self.view.bounds
  }

  internal override func viewDidLoad() {
    super.viewDidLoad()

    self.tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: Styles.gridHalf(3)))
    self.tableView.registerCellClass(ActivityErroredBackingsCell.self)
    self.tableView.dataSource = self.dataSource

    let emptyVC = EmptyStatesViewController.configuredWith(emptyState: .activity)
    self.emptyStatesController = emptyVC
    emptyVC.delegate = self
    self.addChild(emptyVC)
    self.view.addSubview(emptyVC.view)
    emptyVC.didMove(toParent: self)

    self.viewModel.inputs.viewDidLoad()
  }

  internal override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    self.viewModel.inputs.viewWillAppear(animated: animated)
  }

  internal override func bindStyles() {
    super.bindStyles()

    _ = self
      |> baseTableControllerStyle(estimatedRowHeight: 200.0)

    _ = self.navigationItem
      |> UINavigationItem.lens.title %~ { _ in Strings.activity_navigation_title_activity() }
  }

  internal override func bindViewModel() {
    super.bindViewModel()

    self.viewModel.outputs.activities
      .observeForUI()
      .observeValues { [weak self] activities in
        self?.dataSource.load(activities: activities)
        self?.tableView.reloadData()
      }

    self.viewModel.outputs.erroredBackings
      .observeForUI()
      .observeValues { [weak self] backings in
        self?.dataSource.load(erroredBackings: backings)
        self?.tableView.reloadData()
      }

    self.viewModel.outputs.showFacebookConnectSection
      .observeForUI()
      .observeValues { [weak self] source, shouldShow in
        self?.dataSource.facebookConnect(source: source, visible: shouldShow)
        self?.tableView.reloadData()
      }

    self.viewModel.outputs.showFindFriendsSection
      .observeForUI()
      .observeValues { [weak self] source, shouldShow in
        self?.dataSource.findFriends(source: source, visible: shouldShow)
        self?.tableView.reloadData()
      }

    self.viewModel.outputs.showEmptyStateIsLoggedIn
      .observeForUI()
      .observeValues { [weak self] _ in
        self?.tableView.bounces = false
        if let emptyVC = self?.emptyStatesController {
          self?.emptyStatesController?.view.isHidden = false
          self?.view.bringSubviewToFront(emptyVC.view)
        }
      }

    self.viewModel.outputs.hideEmptyState
      .observeForUI()
      .observeValues { [weak self] in
        self?.tableView.bounces = true
        self?.emptyStatesController?.view.isHidden = true
      }

    self.refreshControl?.rac.refreshing = self.viewModel.outputs.isRefreshing

    self.viewModel.outputs.goToProject
      .observeForControllerAction()
      .observeValues { [weak self] project, refTag in
        self?.present(project: project, refTag: refTag)
      }

    self.viewModel.outputs.deleteFacebookConnectSection
      .observeForUI()
      .observeValues { [weak self] in
        self?.deleteFacebookSection()
      }

    self.viewModel.outputs.deleteFindFriendsSection
      .observeForUI()
      .observeValues { [weak self] in
        self?.deleteFindFriendsSection()
      }

    self.viewModel.outputs.goToFriends
      .observeForControllerAction()
      .observeValues { [weak self] source in
        self?.goToFriends(source: source)
      }

    self.viewModel.outputs.showFacebookConnectErrorAlert
      .observeForControllerAction()
      .observeValues { [weak self] error in
        self?.present(
          UIAlertController.alertController(forError: error),
          animated: true,
          completion: nil
        )
      }

    self.viewModel.outputs.unansweredSurveys
      .observeForUI()
      .observeValues { [weak self] in
        self?.dataSource.load(surveys: $0)
        self?.tableView.reloadData()
      }

    self.viewModel.outputs.goToSurveyResponse
      .observeForControllerAction()
      .observeValues { [weak self] surveyResponse in
        self?.goToSurveyResponse(surveyResponse: surveyResponse)
      }

    self.viewModel.outputs.goToUpdate
      .observeForControllerAction()
      .observeValues { [weak self] project, update in
        self?.goToUpdate(project: project, update: update)
      }

    self.viewModel.outputs.goToManagePledge
      .observeForControllerAction()
      .observeValues { [weak self] params in
        self?.goToManagePledge(params: params)
      }

    self.viewModel.outputs.clearBadgeValue
      .observeForUI()
      .observeValues { [weak self] in
        self?.parent?.tabBarItem.badgeValue = nil
      }

    self.viewModel.outputs.updateUserInEnvironment
      .observeValues { user in
        AppEnvironment.updateCurrentUser(user)
        NotificationCenter.default.post(.init(name: .ksr_userUpdated))
      }
  }

  internal override func tableView(
    _: UITableView,
    willDisplay cell: UITableViewCell,
    forRowAt indexPath: IndexPath
  ) {
    if let cell = cell as? ActivityUpdateCell, cell.delegate == nil {
      cell.delegate = self
    } else if let cell = cell as? FindFriendsFacebookConnectCell, cell.delegate == nil {
      cell.delegate = self
    } else if let cell = cell as? FindFriendsHeaderCell, cell.delegate == nil {
      cell.delegate = self
    } else if let cell = cell as? ActivitySurveyResponseCell, cell.delegate == nil {
      cell.delegate = self
    } else if let cell = cell as? ActivityErroredBackingsCell, cell.delegate == nil {
      cell.delegate = self
    }

    self.viewModel.inputs.willDisplayRow(
      self.dataSource.itemIndexAt(indexPath),
      outOf: self.dataSource.numberOfItems()
    )
  }

  internal override func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
    guard let activity = self.dataSource[indexPath] as? Activity else {
      return
    }

    self.viewModel.inputs.tappedActivity(activity)
  }

  @IBAction internal func refresh() {
    self.viewModel.inputs.refresh()
  }

  fileprivate func present(project: Project, refTag: RefTag) {
    guard featureNavigationSelectorProjectPageIsEnabled() else {
      let vc = ProjectNavigatorViewController.configuredWith(project: project, refTag: refTag)
      if UIDevice.current.userInterfaceIdiom == .pad {
        vc.modalPresentationStyle = .fullScreen
      }
      self.present(vc, animated: true, completion: nil)

      return
    }

    let projectParam = Either<Project, Param>(left: project)
    let vc = ProjectPageViewController.configuredWith(
      projectOrParam: projectParam,
      refTag: refTag
    )

    let nav = NavigationController(rootViewController: vc)
    nav.modalPresentationStyle = self.traitCollection.userInterfaceIdiom == .pad ? .fullScreen : .formSheet

    self.present(nav, animated: true, completion: nil)
  }

  fileprivate func goToFriends(source _: FriendsSource) {
    let vc = FindFriendsViewController.configuredWith(source: .activity)
    self.navigationController?.pushViewController(vc, animated: true)
  }

  fileprivate func goToSurveyResponse(surveyResponse: SurveyResponse) {
    let vc = SurveyResponseViewController.configuredWith(surveyResponse: surveyResponse)
    vc.delegate = self

    let nav = UINavigationController(rootViewController: vc)
    nav.modalPresentationStyle = .formSheet

    self.present(nav, animated: true, completion: nil)
  }

  fileprivate func goToUpdate(project: Project, update: Update) {
    let vc = UpdateViewController.configuredWith(project: project, update: update, context: .activity)
    self.navigationController?.pushViewController(vc, animated: true)
  }

  fileprivate func goToManagePledge(params: ManagePledgeViewParamConfigData) {
    let vc = ManagePledgeViewController.controller(with: params, delegate: self)
    self.present(vc, animated: true)
  }

  fileprivate func deleteFacebookSection() {
    self.tableView.beginUpdates()

    self.tableView.deleteRows(at: self.dataSource.removeFacebookConnectRows(), with: .top)

    self.tableView.endUpdates()
  }

  fileprivate func deleteFindFriendsSection() {
    self.tableView.beginUpdates()

    self.tableView.deleteRows(at: self.dataSource.removeFindFriendsRows(), with: .top)

    self.tableView.endUpdates()
  }
}

// MARK: - ActivityUpdateCellDelegate

extension ActivitiesViewController: ActivityUpdateCellDelegate {
  internal func activityUpdateCellTappedProjectImage(activity: Activity) {
    self.viewModel.inputs.activityUpdateCellTappedProjectImage(activity: activity)
  }
}

// MARK: - FindFriendsHeaderCellDelegate

extension ActivitiesViewController: FindFriendsHeaderCellDelegate {
  func findFriendsHeaderCellDismissHeader() {
    self.viewModel.inputs.findFriendsHeaderCellDismissHeader()
  }

  func findFriendsHeaderCellGoToFriends() {
    self.viewModel.inputs.findFriendsHeaderCellGoToFriends()
  }
}

// MARK: - FindFriendsFacebookConnectCellDelegate

extension ActivitiesViewController: FindFriendsFacebookConnectCellDelegate {
  func findFriendsFacebookConnectCellDidFacebookConnectUser() {
    self.viewModel.inputs.findFriendsFacebookConnectCellDidFacebookConnectUser()
  }

  func findFriendsFacebookConnectCellDidDismissHeader() {
    self.viewModel.inputs.findFriendsFacebookConnectCellDidDismissHeader()
  }

  func findFriendsFacebookConnectCellShowErrorAlert(_ alert: AlertError) {
    self.viewModel.inputs.findFriendsFacebookConnectCellShowErrorAlert(alert)
  }
}

// MARK: - ActivitySurveyResponseCellDelegate

extension ActivitiesViewController: ActivitySurveyResponseCellDelegate {
  func activityTappedRespondNow(forSurveyResponse surveyResponse: SurveyResponse) {
    self.viewModel.inputs.tappedRespondNow(forSurveyResponse: surveyResponse)
  }
}

// MARK: - EmptyStatesViewControllerDelegate

extension ActivitiesViewController: EmptyStatesViewControllerDelegate {
  func emptyStatesViewController(
    _: EmptyStatesViewController,
    goToDiscoveryWithParams params: DiscoveryParams?
  ) {
    guard let tabController = self.tabBarController as? RootTabBarViewController else { return }
    tabController.switchToDiscovery(params: params)
  }

  func emptyStatesViewControllerGoToFriends() {}
}

extension ActivitiesViewController: SurveyResponseViewControllerDelegate {
  func surveyResponseViewControllerDismissed() {
    self.viewModel.inputs.surveyResponseViewControllerDismissed()
  }
}

extension ActivitiesViewController: TabBarControllerScrollable {}

// MARK: - ErroredBackingViewDelegate

extension ActivitiesViewController: ErroredBackingViewDelegate {
  func erroredBackingViewDidTapManage(_: ErroredBackingView, backing: ProjectAndBackingEnvelope) {
    self.viewModel.inputs.erroredBackingViewDidTapManage(with: backing)
  }
}

// MARK: - ManagePledgeViewControllerDelegate

extension ActivitiesViewController: ManagePledgeViewControllerDelegate {
  func managePledgeViewController(
    _: ManagePledgeViewController,
    managePledgeViewControllerFinishedWithMessage _: String?
  ) {
    self.viewModel.inputs.managePledgeViewControllerDidFinish()
  }
}
