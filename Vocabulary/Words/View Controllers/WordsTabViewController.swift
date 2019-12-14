//
//  WordsTabViewController.swift
//  Vocabulary
//
//  Created by Alexander Baraley on 13.12.2019.
//  Copyright © 2019 Alexander Baraley. All rights reserved.
//

import UIKit

class WordsTabViewController: UITableViewController, SegueHandlerType {

	// MARK: - Initialization

	private let vocabularyStore: VocabularyStore

	init?(coder: NSCoder, vocabularyStore: VocabularyStore) {
		self.vocabularyStore = vocabularyStore
		super.init(coder: coder)
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	// MARK: - Life cycle

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		tableView.reloadData()
	}

	// MARK: - Navigation

	enum SegueIdentifier: String {
		case showListOfWords
	}

	@IBSegueAction
	func makeListOfWordsViewController(coder: NSCoder, sender: Any?, segueIdentifier: String?) -> ListOfWordsViewController? {
		guard let indexPath = tableView.indexPathForSelectedRow else { return nil }

		let learningStage = Section(at: indexPath) == .allWords ? nil : Word.LearningStage(rawValue: Int16(indexPath.row))

		return ListOfWordsViewController(coder: coder, vocabularyStore: vocabularyStore, learningStage: learningStage)
	}

	// MARK: - UITableViewDataSource

	override func numberOfSections(in tableView: UITableView) -> Int {
		return Section.count
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return Section(section).numberOfItems
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueCell(indexPath: indexPath) as UITableViewCell

		cell.textLabel?.text = Section(at: indexPath).textOfItem(at: indexPath.row)
		cell.detailTextLabel?.text = detailedTextForCell(at: indexPath)

		return cell
	}

	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		return Section(section).title
	}
}

// MARK: - Private
private extension WordsTabViewController {

	enum Section: Int, CaseIterable {
		case allWords, learningStages

		init(at indexPath: IndexPath) {
			self = Section.init(rawValue: indexPath.section)!
		}

		init(_ section: Int) {
			self = Section.init(rawValue: section)!
		}

		static let count = 2

		var title: String? {
			switch self {
			case .allWords:			return nil
			case .learningStages:	return "Learning Stages"
			}
		}

		var numberOfItems: Int {
			switch self {
			case .allWords:			return 1
			case .learningStages:	return Word.LearningStage.count
			}
		}

		func textOfItem(at index: Int) -> String {
			switch self {
			case .allWords:			return "All words"
			case .learningStages:	return Word.LearningStage.names[index]
			}
		}
	}

	func numberOfWords(at learningStage: Word.LearningStage?) -> Int {
		let parameters: WordsRequestParameters = (
			learningStage, currentWordCollectionInfo?.objectID, false
		)
		let request = FetchRequestFactory.requestForWords(with: parameters)
		return vocabularyStore.numberOfWordsFrom(request)
	}

	func detailedTextForCell(at indexPath: IndexPath) -> String {
		let stage: Word.LearningStage?

		switch Section(at: indexPath) {
		case .allWords: 		stage = nil
		case .learningStages: 	stage = Word.LearningStage(rawValue: Int16(indexPath.row))
		}

		let number = numberOfWords(at: stage)

		return "\(number)"
	}
}
