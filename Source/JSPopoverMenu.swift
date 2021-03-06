//
//  JSPopoverMenu.swift
//  JSPopoverMenu
//
//  Created by 王俊硕 on 2017/11/4.
//  Copyright © 2017年 王俊硕. All rights reserved.
//

import UIKit

class JSPopoverMenu: UIView {
    
    fileprivate var removalResponder: UIControl! // 加载在父级视图上
    fileprivate var menuCollection: UICollectionView!
    fileprivate var headerView: UIView!
    fileprivate var textField: JSModalTextField!
    fileprivate var isOnScreen = false
    fileprivate var animationOffset: CGFloat { get { return self.frame.height * 2 } }
    
    // Mark: 用于支持编辑的变量
    /// 内部编辑状态用的数据
    /// An fileprivate data source. Used in editing mode.
    fileprivate var dynamicData: [String]!
    /// Return the index of the add button.
    fileprivate var addButtonIndex: Int { get { return dynamicData.count - 1 - deletedCells.count } }
    /// Return the index of the delete button.
    fileprivate var deleteButtonIndex: Int { get { return dynamicData.count - 2 - deletedCells.count } }
    /// 记录被删除的cell，在完成按钮点击的确认删除，dismiss时清空. Recording the cells about to be deleted
    fileprivate var deletedCells: [Int] = []
    /// 记录正在移动的Cell The index of the cell currently dragging.
    fileprivate var selectedIndex: IndexPath?
    /// 被拖动cell的SnapView，用来实现拖动动画 The snapView of the selected cell.
    fileprivate var animationCell: UIView?
    /// 在交换的时候赋值，记录上一次被交换的cell，用于手势结束居中animationView The indexPath of cell swaped last
    fileprivate var panEndingIndex: IndexPath!
    /// 标明拖动事件是仅仅拖动还是要删除 Indicate whether the dragging is meant to delete the cell.
    fileprivate var needDelete: Bool?
    /// Dragging Gesture Recognizer
    fileprivate var panGesture: UIPanGestureRecognizer!
    
    /// 作为特殊按钮的初始所索引值，用于重置编辑状态
    fileprivate let maxIndex = 99
    /// 外部输入数据 内部只有在编辑完成时调用以更新 初始化不会掉用willSet The input data source. Only be updated when editing done.
    public var data: [String]! { willSet(new) { dynamicData = new } }
    public var delegate: JSPopoverMenuDelegate! // PopoverMenuDelegate

    // UI 相关常量
    fileprivate let screenWidth = UIScreen.main.bounds.width
    fileprivate let screenHeight = UIScreen.main.bounds.height
    fileprivate let baseColor = UIColor.from(hex: 0xf2f2f2)
    fileprivate let selectedTextColor = UIColor.from(hex: 0xFD8B15)
    fileprivate let defaultTextColor = UIColor.from(hex: 0x373636)
    
    // State Marker
    var isCollectionViewEditing = false
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
        
        addSubview(menuCollection)
        addSubview(headerView)
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    //    init()
}

// Mark: - Basic Setting
extension JSPopoverMenu {
    
    fileprivate func setupResponder() {
        removalResponder = UIControl(frame: CGRect(origin: CGPoint(x: 0, y: 0), size: UIScreen.main.bounds.size))
        removalResponder.addTarget(self, action: #selector(offDuty), for: .allEvents)
    }
    fileprivate func setupTextField() {
        textField = JSModalTextField(frame: CGRect(x: 0, y: 60, width: 230, height: 120))
        textField.center = CGPoint(x: screenWidth/2, y: screenHeight/2-90)
        textField.confirmed = { value in
            if let tag = value {
                self.dynamicData.insert(tag, at: self.deleteButtonIndex)
                print(self.dynamicData)
                self.menuCollection.insertItems(at: [IndexPath.ofRow(self.deleteButtonIndex-1)])
                self.delegate.popoverMenu(self, newTag: tag)
            }
        }
    }
    fileprivate func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.headerReferenceSize = CGSize(width: 0, height: 0)
        layout.sectionInset = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        menuCollection = UICollectionView(frame: CGRect(x: 0, y: 35, width: screenWidth, height: 150)
            , collectionViewLayout: layout)
        menuCollection.register(JSMenuCell.self, forCellWithReuseIdentifier: "Cell")
        menuCollection.backgroundColor = baseColor
        menuCollection.delegate = self
        menuCollection.dataSource = self
        menuCollection.tag = 10011
    }
    /// 设置 顶部视图
    fileprivate func setupHeaderView() {
        headerView = UIView(frame: CGRect(x: 0, y: 0, width: screenWidth, height: 30))
        headerView.tag = 10015
        headerView.backgroundColor = baseColor
        
        // 类别/取消 按钮
        let leftButton = JSHeaderButton(originX: 10, state: JSButtonState.group)
        leftButton.addTarget(self, action: #selector(self.leftHeaderButtonTapped), for: .touchUpInside)
        leftButton.tag = 10012
        // 编辑 按钮
        let rightButton = JSHeaderButton(originX: screenWidth-50, state: JSButtonState.edit)
        rightButton.addTarget(self, action: #selector(self.rightHeaderButtonTapped), for: .touchUpInside)
        rightButton.tag = 10013
        
        
        headerView.addSubview(leftButton)
        headerView.addSubview(rightButton)
    }
    
    @objc func leftHeaderButtonTapped(sender leftButton: JSHeaderButton) {
        if leftButton.currentState == JSButtonState.reset {
            resetMenu(forEdting: true)
        }
    }
    @objc func rightHeaderButtonTapped(sender rightButton: JSHeaderButton) {
        let leftButton = headerView.viewWithTag(10012) as! JSHeaderButton
        if rightButton.currentState == JSButtonState.done {// 退出编辑 Edit Done
            rightButton.switchTo(state: .edit)
            leftButton.switchTo(state: .group)
            finishEditing() // 完成编辑 保存
        } else { // 进入编辑 Edit Start
            rightButton.switchTo(state: .done)
            leftButton.switchTo(state: .reset)
            startEditing() // 开始编辑
        }
    }
    
    /// 开始编辑调用 添加拖动手势 Called when editing started. Add drag gesture.
    private func startEditing() {
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(self.gestureHandler(gesture:)))
        menuCollection.addGestureRecognizer(panGesture)
        dynamicData.append(contentsOf: ["delete", "add"])
        menuCollection.insertItems(at: [IndexPath(row: dynamicData.count-2, section: 0), IndexPath(row: dynamicData.count-1, section:0)])
        isCollectionViewEditing = true
    }
    /// 完成编辑 保存编辑结果 Save editing result
    private func finishEditing() {
        
        // 删除拖动手势 Remove dragging gesture
        menuCollection.removeGestureRecognizer(panGesture)
        // 更新数据源 删除删除按钮和添加按钮 Update dynamic data sdource
        for _ in 1...deletedCells.count+2 {
            dynamicData.removeLast()
            menuCollection.deleteItems(at: [IndexPath(row: dynamicData.count, section: 0)]) // 因为已经removeLast()所以不用-1
        }
        // 更新静态数据源 Update static data source
        data = dynamicData
        // 通知控制器 inform the delegate
        //        editCompleted()
        delegate.popoverMenu(self, updatedData: data)
        // 重置寄存器 reset variables
        deletedCells = []
        isCollectionViewEditing = false
        menuCollection.allowsSelection = true
    }
    /// 取消编辑 丢弃内容 结束编辑 Cancel editing. Abandon editing content. End editing
    private func cancelEdting() {
        if dynamicData.count != data.count+2 {
            //alert
            print("gonna discard what you've already done")
        }
        resetMenu(forEdting: false)
    }
    
    //FIXME: 没有恢复交换过但没有删除的Cell 只对特殊按钮后面的待删除项进行还原
    
    /// 重置编辑数据 恢复至编辑开始的状态 Reset data to the beginning.
    private func resetMenu(forEdting: Bool) {
        
        if forEdting {
            resetCells()
        } else {
            // 直接丢弃 从cancel调用
            dynamicData = data
            menuCollection.reloadData()
        }
        deletedCells = []
        
    }
    /// 复原cell动画 Animatable reset
    private func resetCells() {
        var indexes = getOrignialIndexes(of: dynamicData)
        deletedCells = []
        var staticIndexes = indexes
        for _ in 1...staticIndexes.count {
            if let last = staticIndexes.popLast(), last != 99 { // last 是原始序号
                let lastItem = dynamicData.popLast()!
                let p = findPosition(of: last, in: indexes)
                print("Gonna move last: \(last) to new position: \(p)")
                indexes.insert(last, at: p) // 同步更新
                dynamicData.insert(lastItem, at: p) // 更新数据源
                menuCollection.moveItem(at: IndexPath.ofRow(dynamicData.count-1), to: IndexPath.ofRow(p)) // 更新CollectionView 每次更新都是dynamicData的最后一项
                dischargeCell(at: IndexPath.ofRow(p))
            } else {
                break //return
            }
        }
        
    }
    private func findPosition(of item: Int, in array: [Int] ) -> Int {
        for (key, element) in array.enumerated() { if item < element { return key } }
        return array.count-1-2 // 最大一个 除掉两个特殊按钮
    }
    /// 找到最初的序号以排序恢复 Find the original position of `dynamicData` item in `data`.
    private func getOrignialIndexes(of array: [String]) -> [Int] {
        return array.map(){ self.data.index(of: $0) ?? 99 } // 使特殊按钮的值尽可能大，这样不会移动到它们后面去 Set the special button a large Int to prevent them from being move to the end when sort by the index
    }
    /// 恢复cell样式 Reset the cell's style
    private func dischargeCell(at indexPath: IndexPath) {
        let cell = menuCollection.cellForItem(at: indexPath) as! JSMenuCell
        cell.discharged()
    }
    /// 恢复单个被删除的Cell 响应点击事件 Recover a cell. Called when user tap single cell in about to delete area
    fileprivate func recoverCell(from index: IndexPath) {
        
        let cell = menuCollection.cellForItem(at: index) as! JSMenuCell
        let toIndex = IndexPath(row: data.index(of: cell.label!.text!)!, section: 0)
        // 更新数据源 update data source
        let element = dynamicData[index.row]
        dynamicData.remove(at: index.row)
        dynamicData.insert(element, at: toIndex.row)
        
        print("move: \(index), to index: \(toIndex), dynamicData: \(dynamicData)")
        menuCollection.moveItem(at: index, to: toIndex)
        
    }
}

// Mark: - Protocal
protocol JSPopoverMenuDelegate: NSObjectProtocol {
    var baseView: UIView { get }
    func popoverMenu(_ popoverMenu: JSPopoverMenu, didSelectedAt indexPath: IndexPath)
    func popoverMenu(_ popoverMenu: JSPopoverMenu, updatedData data: [String])
    func popoverMenu(_ popoverMenu: JSPopoverMenu, newTag value: String)
}

// Mark: - Gesture handler
extension JSPopoverMenu {
    @objc fileprivate func gestureHandler(gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began: panBegan(gesture: gesture)
        case .changed: panChanged(gesture: gesture)
        case .ended: panEnded(gesture: gesture)
        default:
            break
        }
    }
    private func panBegan(gesture: UIPanGestureRecognizer)  {
        guard let selectedIndexPath = menuCollection.indexPathForItem(at: gesture.location(in: menuCollection)),
            (selectedIndexPath.row < deleteButtonIndex) else { return }
        selectedIndex = selectedIndexPath
        (menuCollection.cellForItem(at: selectedIndexPath) as! JSMenuCell).detained()
        
        let snapView = menuCollection.cellForItem(at: selectedIndexPath)!.snapshotView(afterScreenUpdates: false)
        animationCell = snapView
        animationCell!.isHidden = true
        menuCollection.addSubview(animationCell!)
    }
    private func panChanged(gesture: UIPanGestureRecognizer)  {
        guard let beginningIndex = selectedIndex else { return }
        // 1. 添加AnimationCell
        let point = gesture.location(in: menuCollection)
        animationCell?.center = point
        animationCell?.isHidden = false
        // 2. 获取当前坐标对应的cell
        guard let index = menuCollection.indexPathForItem(at: point) else { return }
        //                print("Move at index: \(index), seletedIndex: \(selectedIndex), endingIndex: \(panEndingIndex)")
        // 3. 如果Cell.index是自身或者上一个交换的cell 则不执行 否则会一直交换
        guard index != selectedIndex, index != panEndingIndex ?? nil else { return }
        needDelete = false
        panEndingIndex = index
        // 4. 如果是添加按钮 或者 删除按钮 则不移动
        if index.row != deleteButtonIndex && index.row != addButtonIndex {
            
            // 交换Cell 交换之后 indexPath也会更新 所以数据原也要更新
            let tmp = dynamicData[beginningIndex.row]
            dynamicData[beginningIndex.row] = dynamicData[index.row]
            dynamicData[index.row] = tmp
            menuCollection.moveItem(at: beginningIndex, to: index)
            
            selectedIndex = index
        } else {
            // 标记为待删除
            needDelete = true
        }
    }
    private func panEnded(gesture: UIPanGestureRecognizer)  {
        guard animationCell != nil else { return }
        let cell = menuCollection.cellForItem(at: selectedIndex!) as! JSMenuCell
        
        if needDelete ?? false { // 首次拖动到空的地方为空
            // 添加撤销操作
            guard (menuCollection.cellForItem(at: selectedIndex!) != nil) else { return }
            //            let button = cell.viewWithTag(100012) as! UIButton
            //            button.isEnabled = true
            //
            // 移至队尾
            menuCollection.moveItem(at: selectedIndex!, to: IndexPath(row: dynamicData.count - 1, section: 0)) // 移动cell
            let tmp = dynamicData[selectedIndex!.row] // 移动数据源
            dynamicData.remove(at: selectedIndex!.row)
            dynamicData.append(tmp)
            deletedCells.append(dynamicData.count - 1) // 添加至待删除
            //            (menuCollection.cellForItem(at: IndexPath(row:  dynamicData.count - 1, section: 0)) as! JSMenuCell).detained() // 每次新删除的项目肯定在最后
        } else { cell.discharged() }
        
        // 如果中间发生过一次交换， 那么selectedIndex记录的值还是原来的值， 但是实际对应的cell已经是交换过去的cell了
        // 重置参数
        needDelete = false
        
        UIView.animate(withDuration: 0.3) {
            self.animationCell?.center = (self.menuCollection.cellForItem(at: self.panEndingIndex ?? self.selectedIndex!)?.center)! //如果没有结束index说明没有交换过，那么久居中到起始cell
            self.animationCell?.removeFromSuperview()
            self.animationCell = nil
            self.selectedIndex = nil
            
            self.panEndingIndex = nil
            
        }
    }
}


// Mark: -Presentation
extension JSPopoverMenu {
    
    public func show(completion closure: (()->Void)?) {
        if !isOnScreen {
            delegate.baseView.addSubview(removalResponder)
            delegate.baseView.addSubview(self)
            isOnScreen = true
            UIView.animate(withDuration: 0.3, animations: {
                self.frame = self.frame.move(x: 0, y: self.animationOffset) //navigationBar 不透明 无高度
            }) { (_) in
                closure?()
            }
        }
        
    }
    public func dismiss(completion closure: (()->Void)?) { // @escaping?
        if isOnScreen {
            isOnScreen = false
            UIView.animate(withDuration: 0.3, animations: {
                self.frame = self.frame.move(x: 0, y: -self.animationOffset)
            }, completion: { (_) in
                self.removeFromSuperview()
                self.removalResponder.removeFromSuperview()
                closure?()
                print(self.frame)
            })
        }
    }
    public func quickSwitch() {
        isOnScreen ? dismiss(completion: nil) : show(completion: nil)
    }
    @objc fileprivate func offDuty() {
        dismiss(completion: nil)
    }
}


// Mark: - UICollectionView Protocals
extension JSPopoverMenu: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 63, height: 30)
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 5
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 5
    }
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        let limitation = dynamicData.count - 1 - deletedCells.count
        return indexPath.row < limitation ? false : true
    }
    /// 只有待删除的cell才会调用这个事件
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let cell = collectionView.cellForItem(at: indexPath) as! JSMenuCell
        if isCollectionViewEditing {
            if (cell.label != nil) {
                cell.discharged()
                recoverCell(from: indexPath)
                deletedCells.remove(at: data.count+2-indexPath.row-1)// 总labrls=data.count+2; indexPath.row从0开始
            } else {
                // Add
                textField.show(onView: delegate.baseView) {
                }
            }
        } else {
            delegate.popoverMenu(self, didSelectedAt: indexPath)
            dismiss(completion: nil)
        }
    }
}

extension JSPopoverMenu: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return dynamicData.count
    }
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as! JSMenuCell
        
        if dynamicData[indexPath.row] == "add" {
            cell.setupImage(name: "cross")
        } else if dynamicData[indexPath.row] == "delete" {
            cell.setupImage(name: "dustbin")
        } else {
            cell.setup(title: dynamicData[indexPath.row])
        }
        return cell
    }
    
}
extension JSPopoverMenu: UICollectionViewDelegateFlowLayout {
    
}
// Mark: - HeaderButton
class JSHeaderButton: UIButton {
    
    public var currentState: JSButtonState {
        get { return buttonState }
        set(state) {
            buttonState = state
            switchTo(state: state)
        }
    }
    
    private var buttonState: JSButtonState!
    private let textColor = UIColor.from(hex: 0x939393)
    private let hightTextColor = UIColor.from(hex: 0xFD8B15)
    
    init(originX x: CGFloat, state: JSButtonState) {
        super.init(frame: CGRect(x: x, y: 0, width: 40, height: 30))
        switchTo(state: state)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func switchTo(state: JSButtonState) {
        isEnabled = true
        buttonState = state
        buttonState.applyTo(self)
    }
    
}

// Mark: - Menu Cell
class JSMenuCell: UICollectionViewCell {
    var label: UILabel?
    var imageView: UIImageView?
    
    public func setup(title: String) {
        contentView.subviews.forEach() { $0.removeFromSuperview() }
        
        backgroundColor = .from(hex: 0xe6e6e6)
        layer.cornerRadius = 3
        
        label = UILabel(frame: bounds)
        label!.textAlignment = .center
        
        label!.attributedText = NSAttributedString(string: title, attributes: [NSAttributedStringKey.foregroundColor: UIColor.from(hex: 0x363636), NSAttributedStringKey.font: UIFont.systemFont(ofSize: 13)])
        //        label.tag = 100013
        contentView.addSubview(label!)
    }
    public func setupImage(name: String) {
        contentView.subviews.forEach() { $0.removeFromSuperview() }
        
        layer.cornerRadius = 3
        clipsToBounds = true
        
        imageView = UIImageView(image: UIImage(named: name))
        imageView!.frame = bounds
        imageView!.contentMode = .scaleAspectFit
        contentView.addSubview(imageView!)
    }
    /// Turn backgroud to gray. Called when the cell is draging.
    public func moving() {
        guard (label != nil) else { return }
        label!.textColor = .from(hex: 0xffffff)
        backgroundColor = .from(hex: 0xFD8B15) //Orange
    }
    public func halt() {
        guard (label != nil) else { return }
        label!.textColor = .from(hex: 0x363636) //Black
        backgroundColor = .from(hex: 0xe6e6e6) //Gray
    }
    public func detained() {
        guard (label != nil) else { return }
        label!.alpha = 0.3
    }
    public func discharged() {
        guard (label != nil) else { return }
        label!.alpha = 1
    }
}
// Mark: - Data Model
enum JSButtonState: String {
    case done = "Done"
    case reset = "Reset"
    case edit = "Edit"
    case group = "Tags"
    //TODO: 接受参数支持自定义颜色
    var textColor: UIColor {
        switch self {
        case .group:
            return UIColor.from(hex: 0x939393)
        default:
            return UIColor.from(hex: 0xFD8B15)
        }
    }
    /// Apply string to the button
    func applyTo(_ button: UIButton) {
        if self == .edit || self == .done {
            button.contentHorizontalAlignment = .right
            button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 3)
        } else {
            button.contentHorizontalAlignment = .left
            button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 3, bottom: 0, right: 0)
        }
        button.setAttributedTitle(NSAttributedString(string: self.rawValue, attributes: [NSAttributedStringKey.foregroundColor: textColor, NSAttributedStringKey.font: UIFont.systemFont(ofSize: 12)]), for: .normal)
    }
}

extension UIColor {
    class func from(hex: Int) -> UIColor {
        let r = (hex & 0xff0000) >> 16
        let g = (hex & 0x00ff00) >> 8
        let b = hex & 0x0000ff
        return UIColor(red: CGFloat(r)/255, green: CGFloat(g)/255, blue: CGFloat(b)/255, alpha: 1)
    }
}
extension IndexPath {
    static func ofRow(_ row: Int) -> IndexPath {
        return IndexPath(row: row, section: 0)
    }
}
extension CGRect {
    func scale(x: CGFloat ,y: CGFloat) -> CGRect {
        return CGRect(origin: origin, size: CGSize(width: width*x, height: height*y))
    }
    func move(x: CGFloat, y: CGFloat) -> CGRect {
        return CGRect(x: origin.x + x, y: origin.y + y, width: width, height: height)
    }
}



