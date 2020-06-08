//
//  SearchableTableViewController.swift
//  MyRep
//
//  Created by Rhett Rogers on 6/5/20.
//  Copyright © 2020 Rhett Rogers. All rights reserved.
//

import Foundation
import UIKit
import Combine

class SearchableTableViewController: UIViewController {
    
    var subscriptions = Set<AnyCancellable>()
    
    @IBOutlet weak var tableView: UITableView!
    lazy var searchController: UISearchController = {
        let controller = UISearchController(searchResultsController: nil)
        
        NotificationCenter.default.publisher(for: UISearchTextField.textDidChangeNotification, object: controller.searchBar.searchTextField)
            .debounce(for: 1, scheduler: DispatchQueue.main)
            .map { _ in controller.searchBar.text ?? "" }
            .sink { text in
                guard !text.isEmpty else { return }
                
                self.searchAndUpdateUI(query: text)
                
        }
        .store(in: &self.subscriptions)
        
        controller.searchBar.textContentType = .none
        controller.searchBar.keyboardType = .default
        controller.searchBar.scopeButtonTitles = MemberFetcher.APIEndpoint.allCases.map { $0.rawValue }
        controller.searchBar.showsScopeBar = true
        controller.searchBar.delegate = self
        self.apiTarget = MemberFetcher.APIEndpoint.allCases[controller.searchBar.selectedScopeButtonIndex]
        controller.obscuresBackgroundDuringPresentation = false
        controller.hidesNavigationBarDuringPresentation = false
        tableView.tableHeaderView = controller.searchBar
        
        
        return controller
    }()
    
    var senators: [Member] = []
    var reps: [Member] = []
    var apiTarget: MemberFetcher.APIEndpoint = .zip
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        _ = searchController
        
        tableView.delegate = self
        tableView.dataSource = self
        
        definesPresentationContext = true
    }
    
    func searchAndUpdateUI(query: String) {
        apiTarget = MemberFetcher.APIEndpoint.allCases[searchController.searchBar.selectedScopeButtonIndex]
        
        let endpoint: MemberFetcher.MemberResult = {
            switch self.apiTarget {
            case .zip: return MemberFetcher.shared.getAllMembers(byZip: query)
            case .name: return MemberFetcher.shared.getAllMembers(byName: query)
            case .state: return MemberFetcher.shared.getAllMembers(byState: query)
            }
        }()
        
        endpoint.sink { [weak self] members in
                
                DispatchQueue.main.async {
                    self?.senators = members.filter { $0.isSenator }
                    self?.reps = members.filter { !$0.isSenator }
                    self?.tableView.reloadData()
                }
                
        }
        .store(in: &subscriptions)
    }
    
    func showAlert(for member: Member) {
        let controller = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        let phoneAction = UIAlertAction(title: "Call \(member.name)", style: .default) { _ in
            guard let url = URL(string: "tel://\(member.phone.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: ""))") else { return }
            
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        
        let webAction = UIAlertAction(title: "Visit Site", style: .default) { _  in
            guard let url = member.url else { return }
            
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        if !member.phone.isEmpty {
            controller.addAction(phoneAction)
        }
        
        if member.url != nil {
            controller.addAction(webAction)
        }
        
        controller.addAction(cancelAction)
        
        searchController.present(controller, animated: true, completion: nil)
        
    }
    
}

extension SearchableTableViewController: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        senators.isEmpty && reps.isEmpty ? 0 : 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? senators.count : reps.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let uncastedCell = tableView.dequeueReusableCell(withIdentifier: "MemberTableViewCell", for: indexPath)
        let members = indexPath.section == 0 ? senators : reps
        
        (uncastedCell as? MemberTableViewCell).map { cell in
            cell.nameLabel.text = members[indexPath.row].name
            cell.stateLabel.text = "\(members[indexPath.row].state)"
            cell.partyLabel.text = members[indexPath.row].party
        }
        
        return uncastedCell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? "Senators" : "Representatives"
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
//        searchController.dismiss(animated: true) {
            self.showAlert(for: indexPath.section == 0 ? self.senators[indexPath.row] : self.reps[indexPath.row])
            
//        }
    }
    
    
    
}

extension SearchableTableViewController: UISearchBarDelegate {
    
    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        apiTarget = MemberFetcher.APIEndpoint.allCases[selectedScope]
        
        
        if let query = searchBar.text {
            searchAndUpdateUI(query: query)
        }
    }
    
    
    
}
