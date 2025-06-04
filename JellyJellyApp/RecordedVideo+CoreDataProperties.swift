//
//  RecordedVideo+CoreDataProperties.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/3/25.
//
//

import Foundation
import CoreData


extension RecordedVideo {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<RecordedVideo> {
        return NSFetchRequest<RecordedVideo>(entityName: "RecordedVideo")
    }

    @NSManaged public var backVideoURL: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var frontVideoURL: String?

}

extension RecordedVideo : Identifiable {

}
