//
//  ItemListViewController.swift
//  fbapplib
//
//  Created by omochimetaru on 2018/08/14.
//  Copyright © 2018年 omochimetaru.com. All rights reserved.
//

import Foundation
import UIKit
import fbappcore
import FirebaseFirestore

public class ItemListViewController : UIViewController, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet private var tableView: UITableView!
    
    public init() {
        super.init(nibName: nil,
                   bundle: Bundle(for: ItemListViewController.self))
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        listener?.remove()
    }

    private var items: [Item] = [] {
        didSet {
            tableView.reloadData()
        }
    }
    
    private var query: Query? {
        didSet {
            observe()
        }
    }
    
    private var listener: ListenerRegistration?
    
    public override func viewDidLoad() {
        super.viewDidLoad()
                
        self.items = [
            Item(name: "Parse", description: "Swift -> AST")
        ]
        
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        self.query = Item.query()
        
        observe()
    }
    
    public func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "default") ??
            UITableViewCell.init(style: UITableViewCellStyle.value1, reuseIdentifier: "default")
        
        let item = self.items[indexPath.row]
        
        cell.textLabel?.text = item.name
        cell.detailTextLabel?.text = item.description
        
        return cell
    }
    
    private func observe() {
        unowned let uself = self
        
        listener?.remove()
        
        guard let query = self.query else { return }
        
        listener = query.addSnapshotListener({ (snapshot, error) in
            if let error = error {
                uself.showError(error)
                return
            }
            
            guard let snapshot = snapshot else {
                return
            }
            
            
            let items = snapshot.documents.compactMap { (firestore) -> Item? in
                return Item(firestore: firestore.data())
            }
            
            self.items = items
        })
    }
    
    private func showError(_ error: Error) {
        let ac = UIAlertController(title: "エラー", message: "\(error)", preferredStyle: UIAlertControllerStyle.alert)
        ac.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
        self.present(ac, animated: true, completion: nil)
    }
    
    @IBAction private func onSetDummyButton() {
        let dummy: [Item] = [
            Item(name: "Parse", description: "Swift -> AST"),
            Item(name: "Sema", description: "Type infer"),
            Item(name: "SIL", description: "AST -> SIL"),
            Item(name: "IRGen", description: "SIL -> LLVM")
        ]
        
        let collection = Firestore.firestore().collection("items")
        
        for a in dummy {
            collection.addDocument(data: a.toFirestore())
        }
    }
}
