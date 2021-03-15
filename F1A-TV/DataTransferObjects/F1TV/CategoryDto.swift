//
//  CategoryDto.swift
//  F1A-TV
//
//  Created by Noah Fetz on 12.03.21.
//

import Foundation

struct CategoryDto: Codable {
    var categoryPathIds: [Int]
    var externalPathIds: [String]
    var endDate: Int
    var orderId: Int
    var isPrimary: Bool
    var categoryName: String
    var categoryId: Int
    var startDate: Int

    init() {
        self.categoryPathIds = [Int]()
        self.externalPathIds = [String]()
        self.endDate = 0
        self.orderId = 0
        self.isPrimary = false
        self.categoryName = ""
        self.categoryId = 0
        self.startDate = 0
    }
    
    init(categoryPathIds: [Int], externalPathIds: [String], endDate: Int, orderId: Int, isPrimary: Bool, categoryName: String, categoryId: Int, startDate: Int) {
        self.categoryPathIds = categoryPathIds
        self.externalPathIds = externalPathIds
        self.endDate = endDate
        self.orderId = orderId
        self.isPrimary = isPrimary
        self.categoryName = categoryName
        self.categoryId = categoryId
        self.startDate = startDate
    }
    
    enum CodingKeys: String, CodingKey {
        case categoryPathIds = "categoryPathIds"
        case externalPathIds = "externalPathIds"
        case endDate = "endDate"
        case orderId = "orderId"
        case isPrimary = "isPrimary"
        case categoryName = "categoryName"
        case categoryId = "categoryId"
        case startDate = "startDate"
    }
}
