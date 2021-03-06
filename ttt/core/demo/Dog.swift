//
//  Dog.swift
//  ttt
//
//  Created by MJ Ling on 2018/1/12.
//  Copyright © 2018年 MJ Ling. All rights reserved.
//

import Foundation
import RealmSwift

///http://www.ganji.com/dog/
public final class Dog : RealmSwift.Object,MMJsonable,Decodable {
    public func ssn_jsonString() -> String {
        return "{\"breed\":\"\(breed)\",\"name\":\"\(name)\",\"brains\":\"\(brains)\",\"loyalty\":\"\(loyalty)\"}"
    }
    
    
    public static func ssn_from(json: String) -> Dog? {
        let js = JSONDecoder()
        let dog = try? js.decode(self, from: json.data(using: String.Encoding.utf8)!)
        return dog
    }
    
    @objc public dynamic var breed: String = "中华田园犬"
    @objc public dynamic var name: String = ""
    @objc public dynamic var brains: Int = 80 // MAX = 120
    @objc public dynamic var loyalty: Int = 80
    
    //https://www.jianshu.com/p/fef63f4cf6b4
    @objc override static open func primaryKey() -> String? { return "breed" }
}



