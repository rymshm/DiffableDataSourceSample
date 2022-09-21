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

    static var sampleData: [Todo] {
        [Int](0..<15).map { index in
            Todo(text: "ToDo \(index)",
                 isDone: Bool.random(),
                 id: index)
        }
    }
}

extension Sequence where Element: Identifiable {
    func groupingByUniqueID() -> [Element.ID: Element] {
        Dictionary(uniqueKeysWithValues: self.map { ($0.id, $0) })
    }
}

class ViewController: UIViewController {
    @IBOutlet private var collectionView: UICollectionView!
    @IBOutlet var sortSwitch: UISwitch!

    private enum Section {
        case todos
    }
    private var dataSource: UICollectionViewDiffableDataSource<Section, Todo.ID>?
    private var todos: [Todo.ID: Todo] = Todo.sampleData.groupingByUniqueID()
    private var isSorted: Bool = false

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
        let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Todo> { (cell, indexPath, todo) in
            var content = cell.defaultContentConfiguration()
            content.text = todo.text
            content.imageProperties.tintColor = todo.isDone ? .green : .secondaryLabel
            content.image = UIImage(systemName: todo.isDone ? "checkmark.circle" : "circle")
            cell.contentConfiguration = content
        }
        dataSource = UICollectionViewDiffableDataSource<Section, Todo.ID>(collectionView: collectionView) {
            (collectionView: UICollectionView, indexPath: IndexPath, identifier: Todo.ID) -> UICollectionViewCell? in
            collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: self.todos[identifier])
        }
    }

    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Todo.ID>()
        snapshot.appendSections([.todos])
        let ids = todos
                    .sorted(by: isSorted ? { ($0.value.isDone ? 1 : 0) < ($1.value.isDone ? 1 : 0) } : { $0.value.id < $1.value.id })
                    .map { $0.value.id }
        snapshot.appendItems(ids)
        dataSource?.apply(snapshot, animatingDifferences: true)
    }

    private func reloadItem(by todo: Todo) {
        todos.updateValue(todo, forKey: todo.id)
        if var snapshot = dataSource?.snapshot() {
            snapshot.reloadItems([todo.id])
            dataSource?.apply(snapshot, animatingDifferences: true)
        }
    }
}

extension ViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        if let id = dataSource?.itemIdentifier(for: indexPath),
            var todo = todos[id] {
            todo.isDone.toggle()
            reloadItem(by: todo)
            if isSorted {
                applySnapshot()
            }
        }
    }
}

