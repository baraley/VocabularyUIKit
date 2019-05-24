//
//	WordCollectionsTableViewController.swift
//	Vocabulary
//
//	Created by Alexander Baraley on 7/3/18.
//	Copyright © 2018 Alexander Baraley. All rights reserved.
//

import UIKit
import CoreData

private(set) var currentWordCollection: WordCollection?

class WordCollectionsTableViewController: UITableViewController, SegueHandlerType {
	
	// MARK: - Public properties -
	
	var vocabularyStore: VocabularyStore!
	
	var dataChanges: [DataChange] = []
	
	var didFinishSelectionHandler: (() -> Void)?
	
	// MARK: - Private properties
	
	private lazy var wordCollectionsDataSource = WordCollectionsDataSource(
		context: vocabularyStore.context
	)
	
	private var wordCollectionToRename: WordCollection?
	
	// MARK: - Actions -
	
	@IBAction private func showLearningsTypesContorller() {
		didFinishSelectionHandler?()
	}
	
	// MARK: - Life Cycle
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		wordCollectionsDataSource.delegate = self
		tableView.dataSource = wordCollectionsDataSource
	}
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		
		wordCollectionToRename = nil
		
		if vocabularyStore.context.undoManager == nil {
			vocabularyStore.context.undoManager = UndoManager()
		}
	}
	
	override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
		showUndoAlert()
	}
	
	// MARK: - Navigation
	
	enum SegueIdentifier: String {
		case createCollection, renameCollection
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		switch segueIdentifier(for: segue) {
		case .createCollection:
			let viewController = segue.destination as! EditTextViewController
			
			viewController.delegate = self
			viewController.initialText = ""
			viewController.charactersCapacity = .verySmall
			
		case .renameCollection:
			guard let wordCollection = wordCollectionToRename else { return }
			
			let viewController = segue.destination as! EditTextViewController
			
			viewController.delegate = self
			viewController.initialText = wordCollection.name
			viewController.charactersCapacity = .verySmall
		}
	}
	
	// MARK: - UITableViewDelegate
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		selectWordCollection(at: indexPath)
		tableView.deselectRow(at: indexPath, animated: true)
	}
	
	override func tableView(_ tableView: UITableView,
							trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
		) -> UISwipeActionsConfiguration? {
		
		
		let renameAction = UIContextualAction(style: .normal,
											  title: "Rename") { (_, _, handler) in
			self.wordCollectionToRename = self.wordCollectionsDataSource.wordCollection(indexPath)
			self.performSegue(with: .renameCollection, sender: nil)
			handler(true)
		}
		
		let deleteAction = UIContextualAction(style: .destructive,
											  title: "Delete") { (_, _, handler) in
			let wordCollectionToDelete = self.wordCollectionsDataSource.wordCollection(indexPath)
			
			if wordCollectionToDelete.words?.count == 0 {
				self.deleteWordCollection(at: indexPath)
				handler(true)
			} else {
				self.sowAlertForWordCollectionDeletion(at: indexPath)
				handler(false)
			}
		}
		
		return UISwipeActionsConfiguration(actions: [deleteAction, renameAction])
	}
}

// MARK: - Private -
private extension WordCollectionsTableViewController {
	
	func selectWordCollection(at indexPath: IndexPath) {
		let wordCollection = wordCollectionsDataSource.wordCollection(indexPath)
		
		if wordCollection != currentWordCollection {
			if let oldWordCollection = currentWordCollection,
				let currentIndexPath = wordCollectionsDataSource.indexPath(for: oldWordCollection) {
				
				tableView.cellForRow(at: currentIndexPath)?.accessoryType = .none
			}
			
			if let indexPath = wordCollectionsDataSource.indexPath(for: wordCollection) {
				tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
			}
			currentWordCollection = wordCollection
			didFinishSelectionHandler?()
			
		} else {
			if let indexPath = wordCollectionsDataSource.indexPath(for: wordCollection) {
				tableView.cellForRow(at: indexPath)?.accessoryType = .none
			}
			currentWordCollection = nil
		}
	}
	
	func deleteWordCollection(at indexPath: IndexPath) {
		let wordCollection = wordCollectionsDataSource.wordCollection(indexPath)
		
		if currentWordCollection == wordCollection {
			currentWordCollection = nil
		}
		vocabularyStore.deleteAndSave(wordCollection)
	}
	
	func sowAlertForWordCollectionDeletion(at indexPath: IndexPath) {
		let wordCollection = wordCollectionsDataSource.wordCollection(indexPath)
		
		let title = "Delete \"\(wordCollection.name)\" collectioin?"
		
		let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
		
		alert.addAction(UIAlertAction(title: "Collection and Words", style: .destructive) { (_) in
			if let words = wordCollection.words as? Set<Word> {
				words.forEach { self.vocabularyStore.context.delete($0) }
			}
			self.deleteWordCollection(at: indexPath)
		})
		alert.addAction(UIAlertAction(title: "Only Collection", style: .destructive) { (_) in
			self.deleteWordCollection(at: indexPath)
		})
		alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
		
		present(alert, animated: true, completion: nil)
	}
}

// MARK: - EditTextViewControllerDelegate
extension WordCollectionsTableViewController: EditTextViewControllerDelegate {
	func editTextViewController(_ controller: EditTextViewController, saveEditedText text: String) {
		if let wordCollection = wordCollectionToRename {
			wordCollection.name = text
		} else {
			let newCollection = WordCollection(context: vocabularyStore.context)
			newCollection.name = text
		}
		vocabularyStore.saveChanges()
		navigationController?.popViewController(animated: true)
	}
}

// MARK: - NSFetchedResultsControllerDelegate
extension WordCollectionsTableViewController: FetchedResultsTableViewControllerDelegate {
	
	func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
					didChange anObject: Any, at indexPath: IndexPath?,
					for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
		dataChanges.append((type, indexPath, newIndexPath))
	}
	
	func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
		handleWordsChanges()
	}
}
