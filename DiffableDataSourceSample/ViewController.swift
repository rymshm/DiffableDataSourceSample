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
    @IBOutlet var sortSwitch: UISwitch!

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
        collectionView.collectionViewLayout = createLayout()
        configureDataSource()
        collectionView.delegate = self
        presenter.viewDidLoad()
    }

    @objc private func onChangedSortSwitch(_ sender: UISwitch) {
        presenter.onChangedSortSwitch(isOn: sender.isOn)
    }

    private func createLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout {
            .list(using: .init(appearance: .plain), layoutEnvironment: $1)
        }
    }

    private func configureDataSource() {
        let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Todo> { (cell, indexPath, todo) in
            var content = cell.defaultContentConfiguration()
            content.text = todo.text
            content.imageProperties.tintColor = todo.isDone ? .green : .secondaryLabel
            content.image = UIImage(systemName: todo.isDone ? "checkmark.circle" : "circle")
            cell.contentConfiguration = content
        }
        dataSource = UICollectionViewDiffableDataSource<Section, Todo.ID>(collectionView: collectionView) {
            (collectionView: UICollectionView, indexPath: IndexPath, identifier: Todo.ID) -> UICollectionViewCell? in
            collectionView.dequeueConfiguredReusableCell(using: cellRegistration,
                                                         for: indexPath,
                                                         item: self.presenter.todo(by: identifier))
        }
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
    func apply(ids: [Todo.ID]) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Todo.ID>()
        snapshot.appendSections([.todos])
        snapshot.appendItems(ids)
        dataSource?.apply(snapshot, animatingDifferences: true)
    }

    func reload(id: Todo.ID) {
        if var snapshot = dataSource?.snapshot() {
            snapshot.reloadItems([id])
            dataSource?.apply(snapshot, animatingDifferences: true)
        }
    }
}

// MARK: - Presenter層

protocol TodoPresenterInput {
    func viewDidLoad()
    func didSelectTodo(id: Todo.ID)
    func todo(by id: Todo.ID) -> Todo
    func onChangedSortSwitch(isOn: Bool)
}

protocol TodoPresenterOutput: AnyObject {
    func apply(ids: [Todo.ID])
    func reload(id: Todo.ID)
}

class TodoPresenter: TodoPresenterInput {
    private weak var output: TodoPresenterOutput?
    private let repository: TodoRepositoryInterface
    private var isSorted: Bool = false
    private var todos: [Todo] = []
    private var ids: [Todo.ID] {
        todos
            .sorted(by: self.isSorted ? { ($0.isDone ? 1 : 0) < ($1.isDone ? 1 : 0) } : { $0.id < $1.id })
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
            self.output?.apply(ids: self.ids)
        }
    }

    func todo(by id: Todo.ID) -> Todo {
        let index = todos.firstIndex(where: { id == $0.id })!
        return todos[index]
    }

    func onChangedSortSwitch(isOn: Bool) {
        isSorted = isOn
        self.output?.apply(ids: ids)
    }

    func didSelectTodo(id: Todo.ID) {
        let index = todos.firstIndex(where: { id == $0.id })!
        todos[index].isDone.toggle()
        output?.reload(id: id)
        if isSorted {
            output?.apply(ids: ids)
        }
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

