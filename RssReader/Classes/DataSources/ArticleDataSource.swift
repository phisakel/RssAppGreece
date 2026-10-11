//
//  ArticleDataSource.swift
//  RssReader
//
//  Created by AppCoda on 25.11.14.
//  Copyright (c) 2014 AppCoda Limited. All rights reserved.
//

import UIKit

//typealias ConfigureArticleCellClosure = (_ articleCell: ArticleViewCell, _ article: Article, _ indexPath: IndexPath) -> ()
typealias ConfigureArticleCellClosure = (ArticleViewCell, Article, IndexPath) -> ()

class ArticleDataSource: NSObject, UITableViewDataSource {

    var articles = [Article]()
    
    var configureCellClosure: ConfigureArticleCellClosure!
    
    init(configureCellClosure: ConfigureArticleCellClosure!) {
        super.init()
        self.configureCellClosure = configureCellClosure
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return articles.count
    }
    
    fileprivate let cellReuseIdentifier = "ArticleViewCell"
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        var cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier)
        
        if cell == nil {
            cell = ArticleViewCell(style: UITableViewCell.CellStyle.default, reuseIdentifier: cellReuseIdentifier)
        }
        
        let articleCell = cell as? ArticleViewCell
        let article = articles[indexPath.row]
        
        self.configureCellClosure(articleCell!, article, indexPath)
        
        return cell!;
    }
    
    subscript(index: Int) -> Article {
        return articles[index]
    }
}
