//
//  ImageCell.swift
//  ELCacheExample
//
//  Created by Sam Grover on 12/28/15.
//  Copyright © 2015 WalmartLabs. All rights reserved.
//

import UIKit

class ImageCell : UICollectionViewCell {
    @IBOutlet weak var imageView: UIImageView!
    
    override func prepareForReuse() {
        self.imageView.image = nil
        super.prepareForReuse()
    }
}

