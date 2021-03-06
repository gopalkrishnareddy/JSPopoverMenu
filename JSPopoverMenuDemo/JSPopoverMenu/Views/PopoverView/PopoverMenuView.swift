
//
//  PopoverMenuVIew.swift
//  JSPopoverMenu
//
//  Created by 王俊硕 on 2017/11/4.
//  Copyright © 2017年 王俊硕. All rights reserved.
//

import UIKit

class JSPopoverMenuView: UIView {
    
    internal var removalResponder: UIControl! // 加载在父级视图上
    internal var menuCollection: UICollectionView!
    internal var headerView: UIView!
    internal var textField: JSModalTextField!
    internal var isOnScreen = false
    internal var animationOffset: CGFloat { get { return self.frame.height * 2 } }
    
    // Mark: 用于支持编辑的变量 Editing Supported Variables
    /// 内部编辑状态用的数据
    /// An internal data source. Used in editing mode.
    internal var dynamicData: [String]!
    /// Return the index of the add button.
    internal var addButtonIndex: Int { get { return dynamicData.count - 1 - deletedCells.count } }
    /// Return the index of the delete button.
    internal var deleteButtonIndex: Int { get { return dynamicData.count - 2 - deletedCells.count } }
    /// 记录被删除的cell，在完成按钮点击的确认删除，dismiss时清空. Recording the cells about to be deleted
    internal var deletedCells: [Int] = []
    /// 记录正在移动的Cell The index of the cell currently dragging.
    internal var selectedIndex: IndexPath?
    /// 被拖动cell的SnapView，用来实现拖动动画 The snapView of the selected cell.
    internal var animationCell: UIView?
    /// 在交换的时候赋值，记录上一次被交换的cell，用于手势结束居中animationView The indexPath of cell swaped last
    internal var panEndingIndex: IndexPath!
    /// 标明拖动事件是仅仅拖动还是要删除 Indicate whether the dragging is meant to delete the cell.
    internal var needDelete: Bool?
    /// Dragging Gesture Recognizer
    internal var panGesture: UIPanGestureRecognizer!

    /// 作为特殊按钮的初始所索引值，用于重置编辑状态
    internal let maxIndex = 99
    /// 外部输入数据 内部只有在编辑完成时调用以更新 初始化不会掉用willSet The input data source. Only be updated when editing done.
    public var data: [String]! { willSet(new) { dynamicData = new } }
    public var delegate: JSPopoverMenuViewDelegate! // PopoverMenuDelegate

    // UI 相关常量
    internal let screenWidth = UIScreen.main.bounds.width
    internal let screenHeight = UIScreen.main.bounds.height
    internal let baseColor = UIColor.from(hex: 0xf2f2f2)
    internal let selectedTextColor = UIColor.from(hex: 0xFD8B15)
    internal let defaultTextColor = UIColor.from(hex: 0x373636)

    // State Flag
    internal var isCollectionViewEditing = false
    // ======
    
    // Mark: Text Field
    /// 设置获取弹出式textField取消时调用的闭包
    public var textFieldDismissed: (()->Void)? {
        get { return textField.dismissCompleted }
        set { textField.dismissCompleted = newValue! }
    }
    /// 设置限制规则，如果只是长度限制，直接调用textFieldMaxInputLength即可
    public var textFieldShouldChangeCharacters: ((UITextField)->Bool)? {
        get { return textField.shouldChangeCharacters }
        set { textField.shouldChangeCharacters = newValue! }
    }
    /// 限制输入长度，如果没有设置textFieldShouldChangeCharacters 闭包，此属性生效。
    public var textFieldMaxInputLength: Int {
        get { return textField.maxInputLength }
        set { textField.maxInputLength = newValue }
    }
    
    
    
    init(height: CGFloat, data: [String]) {
        super.init(frame: CGRect(x: 0, y: -height*2, width: screenWidth, height: height))
        backgroundColor = baseColor
        self.data = data
        dynamicData = data
        isUserInteractionEnabled = true
        
        setupCollectionView()
        setupHeaderView()
        setupResponder()
        setupTextField()

        addSubview(menuCollection)
        addSubview(headerView)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
//    init()
}
