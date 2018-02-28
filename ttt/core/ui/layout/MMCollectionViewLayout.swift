//
//  MMCollectionViewLayout.swift
//  ttt
//
//  Created by lingminjun on 2018/2/27.
//  Copyright © 2018年 MJ Ling. All rights reserved.
//

import UIKit

let COLLECTION_HEADER_KIND = "Header"

struct LayoutConfig {
    var floating:Bool = false//存在某些cell飘浮，此选项开启，会造成性能损耗
    
    //默认UITable风格
    var columnCount:Int = 1
    var rowHeight:CGFloat = 44//固定行高(dp)，设置为0时，表示不固定行高；若设置大于零的有效值，则标识固定行高，不以委托返回高度计算
    var columnSpace:CGFloat = 1//(dp)
    var rowDefaultSpace:CGFloat = 1//默认行间距(dp)
    var insets:UIEdgeInsets = UIEdgeInsets.zero //header将忽略左右上下的间距，只有cell有效
}

@objc protocol MMCollectionViewDataSource : UICollectionViewDataSource {
    
    //可以漂浮停靠在界面顶部
    @objc optional func collectionView(_ collectionView: UICollectionView, canFloatingCellAt indexPath: IndexPath) -> Bool
    
    //cell的行高
    @objc optional func collectionView(_ collectionView: UICollectionView, heightForCellAt indexPath: IndexPath) -> CGFloat
    
    //cell是否SpanSize，返回值小于等于零时默认为1
    @objc optional func collectionView(_ collectionView: UICollectionView, spanSizeForCellAt indexPath: IndexPath) -> Int
    
}

//控制UICollect所有瀑布流，无section headerView和footerView支持，
class MMCollectionViewLayout: UICollectionViewLayout {
    private var _config:LayoutConfig = LayoutConfig()
    
    public init(_ config:LayoutConfig = LayoutConfig()) {
        super.init()
        _config = config;
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
//        fatalError("init(coder:) has not been implemented")
    }
    
    open var config:LayoutConfig {
        get { return _config; }
        set {
            _config = newValue
            if _config.columnCount <= 0 {//防止设置为非法数字
                _config.columnCount = 1
            }
            if _config.rowHeight < 0 {//防止设置为非法数字
                _config.rowHeight = 0
            }
            if _config.columnSpace < 0 {//防止设置为非法数字
                _config.columnSpace = 1
            }
            if _config.rowDefaultSpace < 0 {//防止设置为非法数字
                _config.rowDefaultSpace = 1
            }
            invalidateLayout()
        }
    }
    
//    weak fileprivate final var delegate: UICollectionViewDelegate? { get { return collectionView?.delegate } }
//    weak fileprivate final var collectionDataSource: UICollectionViewDataSource? { get { return collectionView?.dataSource } }
    weak fileprivate final var dataSource: MMCollectionViewDataSource? {
        get {
            guard let ds = self.collectionView?.dataSource else { return nil }
            if ds is MMCollectionViewDataSource {
                return ds as? MMCollectionViewDataSource
            }
            return nil
        }
    }
    
    
    //采用一次性布局
    private var _cellLayouts:[IndexPath:UICollectionViewLayoutAttributes] = [:]
    private var _headIndexs:[IndexPath] = [] //header形式
    private var _bottoms:[CGFloat] = []

    // 准备布局
    override func prepare() {
        super.prepare()
        
        //起始位计算
        _bottoms.removeAll()
        for _ in 0..<_config.columnCount {
            _bottoms.append(0.0)
        }
        _cellLayouts.removeAll();
        _headIndexs.removeAll();
        
        guard let view = self.collectionView else {
            return
        }
        
        let ds = self.dataSource
        let respondCanFloating = ds == nil ? false : ds!.responds(to: #selector(MMCollectionViewDataSource.collectionView(_:canFloatingCellAt:)))
        let respondHeightForCell = ds == nil ? false : ds!.responds(to: #selector(MMCollectionViewDataSource.collectionView(_:heightForCellAt:)))
        let respondSpanSize = ds == nil ? false : ds!.responds(to: #selector(MMCollectionViewDataSource.collectionView(_:spanSizeForCellAt:)))
        
        let floating = _config.floating
        let rowHeight = _config.rowHeight
        let columnCount = _config.columnCount
        let floatingWidth = view.bounds.size.width
//        let lineWidth = view.bounds.size.width - (_config.insets.left + _config.insets.right)
        let cellWidth = (view.bounds.size.width - (_config.insets.left + _config.insets.right) - _config.columnSpace * CGFloat(columnCount - 1)) / CGFloat(columnCount)
        
        
        let sectionCount = view.numberOfSections
        
        for section in 0..<sectionCount {
            
            let cellCount = view.numberOfItems(inSection: section);
            for row in 0..<cellCount {
                
                let indexPath = IndexPath(row: row, section: section)
                
                //是否漂浮
                var isFloating:Bool = _config.floating
                if floating && respondCanFloating {
                    isFloating = ds!.collectionView!(view, canFloatingCellAt: indexPath)
                }
                if isFloating {
                    _headIndexs.append(indexPath)
                }
                
                //行高
                var height:CGFloat = rowHeight
                if height == 0 && respondHeightForCell {
                    height = ds!.collectionView!(view, heightForCellAt: indexPath)
                }
            
                //占用各数
                var spanSize = 1
                if isFloating {//肯定是占满一行
                    spanSize = columnCount
                } else if columnCount > 1 && respondSpanSize {
                    spanSize = ds!.collectionView!(view, spanSizeForCellAt: indexPath)
                    if spanSize > columnCount {
                        spanSize = columnCount
                    }
                }
                
                //取布局属性对象
                var attributes:UICollectionViewLayoutAttributes!
                if isFloating {
                    attributes = UICollectionViewLayoutAttributes(forSupplementaryViewOfKind: COLLECTION_HEADER_KIND, with: indexPath)
                } else {
                    attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)//layoutAttributesForCellWithIndexPath
                }
                _cellLayouts[indexPath] = attributes//记录下来，防止反复创建
                
                var suitableSetion = self.sectionOfLessHeight
                var y = _bottoms[suitableSetion] //起始位置
                
                //说明当前位置并不合适,换到新的一行开始处理
                if isFloating || suitableSetion + spanSize > columnCount {
                    let mostSetion = self.sectionOfMostHeight
                    y = _bottoms[mostSetion] //起始位置
                    suitableSetion = 0 //new line
                }
                
                //起始行特别处理
                if section == 0 && row == 0 && y == 0.0 && !isFloating {
                    y = y + _config.insets.top
                }
                
                //x起始位和宽度
                var x = _config.insets.left + (cellWidth + _config.columnSpace) * CGFloat(suitableSetion)
                var width = cellWidth * CGFloat(spanSize) + _config.columnSpace * CGFloat(spanSize - 1)
                
                //对于floating,满行处理
                if isFloating {
                    x = 0
                    width = floatingWidth
                }
                
                attributes.frame = CGRect(x:x, y:y, width:width, height:height)
                
                //更新每列位置信息
                for index in suitableSetion..<spanSize {
                    _bottoms[index] = y + height + _config.rowDefaultSpace
                }
            }
        }
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        
        //存在飘浮cell
        let hasFloating = !_headIndexs.isEmpty
        
        var csets:Set<IndexPath> = Set<IndexPath>() //所有被列入的key
//        var hsets:Set<IndexPath> = Set<IndexPath>() //所有被列入header的key
        var minCIndexPath:IndexPath? = nil
        var minHIndexPath:IndexPath? = nil
        
        //遍历所有 Attributes 看看哪些符合 rect
        var list:[UICollectionViewLayoutAttributes] = []
        _cellLayouts.forEach { (key,value) in
            
            //存在交集
            if rect.intersects(value.frame) {
                list.append(value)
                
                csets.insert(key)
                
                //记录正常情况下包含的set
                if hasFloating && value.representedElementKind == COLLECTION_HEADER_KIND {
//                    hsets.insert(key)
                    
                    //取最小位置的header
                    if minHIndexPath == nil || minHIndexPath! > key {
                        minHIndexPath = key
                    }
                } else {//取最小位置的header
                    if minCIndexPath == nil || minCIndexPath! > key {
                        minCIndexPath = key
                    }
                }
            }
        }
        
        //没有飘浮处理，直接返回好了
        if !hasFloating {
            return list
        }
        
        
        if minHIndexPath == nil && (minCIndexPath == nil || _headIndexs[0] <= minCIndexPath!) {
            minHIndexPath = _headIndexs[0]
        }
        
        //往前寻找一个飘浮的cell
        if minCIndexPath != nil && minHIndexPath != nil && minCIndexPath! < minHIndexPath! {
            if let idx = _headIndexs.index(of: minHIndexPath!) {
                if idx > 0 {
                    minHIndexPath = _headIndexs[idx - 1]
                }
            }
        }
        
        if minHIndexPath == nil { return list }
        
        guard let view = self.collectionView else {
            return list
        }
        
        guard let value = _cellLayouts[minHIndexPath!] else { return list }
        var frame = value.frame
        
        let viewTop = view.contentOffset.y + view.contentInset.top //表头
        if viewTop < frame.origin.y {
            return list
        }
        
        //调整最小值
        var nextHeightTop = viewTop + 2*UIScreen.main.bounds.height //下一个head的头，默认值设置得比较大
        if minHIndexPath != _headIndexs.last {//不等于最后一个,取下一个header的顶部
            if let next = _headIndexs.index(of: minHIndexPath!) {
                if let nextValue = _cellLayouts[_headIndexs[(next + 1)]] {
                    nextHeightTop = nextValue.frame.origin.y
                }
            }
        }
        
        frame.origin.y = min(nextHeightTop - frame.size.height, viewTop)
        value.frame = frame;
        
        return list
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard let attributes = _cellLayouts[indexPath] else { return nil }
        if attributes.representedElementKind == COLLECTION_HEADER_KIND {
            return nil
        } else {
            return attributes
        }
    }
    
    override func layoutAttributesForSupplementaryView(ofKind elementKind: String, at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard let attributes = _cellLayouts[indexPath] else { return nil }
        if attributes.representedElementKind == COLLECTION_HEADER_KIND {
            return attributes
        } else {
            return nil
        }
    }
    
//    // If the layout supports any supplementary or decoration view types, it should also implement the respective atIndexPath: methods for those types.
//    - (nullable NSArray<__kindof UICollectionViewLayoutAttributes *> *)layoutAttributesForElementsInRect:(CGRect)rect; // return an array layout attributes instances for all the views in the given rect
//    - (nullable UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath;
//    - (nullable UICollectionViewLayoutAttributes *)layoutAttributesForSupplementaryViewOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath;
//    - (nullable UICollectionViewLayoutAttributes *)layoutAttributesForDecorationViewOfKind:(NSString*)elementKind atIndexPath:(NSIndexPath *)indexPath;
//
//    - (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds; // return YES to cause the collection view to requery the layout for geometry information
//    - (UICollectionViewLayoutInvalidationContext *)invalidationContextForBoundsChange:(CGRect)newBounds NS_AVAILABLE_IOS(7_0);
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return _config.floating
    }
    
    override var collectionViewContentSize: CGSize {
        get {
            guard let view = self.collectionView else {
                return CGSize.zero
            }
            let width = view.bounds.size.width
            let height = _config.insets.bottom + _bottoms[self.sectionOfMostHeight]
            return CGSize(width:width,height:height)
        }
    }
    
    
    fileprivate final var sectionOfLessHeight:Int {
        get {
            var minIndex:Int = 0
            for index in 1..<_config.columnCount {
                if _bottoms[index] < _bottoms[minIndex] {
                    minIndex = index
                }
            }
            return minIndex
        }
    }
    
    fileprivate final var sectionOfMostHeight:Int {
        get {
            var maxIndex:Int = 0
            for index in 1..<_config.columnCount {
                if _bottoms[index] > _bottoms[maxIndex] {
                    maxIndex = index
                }
            }
            return maxIndex
        }
    }
}
