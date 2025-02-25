import KsApi
import Library
import Prelude
import UIKit

internal final class ProjectActivitiesViewController: UITableViewController {
  fileprivate let viewModel: ProjectActivitiesViewModelType = ProjectActivitiesViewModel()
  fileprivate let dataSource = ProjectActivitiesDataSource()

  internal static func configuredWith(project: Project) -> ProjectActivitiesViewController {
    let vc = Storyboard.ProjectActivity.instantiate(ProjectActivitiesViewController.self)
    vc.viewModel.inputs.configureWith(project)
    return vc
  }

  internal override func viewDidLoad() {
    super.viewDidLoad()

    self.tableView.dataSource = self.dataSource

    self.viewModel.inputs.viewDidLoad()
  }

  internal override func bindViewModel() {
    super.bindViewModel()

    self.viewModel.outputs.projectActivityData
      .observeForUI()
      .observeValues { [weak self] projectActivityData in
        self?.dataSource.load(projectActivityData: projectActivityData)
        self?.tableView.reloadData()
      }

    self.viewModel.outputs.goTo
      .observeForControllerAction()
      .observeValues { [weak self] goTo in
        switch goTo {
        case let .backing(params):
          self?.goToBacking(params: params)
        case let .comments(project, update):
          self?.goToComments(project: project, update: update)
        case let .project(project):
          self?.goToProject(project: project)
        case let .sendReply(project, update, comment):
          self?.goToSendReply(project: project, update: update, comment: comment)
        case let .sendMessage(backing, context):
          self?.goToSendMessage(backing: backing, context: context)
        case let .update(project, update):
          self?.goToUpdate(project: project, update: update)
        }
      }

    self.viewModel.outputs.showEmptyState
      .observeForUI()
      .observeValues { [weak self] visible in
        self?.dataSource.emptyState(visible: visible)
        self?.tableView.reloadData()
      }
  }

  internal override func bindStyles() {
    super.bindStyles()

    _ = self
      |> baseTableControllerStyle(estimatedRowHeight: 200.0)

    self.title = Strings.activity_navigation_title_activity()
  }

  internal override func tableView(
    _: UITableView,
    willDisplay cell: UITableViewCell,
    forRowAt indexPath: IndexPath
  ) {
    if let cell = cell as? ProjectActivityBackingCell, cell.delegate == nil {
      cell.delegate = self
    } else if let cell = cell as? ProjectActivityCommentCell, cell.delegate == nil {
      cell.delegate = self
    }

    self.viewModel.inputs.willDisplayRow(
      self.dataSource.itemIndexAt(indexPath),
      outOf: self.dataSource.numberOfItems()
    )
  }

  internal override func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
    guard let (activity, project) = self.dataSource.activityAndProjectAtIndexPath(indexPath) else { return }
    self.viewModel.inputs.activityAndProjectCellTapped(activity: activity, project: project)
  }

  internal func goToBacking(params: ManagePledgeViewParamConfigData) {
    let vc = ManagePledgeViewController.controller(with: params)

    if self.traitCollection.userInterfaceIdiom == .pad {
      vc.modalPresentationStyle = UIModalPresentationStyle.formSheet
    }

    self.present(vc, animated: true)
  }

  internal func goToComments(project: Project?, update: Update?) {
    let vc = commentsViewController(for: project, update: update)
    if self.traitCollection.userInterfaceIdiom == .pad {
      let nav = UINavigationController(rootViewController: vc)
      nav.modalPresentationStyle = UIModalPresentationStyle.formSheet
      self.present(nav, animated: true, completion: nil)
    } else {
      self.navigationController?.pushViewController(vc, animated: true)
    }
  }

  internal func goToProject(project: Project) {
    guard featureNavigationSelectorProjectPageIsEnabled() else {
      let vc = ProjectNavigatorViewController.configuredWith(project: project, refTag: .dashboardActivity)
      if UIDevice.current.userInterfaceIdiom == .pad {
        vc.modalPresentationStyle = .fullScreen
      }
      self.present(vc, animated: true, completion: nil)

      return
    }

    let projectParam = Either<Project, Param>(left: project)
    let vc = ProjectPageViewController.configuredWith(
      projectOrParam: projectParam,
      refTag: .dashboardActivity
    )

    let nav = NavigationController(rootViewController: vc)
    nav.modalPresentationStyle = self.traitCollection.userInterfaceIdiom == .pad ? .fullScreen : .formSheet

    self.present(nav, animated: true, completion: nil)
  }

  internal func goToSendMessage(
    backing: Backing,
    context: KSRAnalytics.MessageDialogContext
  ) {
    let vc = MessageDialogViewController.configuredWith(messageSubject: .backing(backing), context: context)
    vc.modalPresentationStyle = .formSheet
    vc.delegate = self
    self.present(
      UINavigationController(rootViewController: vc),
      animated: true,
      completion: nil
    )
  }

  internal func goToSendReply(project: Project, update: Update?, comment: ActivityComment) {
    let dialog = CommentDialogViewController
      .configuredWith(project: project, update: update, recipient: comment.author, context: .projectActivity)
    dialog.modalPresentationStyle = .formSheet
    dialog.delegate = self
    self.present(
      UINavigationController(rootViewController: dialog),
      animated: true,
      completion: nil
    )
  }

  internal func goToUpdate(project: Project, update: Update) {
    let vc = UpdateViewController.configuredWith(project: project, update: update, context: .creatorActivity)
    self.navigationController?.pushViewController(vc, animated: true)
  }
}

extension ProjectActivitiesViewController: MessageDialogViewControllerDelegate {
  internal func messageDialogWantsDismissal(_ dialog: MessageDialogViewController) {
    dialog.dismiss(animated: true, completion: nil)
  }

  internal func messageDialog(_: MessageDialogViewController, postedMessage _: Message) {}
}

extension ProjectActivitiesViewController: ProjectActivityBackingCellDelegate {
  internal func projectActivityBackingCellGoToBacking(project: Project, backing: Backing) {
    self.viewModel.inputs.projectActivityBackingCellGoToBacking(project: project, backing: backing)
  }

  internal func projectActivityBackingCellGoToSendMessage(project: Project, backing: Backing) {
    self.viewModel.inputs.projectActivityBackingCellGoToSendMessage(project: project, backing: backing)
  }
}

extension ProjectActivitiesViewController: ProjectActivityCommentCellDelegate {
  internal func projectActivityCommentCellGoToBacking(project: Project, user: User) {
    self.viewModel.inputs.projectActivityCommentCellGoToBacking(project: project, user: user)
  }

  func projectActivityCommentCellGoToSendReply(project: Project, update: Update?,
                                               comment: ActivityComment) {
    self.viewModel.inputs.projectActivityCommentCellGoToSendReply(
      project: project,
      update: update,
      comment: comment
    )
  }
}

extension ProjectActivitiesViewController: CommentDialogDelegate {
  internal func commentDialogWantsDismissal(_ dialog: CommentDialogViewController) {
    dialog.dismiss(animated: true, completion: nil)
  }

  internal func commentDialog(_: CommentDialogViewController, postedComment _: Comment) {}
}
