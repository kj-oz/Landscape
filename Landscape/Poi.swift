//
//  Poi.swift
//  Landscape
//
//  Created by KO on 2017/01/10.
//  Copyright © 2017年 KO. All rights reserved.
//

import Foundation
import CoreLocation

class Poi {
  let name: String
  let height: Double
  let location: CLLocationCoordinate2D
  var distance = 0.0
  var orientation = 0.0
  var children: [Poi] = []
  
  init(name: String, height: Double, location: CLLocationCoordinate2D, group: Poi? = nil) {
    self.name = name
    self.height = height
    self.location = location
    if let group = group {
      group.children.append(self)
    }
  }
}

class Orientation {
  let name: String
  let level: Int
  let orientation: Double
  
  init(name: String, orientation: Double) {
    self.name = name
    self.level = name.characters.count
    self.orientation = orientation
  }
}
