//
//  OSCProfilesTableViewController.m
//  Moonlight
//
//  Created by Long Le on 11/28/22.
//  Copyright © 2022 Moonlight Game Streaming Project. All rights reserved.
//
//  Modified by True砖家 since 2024.6.24
//  Copyright © 2024 True砖家 on Bilibili. All rights reserved.
//

#import "OSCProfilesTableViewController.h"
#import "LayoutOnScreenControlsViewController.h"
#import "ProfileTableViewCell.h"
#import "OSCProfile.h"
#import "OnScreenButtonState.h"
#import "OSCProfilesManager.h"
#import "LocalizationHelper.h"

const double NAV_BAR_HEIGHT = 50;

@interface OSCProfilesTableViewController ()

@end

@implementation OSCProfilesTableViewController {
    OSCProfilesManager *profilesManager;
}

@synthesize tableView;

- (UIInterfaceOrientationMask)getCurrentOrientation{
    CGFloat screenHeightInPoints = CGRectGetHeight([[UIScreen mainScreen] bounds]);
    CGFloat screenWidthInPoints = CGRectGetWidth([[UIScreen mainScreen] bounds]);
    //lock the orientation accordingly after streaming is started
    if(screenWidthInPoints > screenHeightInPoints) return UIInterfaceOrientationMaskLandscape;
    else return UIInterfaceOrientationMaskPortrait|UIInterfaceOrientationMaskPortraitUpsideDown;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    // Return the supported interface orientations acoordingly
    return [self getCurrentOrientation]; // 90 Degree rotation not allowed in streaming or app view
}

- (void) viewDidDisappear:(BOOL)animated{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"OscLayoutTableViewCloseNotification" object:self]; // notify other view that oscLayoutManager is closing
    [super viewDidDisappear:animated];
}


- (void) viewDidLayoutSubviews {
    CGRect bounds = self.profileTableViewNavigationBar.bounds;
    CGSize cornerSize = CGSizeMake(15, 15);
    
    // 创建一个 UIBezierPath，设置顶部圆角
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:bounds byRoundingCorners:(UIRectCornerTopLeft | UIRectCornerTopRight) cornerRadii:cornerSize];
                                               //byRoundingCorners:(UIRectCornerTopLeft | UIRectCornerTopRight)  // 只设置上半部分圆角
                                                 //    cornerRadius:10];  // 圆角半径

    // 创建一个 CAShapeLayer 并将圆角路径应用到该图层
    CAShapeLayer *maskLayer = [CAShapeLayer layer];
    maskLayer.frame = bounds;
    maskLayer.path = path.CGPath;

    self.profileTableViewNavigationBar.layer.masksToBounds = true;  // 使圆角生效
    self.profileTableViewNavigationBar.layer.mask = maskLayer;
    
    self.tableView.layer.cornerRadius = 15;  // 设置圆角半径
    self.tableView.layer.masksToBounds = true;  // 使圆角生效
}

- (void) viewDidLoad {
    [super viewDidLoad];
    
    // self.profileTableViewNavigationBar.layer.cornerRadius = 15;  // 设置圆角半径
    
    profilesManager = [OSCProfilesManager sharedManager:_layoutViewBounds];
    
    self.tableView.tableHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, NAV_BAR_HEIGHT)];
    
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    [self.tableView registerNib:[UINib nibWithNibName:@"ProfileTableViewCell" bundle:nil]
         forCellReuseIdentifier:@"Cell"]; // Register the custom cell nib file with the table view
    self.tableView.alpha = 0.7;
    //self.tableView.backgroundColor = [[UIColor colorWithRed:0.5 green:0.7 blue:1.0 alpha:1.0] colorWithAlphaComponent:0.2]; // set background color & transparency
    self.tableView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5]; // set background color & transparency
    // self.tableView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.2]; // set background color & transparency

    // 初始化配对状态
    self.isPairingMode = NO;
    self.selectedProfileForPairing = nil;
    self.isProcessingOrientationChange = NO;
    
    // 设置底部工具栏
    [self setupBottomToolbar];
    
    // 调整tableView的底部边距，为工具栏留出空间
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, 80, 0);  // 50(工具栏高度) + 16(底部间距) + 16(额外间距)
    self.tableView.scrollIndicatorInsets = UIEdgeInsetsMake(0, 0, 80, 0);
    
    // 监听设备方向变化
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(deviceOrientationDidChange:)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil];
    
    // 初始更新删除按钮状态
    [self updateDeleteButtonState];
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear: animated];
    

    self.tableView.tableHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, NAV_BAR_HEIGHT)];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    [self.tableView registerNib:[UINib nibWithNibName:@"ProfileTableViewCell" bundle:nil]
                                        forCellReuseIdentifier:@"Cell"]; // Register the custom cell nib file with the table view

    if ([[profilesManager getAllProfiles] count] > 0) { // scroll to selected profile if user has any saved profiles
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:[profilesManager getIndexOfSelectedProfile] inSection:0];
        [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
     }
     
     // 更新工具栏按钮状态
     [self updateToolbarButtons];
}


#pragma mark - UIButton Actions

/* Loads the OSC profile that user selected, dismisses this VC, then tells the presenting view controller to lay out the on screen buttons according to the selected profile's instructions */
- (IBAction) duplicateTapped:(id)sender {

        UIAlertController * inputNameAlertController = [UIAlertController alertControllerWithTitle: [LocalizationHelper localizedStringForKey:@"Enter the name you want to save this profile as"] message: @"" preferredStyle:UIAlertControllerStyleAlert];
        [inputNameAlertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {  // pop up notification with text field where user can enter the text they wish to name their OSC layout profile
            textField.placeholder = [LocalizationHelper localizedStringForKey:@"name"];
            textField.textColor = [UIColor lightGrayColor];
            textField.clearButtonMode = UITextFieldViewModeWhileEditing;
            textField.borderStyle = UITextBorderStyleNone;
        }];
        [inputNameAlertController addAction:[UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Cancel"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { // adds a button that allows user to decline the option to save the controller layout they currently see on screen
            [inputNameAlertController dismissViewControllerAnimated:NO completion:nil];
        }]];
        [inputNameAlertController addAction:[UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Save"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {   // add save button to allow user to save the on screen controller configuration
            NSArray *textFields = inputNameAlertController.textFields;
            UITextField *nameField = textFields[0];
            NSString *enteredProfileName = nameField.text;
            
            if ([profilesManager isTemplateProfile:enteredProfileName]) {  // 不允许覆盖模板布局
                NSString *message = [NSString stringWithFormat:@"不允许覆盖模板布局'%@'", enteredProfileName];
                UIAlertController *alertController = [UIAlertController alertControllerWithTitle: [NSString stringWithFormat:@""] message: message preferredStyle:UIAlertControllerStyleAlert];
                
                [alertController addAction:[UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Ok"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                    [alertController dismissViewControllerAnimated:NO completion:^{
                        [self presentViewController:inputNameAlertController animated:YES completion:nil];
                    }];
                }]];
                [self presentViewController:alertController animated:YES completion:nil];
            }
            else if ([enteredProfileName length] == 0) {    // if user entered no text and taps the 'Save' button let them know they can't do that
                UIAlertController * savedAlertController = [UIAlertController alertControllerWithTitle: [NSString stringWithFormat:@""] message: [LocalizationHelper localizedStringForKey:@"Profile name cannot be blank!"] preferredStyle:UIAlertControllerStyleAlert];
                
                [savedAlertController addAction:[UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Ok"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { // show pop up notification letting user know they must enter a name in the text field if they wish to save the controller profile
                    
                    [savedAlertController dismissViewControllerAnimated:NO completion:^{
                        [self presentViewController:inputNameAlertController animated:YES completion:nil];
                    }];
                }]];
                [self presentViewController:savedAlertController animated:YES completion:nil];
            }
            else if ([self->profilesManager profileNameAlreadyExist:enteredProfileName] == YES) {  // if the entered profile name already
                UIAlertController * savedAlertController = [UIAlertController alertControllerWithTitle: [NSString stringWithFormat:@""] message: [LocalizationHelper localizedStringForKey:@"Profile name already exists"] preferredStyle:UIAlertControllerStyleAlert];
                
                [savedAlertController addAction:[UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Ok"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                    //[savedAlertController dismissViewControllerAnimated:NO completion:nil];
                    //[self profileViewRefresh]; //refresh profile view after saving new profile;
                }]];
                [self presentViewController:savedAlertController animated:YES completion:nil];
            }
            else {  // if user entered a valid name that doesn't already exist then save the profile to persistent storage
                [self->profilesManager saveProfileWithName: enteredProfileName andButtonLayers:self.currentOSCButtonLayers]; // the OSC layout here is passed from parent LayoutOSCViewController;
                [self->profilesManager setProfileToSelected: enteredProfileName];
                
                UIAlertController * savedAlertController = [UIAlertController alertControllerWithTitle: [NSString stringWithFormat:@""] message: [LocalizationHelper localizedStringForKey:@"Profile %@ duplicated from current layout", enteredProfileName] preferredStyle:UIAlertControllerStyleAlert];  // Let user know this profile has been duplicated & saved
                
                [savedAlertController addAction:[UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Ok"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                    [savedAlertController dismissViewControllerAnimated:NO completion:nil];
                    [self profileViewRefresh]; //refresh profile view after saving new profile;
                }]];
                [self presentViewController:savedAlertController animated:YES completion:nil];
            }
        }]];

        [self presentViewController:inputNameAlertController animated:YES completion:nil];
}

/* basically the same with loadTapped */
- (void) profileViewRefresh{
    //[self dismissViewControllerAnimated:YES completion:nil];
    //[selfparentLayoutOSCViewController]
    [self.tableView reloadData]; // table view will be refreshed by calling reloadData
    [self updateDeleteButtonState]; // 更新顶部删除按钮状态
    if (self.needToUpdateOscLayoutTVC) {    // tells the presenting view controller to lay out the on screen buttons according to the selected profile's instructions
        self.needToUpdateOscLayoutTVC();
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:@"OscLayoutProfileSelctedInTableView" object:self]; // notify other view that oscLayoutManager is closing
}

- (IBAction) deleteTapped:(id)sender {
    OSCProfile *currentProfile = [profilesManager getSelectedProfile];
    if (!currentProfile || !currentProfile.name) {
        return;
    }
    
    // 检查是否为模板布局
    if ([profilesManager isTemplateProfile:currentProfile.name]) {
        NSString *message = [NSString stringWithFormat:@"模板布局'%@'不允许删除", currentProfile.name];
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"" message:message preferredStyle:UIAlertControllerStyleAlert];
        
        [alertController addAction:[UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Ok"] style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alertController animated:YES completion:nil];
        return;
    }
    
    // 删除确认弹窗
    NSString *confirmMessage = [NSString stringWithFormat:@"确定要删除布局'%@'吗？", currentProfile.name];
    UIAlertController *confirmController = [UIAlertController alertControllerWithTitle:@"确认删除" message:confirmMessage preferredStyle:UIAlertControllerStyleAlert];
    
    [confirmController addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [confirmController addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [self->profilesManager deleteCurrentSelectedProfile];
        [self profileViewRefresh];
    }]];
    
    [self presentViewController:confirmController animated:YES completion:nil];
}

- (IBAction) exportDataTapped:(id)sender {
    // 创建临时占位文件（仅用于提供文件名）
    self.currentFileOperation = Export;
    NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"profiles.bin"];
    [[NSData new] writeToFile:tempPath atomically:YES]; // 空文件
    
    // 初始化选择器
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithURL:[NSURL fileURLWithPath:tempPath] inMode:UIDocumentPickerModeExportToService];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (IBAction) importDataTapped:(id)sender {
    self.currentFileOperation = Import;
    // 2. 创建文件选择器
    // UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:supportedTypes inMode:UIDocumentPickerModeImport];
    // UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.data"] inMode:UIDocumentPickerModeOpen];
    UIDocumentPickerViewController *documentPicker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.item"] inMode:UIDocumentPickerModeOpen];
    documentPicker.delegate = self;
    documentPicker.allowsMultipleSelection = NO; // 只允许选择一个文件
    [self presentViewController:documentPicker animated:YES completion:nil];
}

- (IBAction) exitTapped:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UIDocumentPickerDelegate
- (void)documentPicker:(UIDocumentPickerViewController *)controller
didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL* url = urls.firstObject;
    switch(self.currentFileOperation){
        case Export:
            [self profilesToFile:url];break;
        case Import:
            [self fileToProfiles:url];break;
        default:break;
    }
}

- (void)profilesToFile:(NSURL* )destinationURL{
    
    // NSArray *profiles = [profilesManager getAllProfiles];
    // 1. 序列化数据
    NSError *error;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:[profilesManager getEncodedProfiles] requiringSecureCoding:YES error:&error];
    if (!data) {
        NSLog(@"序列化失败: %@", error);
        return;
    }
    // 2. 安全写入
    [destinationURL startAccessingSecurityScopedResource];
    BOOL success = [data writeToURL:destinationURL options:NSDataWritingAtomic error:&error];
    [destinationURL stopAccessingSecurityScopedResource];
    if (!success) {
        NSLog(@"写入失败: %@", error);
    }
}

- (void)fileToProfiles:(NSURL* )sourceURL{
    bool restoreFailed = false;
    if (![sourceURL startAccessingSecurityScopedResource]) {
        restoreFailed = true;
    }
    NSError* error;
    NSData* fileData = [NSData dataWithContentsOfURL:sourceURL options:0 error:&error];// 读取数据
    [sourceURL stopAccessingSecurityScopedResource]; // 立即释放权限
    if (!fileData) {
        restoreFailed = true;
    }
    else NSLog(@"profile file read: %d", (uint32_t)fileData.length);
    // 定义需要解码的类集
    NSSet *classes = [NSSet setWithObjects: [NSMutableData class], [NSMutableArray class], nil];
    NSMutableArray *profilesEncoded;
    // 解码原始的NSArray对象，得到包含编码对象的数组
    error = nil;
    profilesEncoded = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:fileData error:&error];
    restoreFailed = error != nil;

    UIAlertController *restoredAlertController = [UIAlertController alertControllerWithTitle: [LocalizationHelper localizedStringForKey:@""] message: [LocalizationHelper localizedStringForKey:@"Pofiles imported"] preferredStyle:UIAlertControllerStyleAlert];
    UIAlertController *failedAlertController = [UIAlertController alertControllerWithTitle: [LocalizationHelper localizedStringForKey:@""] message: [LocalizationHelper localizedStringForKey:@"Failed to import profiles"] preferredStyle:UIAlertControllerStyleAlert];


    UIAlertAction *okAction = [UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"OK"]
                                                           style:UIAlertActionStyleDefault
                                                     handler:nil];
    
    if(restoreFailed){
        [failedAlertController addAction:okAction];
        [self presentViewController:failedAlertController animated:YES completion:nil];
    }
    else{
        [profilesManager importEncodedProfiles:profilesEncoded];
        [restoredAlertController addAction:okAction];
        [self presentViewController:restoredAlertController animated:YES completion:nil];
    }
    
    [self profileViewRefresh];
    NSLog(@"profile test: %d", (uint32_t)profilesEncoded.count);
    if (error) {
        NSLog(@"解码失败: %@", error);
        return;
    }
}


#pragma mark - TableView DataSource

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[profilesManager getAllProfiles] count];
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ProfileTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    NSMutableArray *allProfiles = [profilesManager getAllProfiles];
    
    // 安全检查：确保索引有效且profile不为nil
    if (indexPath.row >= allProfiles.count) {
        NSLog(@"错误：索引超出范围 %ld >= %lu", (long)indexPath.row, (unsigned long)allProfiles.count);
        cell.name.text = @"错误：无效配置";
        return cell;
    }
    
    OSCProfile *profile = [allProfiles objectAtIndex:indexPath.row];
    if (profile == nil) {
        NSLog(@"错误：配置文件为nil，索引：%ld", (long)indexPath.row);
        cell.name.text = @"错误：配置文件损坏";
        return cell;
    }
    
    // 构建显示文本，包含配对标识和模板标识
    NSString *displayText = profile.name ?: @"未命名配置";  // 防止name为nil
    
    // 添加模板标识
    if ([profilesManager isTemplateProfile:profile.name]) {
        displayText = [NSString stringWithFormat:@"📋 %@", displayText];
    }
    
    // 添加配对标识
    if (profile.isPaired) {
        NSString *orientationText = [self getOrientationDisplayText:profile.isLandscapeLayout];
        displayText = [NSString stringWithFormat:@"%@ %@", orientationText, displayText];
    }
    
    cell.name.text = displayText;
    cell.name.backgroundColor = [UIColor clearColor];
    cell.name.alpha = 1.0;
    
    // 根据配对模式设置文本颜色和可选择性
    BOOL canSelect = [self canSelectProfileForPairing:profile];
    if (self.isPairingMode && !canSelect) {
        cell.name.textColor = [UIColor grayColor];  // 不可选择的布局显示为灰色
        cell.userInteractionEnabled = NO;
    } else {
        cell.name.textColor = [UIColor whiteColor];  // 正常白色文本
        cell.userInteractionEnabled = YES;
    }
    
    cell.name.font =[UIFont systemFontOfSize:20 weight:UIFontWeightMedium];
    cell.name.shadowColor = [UIColor blackColor];  // Black shadow
    // Set the shadow offset
    cell.name.shadowOffset = CGSizeMake(1.0, 1.5);

    // Set cell and contentView background colors
    cell.backgroundColor = [UIColor clearColor];
    cell.contentView.backgroundColor = [UIColor clearColor];
    
    // Configure the checkmark accessory
    if ([profile.name isEqualToString:[profilesManager getSelectedProfile].name]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    // Remove existing custom separators to avoid duplicates
    UIView *existingSeparator = [cell.contentView viewWithTag:100];
    if (existingSeparator) {
        [existingSeparator removeFromSuperview];
    }

    // Add custom separator with increased height (thickness)
    CGFloat separatorHeight = 1.0; // Adjust this value for thicker line
    UIView *separatorView = [[UIView alloc] initWithFrame:CGRectMake(0, cell.contentView.frame.size.height - separatorHeight, cell.contentView.frame.size.width, separatorHeight)];
    
    separatorView.backgroundColor = [UIColor whiteColor];  // Set your desired color
    separatorView.tag = 100;  // Assign a tag to identify the separator view
    separatorView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;

    [cell.contentView addSubview:separatorView];
    [cell.contentView bringSubviewToFront:separatorView];


    // Replace the default checkmark with a UILabel displaying a checkmark character
    if ([profile.name isEqualToString:[profilesManager getSelectedProfile].name]) {
        UILabel *checkmarkLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 20, 20)]; // Adjust size as needed
        checkmarkLabel.text = @"✓";  // The checkmark character
        checkmarkLabel.font = [UIFont systemFontOfSize:25]; // Adjust font size as needed
        checkmarkLabel.textAlignment = NSTextAlignmentCenter;
        checkmarkLabel.textColor = [UIColor greenColor];  // Set the color of the checkmark
        cell.accessoryView = checkmarkLabel;
        checkmarkLabel.layer.zPosition = 0; // Push checkmark to the back
    } else {
        cell.accessoryView = nil;  // Remove checkmark if not selected
    }
    [cell.contentView bringSubviewToFront:separatorView];
    separatorView.layer.zPosition = 1; // Bring separator to the top layer

    
    return cell;
}

- (BOOL) tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    NSMutableArray *profiles = [profilesManager getAllProfiles];
    
    // 安全检查：确保索引有效
    if (indexPath.row >= profiles.count) {
        return NO;
    }
    
    OSCProfile *profile = [profiles objectAtIndex:indexPath.row];
    if (!profile || !profile.name) {
        return NO;
    }
    
    // 模板布局不允许删除
    return ![profilesManager isTemplateProfile:profile.name];
}



- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 60.0; // Set your desired cell height here
}


- (void) tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSMutableArray *profiles = [profilesManager getAllProfiles];
        
        // 安全检查：确保索引有效
        if (indexPath.row >= profiles.count) {
            return;
        }
        
        OSCProfile *profileToDelete = [profiles objectAtIndex:indexPath.row];
        if (!profileToDelete || !profileToDelete.name) {
            return;
        }
        
        // 检查是否为模板布局
        if ([profilesManager isTemplateProfile:profileToDelete.name]) {
            NSString *message = [NSString stringWithFormat:@"删除'%@'模板布局是不被允许的", profileToDelete.name];
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"" message:message preferredStyle:UIAlertControllerStyleAlert];
            
            [alertController addAction:[UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Ok"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                [alertController dismissViewControllerAnimated:NO completion:nil];
            }]];
            [self presentViewController:alertController animated:YES completion:nil];
            return;
        }
        
        // 删除确认弹窗
        NSString *confirmMessage = [NSString stringWithFormat:@"确定要删除布局'%@'吗？", profileToDelete.name];
        UIAlertController *confirmController = [UIAlertController alertControllerWithTitle:@"确认删除" message:confirmMessage preferredStyle:UIAlertControllerStyleAlert];
        
        [confirmController addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [confirmController addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
            [self performDeleteProfile:profileToDelete atIndexPath:indexPath];
        }]];
        
        [self presentViewController:confirmController animated:YES completion:nil];
    }
}

- (void)performDeleteProfile:(OSCProfile *)profileToDelete atIndexPath:(NSIndexPath *)indexPath {
    NSMutableArray *profiles = [profilesManager getAllProfiles];
    
    // 处理删除选中布局的情况
    if (profileToDelete.isSelected) {
        if (indexPath.row > 0) {
            OSCProfile *previousProfile = [profiles objectAtIndex:indexPath.row - 1];
            previousProfile.isSelected = YES;
        } else if (profiles.count > 1) {
            OSCProfile *nextProfile = [profiles objectAtIndex:1];
            nextProfile.isSelected = YES;
        }
    }
    
    // 如果要删除的布局是配对布局，解除配对关系
    if (profileToDelete.isPaired) {
        [profilesManager unpairProfile:profileToDelete.name];
    }
    
    [profiles removeObjectAtIndex:indexPath.row];
    
    /* save OSC profiles array to persistent storage */
    NSMutableArray *profilesEncoded = [[NSMutableArray alloc] init];
    for (OSCProfile *profileDecoded in profiles) {  // encode each OSC profile object and add them to an array
        NSData *profileEncoded = [NSKeyedArchiver archivedDataWithRootObject:profileDecoded requiringSecureCoding:YES error:nil];
        [profilesEncoded addObject:profileEncoded];
    }
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:profilesEncoded
                                         requiringSecureCoding:YES error:nil];  // encode the array itself, NOT the objects in the array
    [[NSUserDefaults standardUserDefaults] setObject:data forKey:@"OSCProfiles"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [self.tableView reloadData];
    [self updateToolbarButtons];  // 更新工具栏按钮状态
}


#pragma mark - TableView Delegate

/* When user taps a cell it moves the checkmark to that cell indicating to the user the profile associated with that cell is now the selected profile. It also sets that cell's associated OSCProfile object's 'isSelected' property to YES  */
- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSMutableArray *allProfiles = [profilesManager getAllProfiles];
    
    // 安全检查：确保索引有效
    if (indexPath.row >= allProfiles.count) {
        NSLog(@"错误：选择的索引超出范围 %ld >= %lu", (long)indexPath.row, (unsigned long)allProfiles.count);
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    }
    
    OSCProfile *profile = [allProfiles objectAtIndex:indexPath.row];
    if (profile == nil) {
        NSLog(@"错误：选择的配置文件为nil，索引：%ld", (long)indexPath.row);
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    }
    
    if (self.isPairingMode) {
        // 配对模式：选择要配对的布局
        if ([self canSelectProfileForPairing:profile]) {
            self.selectedProfileForPairing = profile.name;
            [self updateToolbarButtons];  // 更新保存按钮状态
        }
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    }
    
    // 普通模式：选择布局逻辑
    NSIndexPath *selectedIndexPath = [NSIndexPath indexPathForRow:indexPath.row inSection:0];
    NSIndexPath *lastSelectedIndexPath = [NSIndexPath indexPathForRow:[profilesManager getIndexOfSelectedProfile] inSection:0];

    if (selectedIndexPath != lastSelectedIndexPath) {
        // 如果选择的是已配对的布局，需要检查是否应该切换到对应方向的布局
        if (profile.isPaired) {
            BOOL isCurrentLandscape = [profilesManager isCurrentOrientationLandscape];
            OSCProfile *targetProfile = [profilesManager getProfileForCurrentOrientation:profile.name isLandscape:isCurrentLandscape];
            if (targetProfile && ![targetProfile.name isEqualToString:profile.name]) {
                // 切换到对应方向的布局
                profile = targetProfile;
                indexPath = [NSIndexPath indexPathForRow:[[profilesManager getAllProfiles] indexOfObject:targetProfile] inSection:0];
                selectedIndexPath = indexPath;
            }
        }
        
        /* Place checkmark on selected cell and set profile associated with cell as selected profile */
        UITableViewCell *selectedCell = [tableView cellForRowAtIndexPath: selectedIndexPath];
        selectedCell.accessoryType = UITableViewCellAccessoryCheckmark;  // add checkmark to the cell the user tapped
        selectedCell.accessoryView.tintColor = [[UIColor colorWithRed:0.5 green:0.5 blue:1.0 alpha:0.85] colorWithAlphaComponent:1.0];
        [profilesManager setProfileToSelected: profile.name];   // set the profile associated with this cell's 'isSelected' property to YES
        
        /* Remove checkmark on the previously selected cell  */
        UITableViewCell *lastSelectedCell = [tableView cellForRowAtIndexPath: lastSelectedIndexPath];
        lastSelectedCell.accessoryType = UITableViewCellAccessoryNone; 
        [tableView deselectRowAtIndexPath:lastSelectedIndexPath animated:YES];
        
        // 更新工具栏按钮
        [self updateToolbarButtons];
    }
    [self profileViewRefresh]; // update OSC layout when table view option is changed
}

#pragma mark - Pairing Management

- (void)setupBottomToolbar {
    NSLog(@"开始设置底部工具栏");
    
    // 创建底部工具栏视图（如果不存在）
    if (!self.bottomToolbarView) {
        NSLog(@"创建新的底部工具栏视图");
        self.bottomToolbarView = [[UIView alloc] init];
        if (!self.bottomToolbarView) {
            NSLog(@"错误：无法创建bottomToolbarView");
            return;
        }
        
        // 设置工具栏样式
        self.bottomToolbarView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.8];
        self.bottomToolbarView.layer.cornerRadius = 8;
        self.bottomToolbarView.layer.masksToBounds = YES;
        
        self.bottomToolbarView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.view addSubview:self.bottomToolbarView];
        NSLog(@"工具栏视图已添加到视图");
        
        // 创建约束
        NSLayoutConstraint *leadingConstraint = [self.bottomToolbarView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16];
        NSLayoutConstraint *trailingConstraint = [self.bottomToolbarView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16];
        NSLayoutConstraint *bottomConstraint = [self.bottomToolbarView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-16];
        NSLayoutConstraint *heightConstraint = [self.bottomToolbarView.heightAnchor constraintEqualToConstant:50];
        
        // 检查约束是否创建成功
        NSMutableArray *constraints = [[NSMutableArray alloc] init];
        if (leadingConstraint) [constraints addObject:leadingConstraint];
        if (trailingConstraint) [constraints addObject:trailingConstraint];
        if (bottomConstraint) [constraints addObject:bottomConstraint];
        if (heightConstraint) [constraints addObject:heightConstraint];
        
        if (constraints.count == 4) {
            [NSLayoutConstraint activateConstraints:constraints];
            NSLog(@"工具栏约束设置成功");
        } else {
            NSLog(@"错误：约束创建失败，成功创建 %lu/4 个约束", (unsigned long)constraints.count);
        }
        
        // 确保工具栏在最前面
        [self.view bringSubviewToFront:self.bottomToolbarView];
    } else {
        NSLog(@"工具栏已存在，跳过创建");
    }
    
    [self updateToolbarButtons];
}

- (void)updateToolbarButtons {
    // 如果工具栏不存在，直接返回
    if (!self.bottomToolbarView) {
        return;
    }
    
    // 清除现有按钮
    for (UIView *subview in self.bottomToolbarView.subviews) {
        [subview removeFromSuperview];
    }
    
    OSCProfile *selectedProfile = [profilesManager getSelectedProfile];
    BOOL isCurrentProfilePaired = selectedProfile ? selectedProfile.isPaired : NO;
    BOOL isLandscape = [profilesManager isCurrentOrientationLandscape];
    
    if (self.isPairingMode) {
        // 配对模式：显示保存和取消按钮
        [self createPairingModeButtons];
    } else {
        // 普通模式：检查是否为模板布局
        if (selectedProfile && [profilesManager isTemplateProfile:selectedProfile.name]) {
            // 模板布局不显示配对相关按钮
            return;
        }
        
        // 普通模式：显示配对/解除配对按钮
        NSString *buttonTitle;
        SEL buttonAction;
        
        if (isCurrentProfilePaired) {
            buttonTitle = @"解除配对";
            buttonAction = @selector(unpairTapped:);
        } else {
            NSString *oppositeOrientation = isLandscape ? @"竖屏" : @"横屏";
            buttonTitle = [NSString stringWithFormat:@"添加%@布局", oppositeOrientation];
            buttonAction = @selector(startPairingTapped:);
        }
        
        [self createNormalModeButtonWithTitle:buttonTitle action:buttonAction];
    }
}

- (void)createPairingModeButtons {
    // 创建取消按钮
    self.cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.cancelButton setTitle:@"取消" forState:UIControlStateNormal];
    [self.cancelButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.cancelButton addTarget:self action:@selector(cancelPairingTapped:) forControlEvents:UIControlEventTouchUpInside];
    self.cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.bottomToolbarView addSubview:self.cancelButton];
    
    // 创建保存按钮
    self.saveButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.saveButton setTitle:@"保存" forState:UIControlStateNormal];
    [self.saveButton setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
    [self.saveButton setTitleColor:[UIColor grayColor] forState:UIControlStateDisabled];
    [self.saveButton addTarget:self action:@selector(savePairingTapped:) forControlEvents:UIControlEventTouchUpInside];
    self.saveButton.enabled = (self.selectedProfileForPairing != nil);
    self.saveButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.bottomToolbarView addSubview:self.saveButton];
    
    // 设置约束
    [NSLayoutConstraint activateConstraints:@[
        [self.cancelButton.leadingAnchor constraintEqualToAnchor:self.bottomToolbarView.leadingAnchor constant:16],
        [self.cancelButton.centerYAnchor constraintEqualToAnchor:self.bottomToolbarView.centerYAnchor],
        
        [self.saveButton.trailingAnchor constraintEqualToAnchor:self.bottomToolbarView.trailingAnchor constant:-16],
        [self.saveButton.centerYAnchor constraintEqualToAnchor:self.bottomToolbarView.centerYAnchor]
    ]];
    
    NSLog(@"配对模式按钮创建成功");
}

- (void)createNormalModeButtonWithTitle:(NSString *)title action:(SEL)action {
    // 创建主按钮
    self.pairingButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.pairingButton setTitle:title forState:UIControlStateNormal];
    [self.pairingButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.pairingButton addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    self.pairingButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.bottomToolbarView addSubview:self.pairingButton];
    
    // 设置约束 - 居中显示
    [NSLayoutConstraint activateConstraints:@[
        [self.pairingButton.centerXAnchor constraintEqualToAnchor:self.bottomToolbarView.centerXAnchor],
        [self.pairingButton.centerYAnchor constraintEqualToAnchor:self.bottomToolbarView.centerYAnchor]
    ]];
    
    NSLog(@"普通模式按钮创建成功：%@", title);
}

- (IBAction)startPairingTapped:(id)sender {
    self.isPairingMode = YES;
    self.selectedProfileForPairing = nil;
    [self updateToolbarButtons];
    [self.tableView reloadData];
}

- (IBAction)unpairTapped:(id)sender {
    OSCProfile *selectedProfile = [profilesManager getSelectedProfile];
    if (selectedProfile && selectedProfile.isPaired) {
        [profilesManager unpairProfile:selectedProfile.name];
        [self updateToolbarButtons];
        [self.tableView reloadData];
    }
}

- (IBAction)savePairingTapped:(id)sender {
    if (self.selectedProfileForPairing) {
        OSCProfile *currentProfile = [profilesManager getSelectedProfile];
        if (currentProfile == nil || currentProfile.name == nil) {
            NSLog(@"错误：当前选中的配置文件无效，无法进行配对");
            return;
        }
        
        BOOL isCurrentLandscape = [profilesManager isCurrentOrientationLandscape];
        
        BOOL success = [profilesManager pairProfile:currentProfile.name 
                                        withProfile:self.selectedProfileForPairing 
                                   isProfile1Landscape:isCurrentLandscape];
        
        if (success) {
            self.isPairingMode = NO;
            self.selectedProfileForPairing = nil;
            [self updateToolbarButtons];
            [self.tableView reloadData];
        } else {
            NSLog(@"配对失败");
        }
    }
}

- (IBAction)cancelPairingTapped:(id)sender {
    self.isPairingMode = NO;
    self.selectedProfileForPairing = nil;
    [self updateToolbarButtons];
    [self.tableView reloadData];
}

- (NSString *)getOrientationDisplayText:(BOOL)isLandscape {
    return isLandscape ? @"[横]" : @"[竖]";
}

- (BOOL)canSelectProfileForPairing:(OSCProfile *)profile {
    if (!self.isPairingMode) return YES;
    
    OSCProfile *currentProfile = [profilesManager getSelectedProfile];
    
    // 不能选择当前使用的布局
    if ([profile.name isEqualToString:currentProfile.name]) {
        return NO;
    }
    
    // 不能选择已配对的布局
    if (profile.isPaired) {
        return NO;
    }
    
    // 不能选择模板布局
    if ([profilesManager isTemplateProfile:profile.name]) {
        return NO;
    }
    
    return YES;
}

- (void)deviceOrientationDidChange:(NSNotification *)notification {
    // 如果正在配对模式，不处理自动切换
    if (self.isPairingMode) {
        return;
    }
    
    // 如果正在处理方向变化，跳过重复处理
    if (self.isProcessingOrientationChange) {
        return;
    }
    
    self.isProcessingOrientationChange = YES;
    
    // 延迟一小段时间，让旋转完成后再检测方向
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self performPairedLayoutSwitchingForTableView];
        // 简化：处理完成后立即重置标志
        self.isProcessingOrientationChange = NO;
    });
}

- (void)performPairedLayoutSwitchingForTableView {
    OSCProfile *currentProfile = [profilesManager getSelectedProfile];
    if (!currentProfile || !currentProfile.isPaired) {
        return;
    }
    
    // 使用当前视图的bounds来检测方向，而不是依赖OSCProfilesManager的方法
    BOOL isCurrentLandscape = self.view.bounds.size.width > self.view.bounds.size.height;
    
    OSCProfile *targetProfile = [profilesManager getProfileForCurrentOrientation:currentProfile.name isLandscape:isCurrentLandscape];
    
    if (targetProfile && ![targetProfile.name isEqualToString:currentProfile.name]) {
        // 切换到目标布局
        [profilesManager setProfileToSelected:targetProfile.name];
        
        // 更新UI - 这是关键，确保绿色小勾更新到新选中的布局
        [self.tableView reloadData];
        [self updateToolbarButtons];
        
        // 滚动到新选中的布局
        NSInteger selectedIndex = [profilesManager getIndexOfSelectedProfile];
        if (selectedIndex >= 0 && selectedIndex < [[profilesManager getAllProfiles] count]) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:selectedIndex inSection:0];
            [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
        }
    }
}

- (void)dealloc {
    // 移除通知监听
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
}

#pragma mark - Delete Button State Management

- (void)updateDeleteButtonState {
    OSCProfile *currentProfile = [profilesManager getSelectedProfile];
    BOOL isTemplateProfile = currentProfile && [profilesManager isTemplateProfile:currentProfile.name];
    
    // 尝试通过多种方式找到删除按钮并更新其状态
    [self updateDeleteButtonWithTemplateState:isTemplateProfile];
}

- (void)updateDeleteButtonWithTemplateState:(BOOL)isTemplate {
    // 方法1: 通过NavigationBar的rightBarButtonItems查找
    if (self.navigationController && self.navigationController.navigationBar) {
        UINavigationBar *navBar = self.navigationController.navigationBar;
        UINavigationItem *navItem = navBar.topItem;
        
        if (navItem.rightBarButtonItems) {
            for (UIBarButtonItem *item in navItem.rightBarButtonItems) {
                // 检查按钮标题或者action来识别删除按钮
                if ([item.title isEqualToString:@"删除"] || 
                    [item.title isEqualToString:@"Delete"] ||
                    item.action == @selector(deleteTapped:)) {
                    item.enabled = !isTemplate;
                    NSLog(@"通过NavigationBar找到删除按钮，设置enabled=%@", isTemplate ? @"NO" : @"YES");
                    return;
                }
            }
        }
        
        if (navItem.rightBarButtonItem) {
            UIBarButtonItem *item = navItem.rightBarButtonItem;
            if ([item.title isEqualToString:@"删除"] || 
                [item.title isEqualToString:@"Delete"] ||
                item.action == @selector(deleteTapped:)) {
                item.enabled = !isTemplate;
                NSLog(@"通过NavigationBar找到删除按钮，设置enabled=%@", isTemplate ? @"NO" : @"YES");
                return;
            }
        }
    }
    
    // 方法2: 通过profileTableViewNavigationBar查找
    if (self.profileTableViewNavigationBar) {
        UINavigationItem *navItem = self.profileTableViewNavigationBar.topItem;
        
        if (navItem.rightBarButtonItems) {
            for (UIBarButtonItem *item in navItem.rightBarButtonItems) {
                if ([item.title isEqualToString:@"删除"] || 
                    [item.title isEqualToString:@"Delete"] ||
                    item.action == @selector(deleteTapped:)) {
                    item.enabled = !isTemplate;
                    NSLog(@"通过profileTableViewNavigationBar找到删除按钮，设置enabled=%@", isTemplate ? @"NO" : @"YES");
                    return;
                }
            }
        }
        
        if (navItem.rightBarButtonItem) {
            UIBarButtonItem *item = navItem.rightBarButtonItem;
            if ([item.title isEqualToString:@"删除"] || 
                [item.title isEqualToString:@"Delete"] ||
                item.action == @selector(deleteTapped:)) {
                item.enabled = !isTemplate;
                NSLog(@"通过profileTableViewNavigationBar找到删除按钮，设置enabled=%@", isTemplate ? @"NO" : @"YES");
                return;
            }
        }
    }
    
    // 方法3: 递归搜索view hierarchy中的删除按钮
    [self findAndUpdateDeleteButtonInView:self.view isTemplate:isTemplate];
}

- (void)findAndUpdateDeleteButtonInView:(UIView *)view isTemplate:(BOOL)isTemplate {
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)subview;
            NSString *title = [button titleForState:UIControlStateNormal];
            
            // 检查按钮的标题或action
            if ([title isEqualToString:@"删除"] || 
                [title isEqualToString:@"Delete"] ||
                [button actionsForTarget:self forControlEvent:UIControlEventTouchUpInside].count > 0) {
                
                // 检查action是否为deleteTapped
                NSArray *actions = [button actionsForTarget:self forControlEvent:UIControlEventTouchUpInside];
                for (NSString *action in actions) {
                    if ([action isEqualToString:@"deleteTapped:"]) {
                        button.enabled = !isTemplate;
                        button.alpha = isTemplate ? 0.5 : 1.0; // 置灰效果
                        NSLog(@"通过view hierarchy找到删除按钮，设置enabled=%@", isTemplate ? @"NO" : @"YES");
                        return;
                    }
                }
            }
        }
        
        // 递归搜索子视图
        [self findAndUpdateDeleteButtonInView:subview isTemplate:isTemplate];
    }
}

@end
