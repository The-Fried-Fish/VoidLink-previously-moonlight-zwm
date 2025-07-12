//
//  KeyManagerViewController.swift
//  VoidLink
//
//  Created by True砖家 on 2024/7/23.
//  Copyright © 2024 True砖家 on Bilibili. All rights reserved.
//

import UIKit

@objc protocol ToolboxSpecialEntryDelegate: NSObjectProtocol {
    @objc optional func openWidgetLayoutTool()
    @objc optional func switchWidgetProfile()
    @objc optional func bringUpSoftKeyboard()
    @objc optional func enterPip()
}


@objc public class ToolboxViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    @objc weak var specialEntryDelegate: ToolboxSpecialEntryDelegate?
    public let tableView = UITableView()
    private let addButton = UIButton(type: .system)
    private let deleteButton = UIButton(type: .system)
    private let editButton = UIButton(type: .system)
    private let exitButton = UIButton(type: .system)
    private let pinButton = UIButton(type: .system)
    private let viewBackgroundColor = UIColor(white: 0.2, alpha: 0.8);
    private let highlightColor = UIColor(white: 0.39, alpha: 0.8);
    private let titleLabel = UILabel()
    @objc public var specialEntries : NSMutableArray = ["widgetSwitchTool", "widgetLayoutTool", "bringUpSoftKeyboard", "enterPip"]
    private let specialEntryAliasDic : [String:String] = [
        "widgetSwitchTool":SwiftLocalizationHelper.localizedString(forKey: "[ Switch among on-screen widget profiles ]"),
        "widgetLayoutTool":SwiftLocalizationHelper.localizedString(forKey: "[ Open on-screen widget tool ]"),
        "bringUpSoftKeyboard":SwiftLocalizationHelper.localizedString(forKey: "[ Bring up soft keyboard ]"),
        "enterPip":SwiftLocalizationHelper.localizedString(forKey: "[ Enter picture-in-picture mode ]")
    ]
    
    private var viewPinned: Bool = false
    private var isEditingMode: Bool = false {
        didSet {
            updateEditingMode()
        }
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        setupViews()
        updateEditingMode()
        
        tableView.dataSource = self
        tableView.delegate = self
        
        // Register the cell class
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        //pass self to the CommandManager
        CommandManager.shared.viewController = self
    }
    
    
    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        //setupConstraints()
        reloadTableView()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        //setupConstraints()
    }

    
    private func setupViews() {
        
        // Set corner radius
        view.layer.cornerRadius = 20  // Adjust the corner radius
        view.layer.masksToBounds = true
        
        // Set up the title label
        titleLabel.text = SwiftLocalizationHelper.localizedString(forKey: "Toolbox")
        titleLabel.font = UIFont.boldSystemFont(ofSize: 20)  // Adjust font size as needed
        titleLabel.textColor = UIColor.white  // Adjust color as needed
        titleLabel.textAlignment = .center
        view.addSubview(titleLabel)
        
        view.backgroundColor = viewBackgroundColor
        tableView.backgroundColor = .clear
        tableView.rowHeight = isIPhone() ? 47 : 60
        tableView.separatorColor = highlightColor
        // Configure buttons
        addButton.setTitle(SwiftLocalizationHelper.localizedString(forKey: "Add / Duplicate"), for: .normal)
        deleteButton.setTitle(SwiftLocalizationHelper.localizedString(forKey: "Delete"), for: .normal)
        editButton.setTitle(SwiftLocalizationHelper.localizedString(forKey: "Edit"), for: .normal)
        exitButton.setTitle(SwiftLocalizationHelper.localizedString(forKey: "Exit"), for: .normal)
        pinButton.setTitle("📌", for: .normal)
        addButton.titleLabel?.font = UIFont.systemFont(ofSize: 20) // Adjust the size as needed
        deleteButton.titleLabel?.font = UIFont.systemFont(ofSize: 20)
        editButton.titleLabel?.font = UIFont.systemFont(ofSize: 20)
        exitButton.titleLabel?.font = UIFont.systemFont(ofSize: 20)
        pinButton.titleLabel?.font = UIFont.systemFont(ofSize: 20)

        // Add subviews
        view.addSubview(tableView)
        view.addSubview(addButton)
        view.addSubview(deleteButton)
        view.addSubview(editButton)
        view.addSubview(exitButton)
        view.addSubview(pinButton)
        
        // Setup button targets
        addButton.addTarget(self, action: #selector(addButtonTapped), for: .touchUpInside)
        deleteButton.addTarget(self, action: #selector(deleteButtonTapped), for: .touchUpInside)
        editButton.addTarget(self, action: #selector(editButtonTapped), for: .touchUpInside)
        exitButton.addTarget(self, action: #selector(exitButtonTapped), for: .touchUpInside)
        pinButton.addTarget(self, action: #selector(pinButtonTapped), for: .touchUpInside)
        pinButton.contentEdgeInsets = UIEdgeInsets(top: 7, left: 20, bottom: 7, right: 20)

    }
    
    public override func updateViewConstraints() {
        self.setupConstraints()
        super.updateViewConstraints()
    }

    private func isIPhone()->Bool {
        return UIDevice.current.userInterfaceIdiom == .phone
    }
    
    @objc public func setupConstraints() {
        
        guard view.superview != nil else {
            return
        }
                
        NSLayoutConstraint.deactivate(view.constraints)

        view.translatesAutoresizingMaskIntoConstraints = false
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        addButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        editButton.translatesAutoresizingMaskIntoConstraints = false
        exitButton.translatesAutoresizingMaskIntoConstraints = false
        pinButton.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            
            // Set the width and height of the view
            
            view.widthAnchor.constraint(equalTo: view.superview!.widthAnchor, multiplier: isIPhone() ? 0.7 : 0.8),
            view.heightAnchor.constraint(equalTo: view.superview!.heightAnchor, multiplier: 0.99),
            // Set the width and height of the view
            //view.leadingAnchor.constraint(equalTo: view.superview!.leadingAnchor, constant: 60),
            //view.trailingAnchor.constraint(equalTo: view.superview!.trailingAnchor, constant: -60),

            // Center the view horizontally and vertically
            view.centerXAnchor.constraint(equalTo: view.superview!.centerXAnchor),
            view.centerYAnchor.constraint(equalTo: view.superview!.centerYAnchor),
            
            // ViewTitle constrains
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 13.5),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            
            
            // TableView constraints
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            tableView.topAnchor.constraint(equalTo: view.topAnchor, constant: 50),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -60),
            
            // ExitButton constraints
            exitButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 25),
            exitButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),
            
            // EditButton constraints
            editButton.leadingAnchor.constraint(equalTo: exitButton.trailingAnchor, constant: 50),
            editButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),
            
            // AddButton constraints
            addButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -25),
            addButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),
            
            // DeleteButton constraints
            deleteButton.trailingAnchor.constraint(equalTo: addButton.leadingAnchor, constant: -50),
            deleteButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),
            
            // DeleteButton constraints
            pinButton.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -50),
            pinButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),
        ])
    }


    private func updateEditingMode() {
        addButton.isEnabled = isEditingMode
        deleteButton.isEnabled = isEditingMode
        if(isEditingMode){ editButton.setTitle(SwiftLocalizationHelper.localizedString(forKey: "Done"), for: .normal) }
        else{ editButton.setTitle(SwiftLocalizationHelper.localizedString(forKey: "Edit"), for: .normal) }
    }
    
    @objc private func pinButtonTapped() {
        viewPinned = !viewPinned
        if viewPinned {
            pinButton.backgroundColor = highlightColor
        }
        else{
            pinButton.backgroundColor = viewBackgroundColor
        }
    }
    
    @objc private func addButtonTapped() {
        let previouslySelectedIndexPath = tableView.indexPathForSelectedRow //memorize selected indexpath
        let alert = UIAlertController(title: SwiftLocalizationHelper.localizedString(forKey: "New Command"), message: SwiftLocalizationHelper.localizedString(forKey: "Enter a new command and alias"), preferredStyle: .alert)
        alert.addTextField { $0.placeholder = SwiftLocalizationHelper.localizedString(forKey:"Command") }
        alert.addTextField { $0.placeholder = SwiftLocalizationHelper.localizedString(forKey: "Alias (optional)") }
        alert.textFields?[0].keyboardType = .asciiCapable
        alert.textFields?[0].autocorrectionType = .no
        alert.textFields?[0].spellCheckingType = .no
        alert.textFields?[1].keyboardType = .asciiCapable
        alert.textFields?[1].autocorrectionType = .no
        alert.textFields?[1].spellCheckingType = .no

        let submitAction = UIAlertAction(title: SwiftLocalizationHelper.localizedString(forKey: "Add"), style: .default) { [unowned alert] _ in
            let keyboardCmdString = alert.textFields?[0].text ?? ""
            let alias = alert.textFields?[1].text ?? keyboardCmdString
            let newCommand = RemoteCommand(cmdString: keyboardCmdString, alias: alias)
            let addCommandSuceeded = CommandManager.shared.addCommand(newCommand)
            //self.reloadTableView() // don't know why but this reload has to be called from the CommandManager, it doesn't work here.
            
            //if previouslySelectedIndexPath == nil { return }
            if addCommandSuceeded {
                let lastRow = self.tableView.numberOfRows(inSection: 0) - 1  //for now there's only 1 section for the tableview, just use setion 0
                let newEntryIndexPath = IndexPath(row: lastRow, section: 0)
                self.tableView.selectRow(at: newEntryIndexPath, animated: true, scrollPosition: .middle) // shift the highlight to the newly added entry
            }
            else {
                self.tableView.selectRow(at: previouslySelectedIndexPath, animated: true, scrollPosition: .middle) // keep the highlight on the previous entry if failed to add command
            }
        }
        
        let cancelAction = UIAlertAction(title: SwiftLocalizationHelper.localizedString(forKey:"Cancel"), style: .cancel)
        alert.addAction(submitAction)
        alert.addAction(cancelAction)
        
        if let selectedIndexPath = self.tableView.indexPathForSelectedRow {
            if isSpecialEntrySelected() {return}
            let selectedCommand = CommandManager.shared.getAllCommands()[selectedIndexPath.row-specialEntries.count]
            alert.textFields?[0].text = selectedCommand.cmdString // load selected keyboard cmd string
            //alert.textFields?[1].text = selectedCommand.alias // leave the alias input field empty
        }
        
        self.present(alert, animated: true)
    }
    
    
    @objc private func deleteButtonTapped() {
        guard let selectedIndexPath = tableView.indexPathForSelectedRow else {
            return
        }
        
        if isSpecialEntrySelected() {return}
        
        let previouslySelectedIndexPath = selectedIndexPath // memorize selected row before reloading tableview
        
        CommandManager.shared.deleteCommand(at: selectedIndexPath.row-specialEntries.count)
        reloadTableView()
        // target new entry after deletion
        var targetRowAfterDel = previouslySelectedIndexPath.row - 1
        if targetRowAfterDel < 0 { targetRowAfterDel = 0 }
        let targetIndexPathAfterDel = IndexPath(row: targetRowAfterDel, section: previouslySelectedIndexPath.section)
            if targetRowAfterDel < tableView.numberOfRows(inSection: previouslySelectedIndexPath.section) {
                tableView.selectRow(at: targetIndexPathAfterDel, animated: true, scrollPosition: .middle) // shift highlight to the target entry after deletion
            }
    }
    
    @objc private func editButtonTapped() {
        isEditingMode.toggle()
        deleteButton.isEnabled = !isSpecialEntrySelected()
        addButton.isEnabled = !isSpecialEntrySelected()
    }
    
    @objc private func exitButtonTapped() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc public func reloadTableView() {
        tableView.layoutIfNeeded()
        tableView.reloadData()
        
        /*
        let previouslySelectedIndexPath = tableView.indexPathForSelectedRow
        if let indexPath = previouslySelectedIndexPath {
            // Make sure the indexPath is still valid and scroll to the selected indexPath
            if indexPath.row < tableView.numberOfRows(inSection: indexPath.section) {
                tableView.selectRow(at: indexPath, animated: true, scrollPosition: .middle) // keep the entry of previous index selected.
            }
        } */
    }
    
    // UITableViewDataSource
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return specialEntries.count + CommandManager.shared.getAllCommands().count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        // Configure cell appearance
        cell.backgroundColor = .clear // Set background color of the cell
        cell.textLabel?.textColor = UIColor.white // Set font color of the text
        
        
        // Set selected background view
        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = highlightColor // Color for the selected state
        cell.selectedBackgroundView = selectedBackgroundView
        
        if indexPath.row < specialEntries.count {
            cell.textLabel?.text = specialEntryAliasDic[specialEntries[indexPath.row] as! String]
        }
        else {
            let command = CommandManager.shared.getAllCommands()[indexPath.row-specialEntries.count]
            cell.textLabel?.text = command.alias
        }
        return cell
    }
    
    // UITableViewDelegate
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if let cell = tableView.cellForRow(at: indexPath) {
            // Set the cell background color to the flashing color
            // Animate the flash effect
            UIView.animate(withDuration: 0.1, animations: {
                cell.selectedBackgroundView?.backgroundColor = .clear
            }) { _ in
                // Reset the cell background color after the animation
                UIView.animate(withDuration: 0.1) {
                    cell.selectedBackgroundView?.backgroundColor = self.highlightColor
                }
            }
        }
    
        if !isEditingMode {
            // Sending keyboard command
            if indexPath.row < specialEntries.count{
                handleSpecialEntries(index: indexPath.row)
            }
            else {
                let command = CommandManager.shared.getAllCommands()[indexPath.row-specialEntries.count]
                sendKeyboardCommand(command)
            }
            if !viewPinned { dismiss(animated: false, completion: nil) } // dimiss the view in sending mode & the view is not pinned
        }
        else {
            let specialEntrySelected = indexPath.row < specialEntries.count
            addButton.isEnabled = !specialEntrySelected
            deleteButton.isEnabled = !specialEntrySelected
        }
    }
    
    private func isSpecialEntrySelected() -> Bool {
        return self.tableView.indexPathForSelectedRow?.row ?? specialEntries.count+1 < specialEntries.count
    }
    
    private func handleSpecialEntries(index:Int){
        usleep(1000*100)
        dismiss(animated: true, completion: nil)
        switch specialEntries[index] as? String {
        case "widgetLayoutTool":
            specialEntryDelegate?.openWidgetLayoutTool!()
        case "widgetSwitchTool":
            specialEntryDelegate?.switchWidgetProfile?()
        case "bringUpSoftKeyboard":
            specialEntryDelegate?.bringUpSoftKeyboard?()
        case "enterPip":
            specialEntryDelegate?.enterPip?()
        default: break
        }
    }
    
    
    private func sendKeyboardCommand(_ cmd: RemoteCommand) {
        print("Sending key-value")
        let keyboardCmdStrings = CommandManager.shared.extractKeyStringsFromComboCommand(from: cmd.cmdString)
        CommandManager.shared.sendKeyComboCommand(keyboardCmdStrings: keyboardCmdStrings!)
    }
}
  
