import KsApi
import Prelude
import ReactiveExtensions
import ReactiveSwift

public protocol CommentsViewModelInputs {
  /// Call when the User is posting a comment or reply
  func postCommentButtonTapped()

  /// Call when the view loads.
  func viewDidLoad()
}

public protocol CommentsViewModelOutputs {
  /// Emits a URL for the avatar image view.
  var avatarURL: Signal<URL?, Never> { get }

  /// Emits a boolean that determines if the comment input area is visible.
  var inputAreaVisible: Signal<Bool, Never> { get }

  /// Emits a list of comments that should be displayed.
  var dataSource: Signal<([Comment], User?), Never> { get }
}

public protocol CommentsViewModelType {
  var inputs: CommentsViewModelInputs { get }
  var outputs: CommentsViewModelOutputs { get }
}

public final class CommentsViewModel: CommentsViewModelType,
  CommentsViewModelInputs,
  CommentsViewModelOutputs {
  public init() {
    let currentUser = self.viewDidLoadProperty.signal
      .map { _ in AppEnvironment.current.currentUser }
      .skipNil()

    // FIXME: Configure this VM with a project in order to feed the slug in here to fetch comments
    // Call this again with a cursor to paginate.
    self.viewDidLoadProperty.signal.switchMap { _ in
      AppEnvironment.current.apiService
        .fetchComments(query: comments(withProjectSlug: "bring-back-weekly-world-news"))
        .ksr_delay(AppEnvironment.current.apiDelayInterval, on: AppEnvironment.current.scheduler)
        .materialize()
    }
    .observeValues { print($0) }

    // FIXME: We need to dynamically supply the IDs when the UI is built.
    // The IDs here correspond to the following project: `THE GREAT GATSBY: Limited Edition Letterpress Print`.
    // When testing, replace with a project you have Backed or Created.
    self.postCommentButtonTappedProperty.signal.switchMap { _ in
      AppEnvironment.current.apiService
        .postComment(input: .init(
          body: "Testing on iOS!",
          commentableId: "UHJvamVjdC02NDQ2NzAxMzU=",
          parentId: "Q29tbWVudC0zMjY2MjUzOQ=="
        ))
        .ksr_delay(AppEnvironment.current.apiDelayInterval, on: AppEnvironment.current.scheduler)
        .materialize()
    }
    .observeValues { print($0) }

    self.avatarURL = currentUser.map { URL(string: $0.avatar.medium) }

    // When Project is supplied to the config, we will use that to determine who can comment on the project
    // and also to determine whethere input area is visible.
    self.inputAreaVisible = self.viewDidLoadProperty.signal.mapConst(true)

    // FIXME: This would be removed when we fetch comments from API
    self.dataSource = self.templatesComments.signal.skipNil()
  }

  fileprivate let postCommentButtonTappedProperty = MutableProperty(())
  public func postCommentButtonTapped() {
    self.postCommentButtonTappedProperty.value = ()
  }

  fileprivate let viewDidLoadProperty = MutableProperty(())

  // TODO: - This would be removed when we fetch comments from API
  fileprivate let templatesComments = MutableProperty<([Comment], User?)?>(nil)
  public func viewDidLoad() {
    self.viewDidLoadProperty.value = ()

    // FIXME: This would be removed when we fetch comments from API
    self.templatesComments.value = (Comment.templates, AppEnvironment.current.currentUser)
  }

  public var avatarURL: Signal<URL?, Never>
  public var inputAreaVisible: Signal<Bool, Never>
  public let dataSource: Signal<([Comment], User?), Never>

  public var inputs: CommentsViewModelInputs { return self }
  public var outputs: CommentsViewModelOutputs { return self }
}
