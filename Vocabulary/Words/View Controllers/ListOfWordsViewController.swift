//
//	ListOfWordsViewController.swift
//	Vocabulary
//
//	Created by Alexander Baraley on 3/6/18.
//	Copyright © 2018 Alexander Baraley. All rights reserved.
//

import UIKit
import CoreData

class ListOfWordsViewController: UITableViewController, SegueHandlerType {

	// MARK: - Initialization

	let vocabularyStore: VocabularyStore
	private let listOfWordsModelController: ListOfWordsModelController

	init?(
		coder: NSCoder,
		vocabularyStore: VocabularyStore,
		listOfWordsModelController: ListOfWordsModelController
	) {
		self.vocabularyStore = vocabularyStore
		self.listOfWordsModelController = listOfWordsModelController
		super.init(coder: coder)
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	// MARK: - Outlets -

	@IBOutlet private var addButtonItem: UIBarButtonItem!

	@IBOutlet private var moveButton: UIBarButtonItem!
	@IBOutlet private var selectAllButton: UIBarButtonItem!
	@IBOutlet private var deleteButton: UIBarButtonItem!
	
	// MARK: - Private properties -
	
	private let searchController = UISearchController(searchResultsController: nil)

	private var isAllCellsSelected = false

	// MARK: - Life Cycle -
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		initialConfiguration()
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)

		stopPronouncing()
		navigationController?.setToolbarHidden(true, animated: false)
	}
	
	override var textInputContextIdentifier: String? {
		return ListOfWordsViewController.stringIdentifier
	}
	
	override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
		showUndoAlert()
	}
	
	override func setEditing(_ editing: Bool, animated: Bool) {
		super.setEditing(editing, animated: animated)

		navigationItem.rightBarButtonItems = rightBarButtonItems

		if !isEditing, let indexPaths = tableView.indexPathsForVisibleRows {
			tableView.reloadRows(at: indexPaths, with: .automatic)
		}
		updateToolBar()
	}
	
	// MARK: - Navigation -
	
	enum SegueIdentifier: String {
		case editWord, createWord, moveWords
	}

	@IBSegueAction
	private func makeEditWordViewController(coder: NSCoder, sender: Any?, segueIdentifier: String?) -> EditWordViewController? {
		let editWordContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
		editWordContext.parent = vocabularyStore.viewContext

		let word: Word
		let viewMode: EditWordViewController.ViewMode

		if let cell = sender as? UITableViewCell, let indexPath = tableView.indexPath(for: cell) {
			word = listOfWordsModelController.wordAt(indexPath)
			viewMode = .edit
		} else {
			word = Word(context: vocabularyStore.viewContext)
			viewMode = .create
		}

		let editedWord = editWordContext.object(with: word.objectID) as! Word

		return EditWordViewController(coder: coder, context: editWordContext, word: editedWord, viewMode: viewMode) {
			[unowned self] (action) in
			self.handleEditing(of: word, withResultAction: action)
		}
	}

	@IBSegueAction
	private func makeWordDestinationsViewController(coder: NSCoder) -> WordDestinationsViewController? {
		return WordDestinationsViewController(
			coder: coder,
			vocabularyStore: vocabularyStore,
			destinationHandler: handle(_:)
		)
	}
}

// MARK: - Actions -
private extension ListOfWordsViewController {
	
	@IBAction func selectAllButtonAction(_ sender: UIBarButtonItem) {
		if isAllCellsSelected {
			deselectAllCells()
		} else {
			selectAllCells()
		}
		updateToolBar()
	}
	
	@IBAction func deleteWordsButtonAction(_ sender: UIBarButtonItem) {
		guard let indexPaths = tableView.indexPathsForSelectedRows else { return }
		
		listOfWordsModelController.deleteWords(at: indexPaths)

		setEditing(false, animated: true)
	}
	
	@IBAction func pronounceButtonAction(_ sender: UIButton) {
		guard let indexPath = tableView.indexPathForRow(with: sender) else { return }
		let word = listOfWordsModelController.wordAt(indexPath).headword
		pronounce(word)
	}
}

// MARK: - Helpers -
private extension ListOfWordsViewController {

	// MARK: - Configuration -

	var rightBarButtonItems: [UIBarButtonItem] {
		tableView.isEditing ? [editButtonItem] : [editButtonItem, addButtonItem]
	}

	func initialConfiguration() {
		vocabularyStore.viewContext.undoManager = UndoManager()

		listOfWordsModelController.dataChangesHandler = { [unowned self] changes in
			self.tableView.handleChanges(changes)
		}
		tableView.dataSource = listOfWordsModelController

		configureNavigationBar()
		updateToolBar()
	}

	func configureNavigationBar() {
		configureSearchController()

		navigationItem.rightBarButtonItems = rightBarButtonItems
		navigationItem.searchController = searchController

		navigationItem.title = listOfWordsModelController.learningStage?.name ?? "All Words"
	}

	func configureSearchController() {
		searchController.obscuresBackgroundDuringPresentation = false
		searchController.searchBar.placeholder = "Search by headword"
		searchController.searchResultsUpdater = self
		definesPresentationContext = true
	}

	func updateToolBar() {
		let hasSelectedRows = (tableView.indexPathForSelectedRow?.count ?? 0) > 0

		let wordsNumber = tableView.numberOfRows(inSection: 0)
		selectAllButton.isEnabled = wordsNumber > 0
		moveButton.isEnabled = hasSelectedRows
		deleteButton.isEnabled = hasSelectedRows
		selectAllButton.title = isAllCellsSelected ? "Deselect All" : "Select All"

		navigationController?.setToolbarHidden(!isEditing, animated: true)
	}

	// MARK: - Cells Selection -

	func selectAllCells() {
		let wordsNumber = tableView.numberOfRows(inSection: 0)

		for index in 0..<wordsNumber {
			let indexPath = IndexPath(row: index, section: 0)
			tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
		}

		isAllCellsSelected = true
	}

	func deselectAllCells() {
		tableView.indexPathsForSelectedRows?.forEach {
			tableView.deselectRow(at: $0, animated: true)
		}

		isAllCellsSelected = false
	}

	// MARK: - Handlers

	func handle(_ destination: WordDestinationsViewController.Destination) {
		guard let indexPaths = tableView.indexPathsForSelectedRows else { return }

		listOfWordsModelController.moveWords(at: indexPaths, to: destination)

		setEditing(false, animated: true)
	}

	func handleEditing(of word: Word, withResultAction action: EditWordViewController.ResultAction) {
		switch action {
		case .save, .delete:
			vocabularyStore.saveChanges()

		case .cancel:
			vocabularyStore.viewContext.refresh(word, mergeChanges: false)
		}
	}
}

// MARK: - UITableViewDelegate -
extension ListOfWordsViewController {
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		updateToolBar()
	}
	
	override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
		updateToolBar()
	}

	// Default implementation of showing swipe actions will turn tableView in editing state.
	// In order to prevent it you need to override willBeginEditingRowAt/didEndEditingRowAt delegate's methods
	override func tableView(_ tableView: UITableView, willBeginEditingRowAt indexPath: IndexPath) { }
	override func tableView(_ tableView: UITableView, didEndEditingRowAt indexPath: IndexPath?) { }
	
	override func tableView(
		_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
	) -> UISwipeActionsConfiguration? {
		
		let editAction = UIContextualAction(style: .normal, title: "Edit") { (_, _, handler) in
			self.performSegue(with: .editWord, sender: tableView.cellForRow(at: indexPath))
			handler(true)
		}
		
		let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { (_, _, handler) in
			self.listOfWordsModelController.deleteWords(at: [indexPath])
			handler(true)
		}
		
		return UISwipeActionsConfiguration(actions: [deleteAction, editAction])
	}
}

// MARK: - UISearchResultsUpdating -
extension ListOfWordsViewController: UISearchResultsUpdating {
	func updateSearchResults(for searchController: UISearchController) {
		if let searchQuery = searchController.searchBar.text, !searchQuery.isEmpty {
			listOfWordsModelController.filterWordsBy(searchQuery: searchQuery)
		} else {
			listOfWordsModelController.filterWordsBy(searchQuery: nil)
		}
		tableView.reloadData()
	}
}
