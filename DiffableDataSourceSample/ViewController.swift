//
//  ViewController.swift
//  DiffableDataSourceSample
//
//  Created by mashima.ryo on 2022/09/19.
//

import UIKit

struct Todo: Identifiable {
    let text: String
    var isDone: Bool
    let id: Int
}

class ViewController: UIViewController {
    @IBOutlet private var collectionView: UICollectionView!
    @IBOutlet private var sortSwitch: UISwitch!

    private enum Section {
        case todos
    }
    private var dataSource: UICollectionViewDiffableDataSource<Section, Todo.ID>?
    private var presenter: TodoPresenterInput!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "ToDo"
        self.presenter = TodoPresenter(output: self)
        sortSwitch.addTarget(self, action: #selector(onChangedSortSwitch(_:)), for: .valueChanged)
        configureCollectionView()
        presenter.viewDidLoad()
    }

    @objc private func onChangedSortSwitch(_ sender: UISwitch) {
        presenter.onChangedSortSwitch(isOn: sender.isOn)
    }

    private func configureCollectionView() {
        // layout
        collectionView.collectionViewLayout = listLayout()
        // delegate
        collectionView.delegate = self
        // datasource
        let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Todo> { (cell, indexPath, todo) in
            cell.contentConfiguration = TodoContentConfiguration(isDone: todo.isDone, text: todo.text)
//            var content = cell.defaultContentConfiguration()
//            content.text = todo.text
//            content.imageProperties.tintColor = todo.isDone ? .green : .secondaryLabel
//            content.image = UIImage(systemName: todo.isDone ? "checkmark.circle" : "circle")
//            cell.contentConfiguration = content
        }
        dataSource = UICollectionViewDiffableDataSource<Section, Todo.ID>(collectionView: collectionView) {
            (collectionView: UICollectionView, indexPath: IndexPath, identifier: Todo.ID) -> UICollectionViewCell? in
            collectionView.dequeueConfiguredReusableCell(using: cellRegistration,
                                                         for: indexPath,
                                                         item: self.presenter.todo(by: identifier))
        }
    }

    private func listLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout.list(using: .init(appearance: .plain))
    }

    private func createSnapshot() -> NSDiffableDataSourceSnapshot<Section, Todo.ID> {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Todo.ID>()
        snapshot.appendSections([.todos])
        snapshot.appendItems(presenter.ids)
        return snapshot
    }
}

extension ViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        if let id = dataSource?.itemIdentifier(for: indexPath) {
            presenter.didSelectTodo(id: id)
        }
    }
}

extension ViewController: TodoPresenterOutput {
    func updateSnapshot(reloadItems: [Todo.ID]) {
        var snapshot = createSnapshot()
        if !reloadItems.isEmpty {
            snapshot.reloadItems(reloadItems)
        }
        dataSource?.apply(snapshot, animatingDifferences: true)
    }
}

// MARK: - Presenter層

protocol TodoPresenterInput {
    func viewDidLoad()
    func didSelectTodo(id: Todo.ID)
    func onChangedSortSwitch(isOn: Bool)
    func todo(by id: Todo.ID) -> Todo
    var ids: [Todo.ID] { get }
}

protocol TodoPresenterOutput: AnyObject {
    func updateSnapshot(reloadItems: [Todo.ID])
}

class TodoPresenter: TodoPresenterInput {
    private weak var output: TodoPresenterOutput?
    private let repository: TodoRepositoryInterface
    private var isSorted: Bool = false
    private var todos: [Todo] = []
    var ids: [Todo.ID] {
        todos
            .sorted(by: isSorted ? { ($0.isDone ? 1 : 0) < ($1.isDone ? 1 : 0) } : { $0.id < $1.id })
            .map { $0.id }
    }

    init(output: TodoPresenterOutput,
         repository: TodoRepositoryInterface = TodoRepository()) {
        self.output = output
        self.repository = repository
    }

    func viewDidLoad() {
        repository.fetch { todos in
            self.todos = todos
            self.output?.updateSnapshot(reloadItems: [])
        }
    }

    func todo(by id: Todo.ID) -> Todo {
        let index = todos.firstIndex(where: { id == $0.id })!
        return todos[index]
    }

    func onChangedSortSwitch(isOn: Bool) {
        isSorted = isOn
        output?.updateSnapshot(reloadItems: [])
    }

    func didSelectTodo(id: Todo.ID) {
        let index = todos.firstIndex(where: { id == $0.id })!
        todos[index].isDone.toggle()
        output?.updateSnapshot(reloadItems: [id])
    }
}

// MARK: - Model層

protocol TodoRepositoryInterface {
    func fetch(completion: @escaping (([Todo]) -> Void))
}

struct TodoRepository: TodoRepositoryInterface {
    func fetch(completion: @escaping (([Todo]) -> Void)) {
        let todos = [Int](0..<20).map { index in
            Todo(text: "ToDo \(index)",
                 isDone: Bool.random(),
                 id: index)
        }
        completion(todos)
    }
}

// MARK: - Custom Content Configuration

struct TodoContentConfiguration: UIContentConfiguration {
    var isDone: Bool
    var text: String

    func makeContentView() -> UIView & UIContentView { ToDoContentView(configuration: self) }
    func updated(for state: UIConfigurationState) -> TodoContentConfiguration { self }
}

class ToDoContentView: UIView, UIContentView {
    private let checkMarkImageView: UIImageView = .init()
    private let label: UILabel =  {
        let label = UILabel()
        label.font = .systemFont(ofSize: UIFont.buttonFontSize, weight: .semibold)
        return label
    }()
    private let stackView: UIStackView = {
        let view = UIStackView()
        view.alignment = .center
        view.axis = .horizontal
        view.spacing = 8
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    var configuration: UIContentConfiguration {
        didSet {
            guard let configuration = configuration as? TodoContentConfiguration else { return }
            checkMarkImageView.image = UIImage(systemName: configuration.isDone ? "checkmark.circle" : "circle")
            checkMarkImageView.tintColor = configuration.isDone ? .green : .secondaryLabel
            label.text = configuration.text
        }
    }

    init(configuration: TodoContentConfiguration) {
        self.configuration = configuration
        super.init(frame: .zero)

        addSubview(stackView)
        stackView.addArrangedSubview(label)
        stackView.addLayoutGuide(UILayoutGuide())
        stackView.addArrangedSubview(checkMarkImageView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor,
                                               constant: 16),
            stackView.trailingAnchor.constraint(greaterThanOrEqualTo: safeAreaLayoutGuide.trailingAnchor,
                                                constant: -16),
            stackView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor,
                                           constant: 16),
            stackView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor,
                                              constant: -16),

            checkMarkImageView.widthAnchor.constraint(equalToConstant: 24),
            checkMarkImageView.heightAnchor.constraint(equalTo: checkMarkImageView.widthAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


