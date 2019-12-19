//
//  AppRootViewController.swift
//  Vocabulary
//
//  Created by Alexander Baraley on 05.12.2019.
//  Copyright © 2019 Alexander Baraley. All rights reserved.
//

import UIKit

class AppRootViewController: UITabBarController, SegueHandlerType {

	private let vocabularyStore = VocabularyStore()
	private let currentWordCollectionModelController = CurrentWordCollectionModelController()

	override func viewDidLoad() {
		super.viewDidLoad()

		view.backgroundColor = .white
		setupViewControllers()
		selectedIndex = 1
	}

	// MARK: - Navigation

	enum SegueIdentifier: String {
		case showWordCollections
	}

	@IBSegueAction
	private func makeWordCollectionsController(coder: NSCoder) -> WordCollectionsTableViewController? {
		WordCollectionsTableViewController(
			coder: coder,
			vocabularyStore: vocabularyStore,
			currentWordCollectionModelController: currentWordCollectionModelController
		)
	}
}

// MARK: - Private
private extension AppRootViewController {

	func setupViewControllers() {
		viewControllers?.forEach {
			guard let navVC = $0 as? UINavigationController else { return }

			navVC.viewControllers.first?.navigationItem.leftBarButtonItem = UIBarButtonItem(
				title: "Collections", style: .plain, target: self, action: #selector(showWordCollections)
			)

			if let learningTabVC = navVC.viewControllers.first as? LearningOptionsViewController {
				learningTabVC.vocabularyStore = vocabularyStore
				learningTabVC.currentWordCollectionInfoProvider = currentWordCollectionModelController
			}
			if let searchTabVC = navVC.viewControllers.first as? SearchTabViewController {
				searchTabVC.vocabularyStore = vocabularyStore
				searchTabVC.searchStateModelController = SearchStateModelController()
				searchTabVC.currentWordCollectionInfoProvider = currentWordCollectionModelController
			}
			if let wordsTabVC = navVC.viewControllers.first as? WordsTabViewController {
				wordsTabVC.vocabularyStore = vocabularyStore
				wordsTabVC.currentWordCollectionInfoProvider = currentWordCollectionModelController
			}
		}
	}

	@objc
	func showWordCollections() {
		performSegue(with: .showWordCollections, sender: nil)
	}
}
