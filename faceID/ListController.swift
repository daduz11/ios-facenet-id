//
//  ListController.swift
//  faceID
//
//  Created by Davide on 24/07/2020.
//  Copyright © 2020 Davide. All rights reserved.
//

import Foundation
import UIKit


class ListController: UIViewController, UITableViewDelegate, UITableViewDataSource{
    
    private var labels :[String] = []
    @IBOutlet weak var tableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let fileURL = Bundle.main.url(forResource: "labels", withExtension: "txt"){
            do {
                let text = try! String(contentsOf: fileURL)
                let lines = text.components(separatedBy: "\n") as [String]
                
                //stores each line of file into a dictionary
                for i in 0..<lines.count {
                    self.labels.append(lines[i])
                }
            }
        }
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    //row
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return labels.count - 1
    }
    //cell content
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = labels[indexPath.row]
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let search = labels[indexPath.row]
        guard let encoded = search.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else {return}
        let link = "https://google.com/search?q=" + encoded
        let urlString = link.replacingOccurrences(of: " ", with: "+")
        if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}




