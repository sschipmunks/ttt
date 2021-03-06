//
//  ProfileViewController.swift
//  ttt
//
//  Created by MJ Ling on 2018/1/24.
//  Copyright © 2018年 MJ Ling. All rights reserved.
//

import Foundation

class ProfileViewController: MMUITableController<MMCellModel> {
    
    var profile:String = ""
    
    override func loadFetchs() -> [MMFetch<MMCellModel>] {
        //使用默认的数据库
        var list = [] as [MMCellModel]
        var f = MMFetchList(list:list)
        return [f]
    }
    
    override func onViewDidLoad() {
        super.onViewDidLoad()
        
        var profile = ssn_Arguments["profile"]?.string
        
        // Provisional request
        RPC.exec(task: { (idx, cmd, resp) -> Any in
            // do something
            return RPC.Result.empty
        }, feedback: self)

        // concurrent
        RPC.exec(cmds:[
            (ProfileViewController.getFirstRemoteData,"getFirst"),
            (ProfileViewController.getSecondRemoteData,"getSecond"),
            (ProfileViewController.getLastRemoteData,"getLast")
            ],
                 feedback:self)
        
        // serial
        RPC.exec(cmds:[
            (ProfileViewController.getFirstRemoteData,"getFirst"),
            (ProfileViewController.getSecondRemoteData,"getSecond"),
            (ProfileViewController.getLastRemoteData,"getLast")
            ],
                 queue:RPC.QueueModel.serial ,feedback:self)
    }
    
    
    class func getFirstRemoteData(_ index:RPC.Index, _ cmd:String?, _ resp:RPC.Response) throws -> Any {
        
        return "第一个任务请求数据"
    }
    
    class func getSecondRemoteData(_ index:RPC.Index, _ cmd:String?, _ resp:RPC.Response) throws -> Any {
        //取前一个数据
        let p = resp.getResult(RPC.Index(index.value-1), type: String.self)
        if p != nil {
            print("成功取到前面的数据:\"\(p!)\"")
        }
        return RPC.Result.empty
    }
    
    class func getLastRemoteData(_ index:RPC.Index, _ cmd:String?, _ resp:RPC.Response) throws -> Any {
        
        return RPC.Result.empty
    }
}

extension ProfileViewController : Feedback {
    func start(group: String, assembly: RPC.AssemblyObject) {
//        assembly.setModel(fetchs[0])
    }
    
    func finish(group: String, assembly: RPC.AssemblyObject) {
        //
    }
    
    func failed(index: RPC.Index, cmd: String, group: String, error: NSError) {
        //
    }
    
    func staged(index: RPC.Index, cmd: String, group: String, result: Any, assembly: RPC.AssemblyObject) {
        switch index {
        case .first:
            let node = SettingNode()
            node.title = "数据0" + cmd + " " + group
            node.subTitle = "99"
            fetchs[0]!.append(node)
            break
        default:
            let node = SettingNode()
            node.title = "数据\(index.value)" + cmd + " " + group
            node.subTitle = "99"
            fetchs[0]!.insert(node, atIndex: index.value)
        }
    }
    
    
}
