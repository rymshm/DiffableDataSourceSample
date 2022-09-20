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
    let id: UUID = UUID()

    static var sampleData: [Todo] {
        [Int](0..<15).map { index in
            Todo(text: "ToDo \(index)", isDone: Bool.random())
        }
    }
}

class ViewController: UIViewController {
    @IBOutlet private var collectionView: UICollectionView!
    @IBOutlet var sortSwitch: UISwitch!

    private enum Section {
        case todos
    }
    private var dataSource: UICollectionViewDiffableDataSource<Section, Todo.ID>?
    private var todos: [Todo] = Todo.sampleData
    private var isSorted: Bool = false
    var ids: [Todo.ID] {
        isSorted ?
        todos.sorted(by: { ($0.isDone ? 1 : 0) < ($1.isDone ? 1 : 0) }).map { $0.id }
        : todos.map { $0.id }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "ToDo"
        sortSwitch.isOn = self.isSorted
        sortSwitch.addTarget(self, action: #selector(sortTodos), for: .valueChanged)
        collectionView.collectionViewLayout = createLayout()
        configureDataSource()
        collectionView.delegate = self
        applySnapshot()
    }

    @objc private func sortTodos(_ sender: UISwitch) {
        isSorted = sender.isOn
        applySnapshot()
    }

    private func createLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout {
            .list(using: .init(appearance: .plain), layoutEnvironment: $1)
        }
    }

    private func configureDataSource() {
        let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Todo.ID> { (cell, indexPath, id) in
            let todo = self.todo(id: id).element
            var content = cell.defaultContentConfiguration()
            content.text = todo.text
            content.imageProperties.tintColor = todo.isDone ? .green : .secondaryLabel
            content.image = UIImage(systemName: todo.isDone ? "checkmark.circle" : "circle")
            cell.contentConfiguration = content
        }
        dataSource = UICollectionViewDiffableDataSource<Section, Todo.ID>(collectionView: collectionView) {
            (collectionView: UICollectionView, indexPath: IndexPath, identifier: Todo.ID) -> UICollectionViewCell? in
            collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: identifier)
        }
    }

    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Todo.ID>()
        snapshot.appendSections([.todos])
        snapshot.appendItems(ids)
        dataSource?.apply(snapshot, animatingDifferences: true)
    }

    private func reloadItems(by id: Todo.ID) {
        if var snapshot = dataSource?.snapshot() {
            snapshot.reloadItems([id])
            dataSource?.apply(snapshot, animatingDifferences: true)
        }
    }

    private func todo(id: Todo.ID) -> (index: Int, element: Todo) {
        let index = todos.firstIndex(where: { $0.id == id })!
        return (index, todos[index])
    }
}

extension ViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let itemIdentifier = dataSource?.itemIdentifier(for: indexPath) {
            collectionView.deselectItem(at: indexPath, animated: true)
            let index = todo(id: itemIdentifier).index
            todos[index].isDone.toggle()
            reloadItems(by: itemIdentifier)
            if isSorted {
                applySnapshot()
            }
        }
    }
}

