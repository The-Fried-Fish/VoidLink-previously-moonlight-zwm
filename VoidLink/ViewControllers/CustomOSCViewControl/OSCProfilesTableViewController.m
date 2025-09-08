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

@interface OSCProfilesTableViewController () <UIGestureRecognizerDelegate>

@end

@implementation OSCProfilesTableViewController {
    OSCProfilesManager *profilesManager;
    NSArray *storedLeftBarItems;
    NSArray *storedRightBarItems;
    NSString *storedNavTitle;
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

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"OSCProfilesOverlayRemove" object:nil];
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

    // 恢复底部系统 UIToolbar 的圆角（下边两个角）
    if (self.systemBottomToolbar) {
        self.systemBottomToolbar.clipsToBounds = YES;
        self.systemBottomToolbar.layer.cornerRadius = 15;
#ifdef __IPHONE_11_0
        if ([self.systemBottomToolbar.layer respondsToSelector:@selector(setMaskedCorners:)]) {
            self.systemBottomToolbar.layer.maskedCorners = kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
        }
#endif
    }
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
    self.view.backgroundColor = [UIColor clearColor];
    self.tableView.alpha = 1.0;
    // 列表主体使用白色 95% 透明背景
    self.tableView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.95];
    // 顶部文字按钮统一使用青色
    if (self.navigationController) {
        self.navigationController.navigationBar.tintColor = [UIColor systemTealColor];
        // 移除顶部工具栏透明度
        self.navigationController.navigationBar.translucent = NO;
        self.navigationController.navigationBar.barTintColor = [UIColor whiteColor];
    }
    if (self.profileTableViewNavigationBar) {
        self.profileTableViewNavigationBar.tintColor = [UIColor systemTealColor];
        self.profileTableViewNavigationBar.translucent = NO;
        self.profileTableViewNavigationBar.barTintColor = [UIColor whiteColor];
    }
    
    // 移除系统自带分隔线，避免与自定义分隔线叠加
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;

    // 添加点击背景关闭的手势（仅在点击 tableView 以外区域时生效）
    UITapGestureRecognizer *bgTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleBackgroundTap:)];
    bgTap.cancelsTouchesInView = NO;
    bgTap.delegate = self;
    [self.view addGestureRecognizer:bgTap];
    
    // 初始化配对状态
    self.isPairingMode = NO;
    self.selectedProfileForPairing = nil;
    self.isProcessingOrientationChange = NO;
    
    // 设置底部工具栏（自定义bar 与 系统UIToolbar 二选一，系统UIToolbar优先）
    if (self.systemBottomToolbar) {
        // 系统 Toolbar 存在：优先使用系统 Toolbar
        [self updateSystemToolbarItems];
    } else {
        // 兼容旧版自定义工具栏
        [self setupBottomToolbar];
    }
    
    // 调整tableView的底部边距，为工具栏留出空间（系统或自定义）
    CGFloat tbHeight = self.systemBottomToolbar ? self.systemBottomToolbar.bounds.size.height : 50.0;
    CGFloat bottomInset = MAX(64.0, tbHeight + 30.0);
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, bottomInset, 0);
    self.tableView.scrollIndicatorInsets = UIEdgeInsetsMake(0, 0, bottomInset, 0);
    
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
    if (self.systemBottomToolbar) {
        [self updateSystemToolbarItems];
    }
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
    NSString *confirmMessage = [LocalizationHelper localizedStringForKey:@"ConfirmDeleteProfile:%@", currentProfile.name];
    UIAlertController *confirmController = [UIAlertController alertControllerWithTitle:[LocalizationHelper localizedStringForKey:@"ConfirmDelete"] message:confirmMessage preferredStyle:UIAlertControllerStyleAlert];
    
    [confirmController addAction:[UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Cancel"] style:UIAlertActionStyleCancel handler:nil]];
    [confirmController addAction:[UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Delete"] style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
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
    
    // 名称 + 可选“横屏/竖屏”胶囊
    NSString *baseName = profile.name ?: @"未命名配置";  // 防止name为nil

    // 模板布局不再添加 emoji

    // 配对模式下的可选性与配色
    BOOL canSelect = [self canSelectProfileForPairing:profile];
    BOOL isCurrentSelectedProfileRow = [[[profilesManager getSelectedProfile] name] isEqualToString:profile.name];
    BOOL isPairSelectionRow = (self.isPairingMode && self.selectedProfileForPairing && [self.selectedProfileForPairing isEqualToString:profile.name]);
    UIColor *nameColor = [UIColor blackColor];
    if (self.isPairingMode) {
        if (isPairSelectionRow) {
            // 选中的配对目标：teal
            nameColor = [UIColor systemTealColor];
            cell.userInteractionEnabled = YES;
            cell.contentView.alpha = 1.0;
        } else if (isCurrentSelectedProfileRow) {
            // 当前正在使用的布局：文字 teal，整体不降透明度
            nameColor = [UIColor systemTealColor];
            cell.userInteractionEnabled = NO;
            cell.contentView.alpha = 1.0;
        } else if (!canSelect) {
            // 其它不可选：灰
            nameColor = [UIColor colorWithWhite:0 alpha:0.3];
            cell.userInteractionEnabled = NO;
            cell.contentView.alpha = 0.7; // 整体降低 30% 透明度
        } else {
            nameColor = [UIColor blackColor];
            cell.userInteractionEnabled = YES;
            cell.contentView.alpha = 1.0;
        }
    } else {
        nameColor = isCurrentSelectedProfileRow ? [UIColor systemTealColor] : [UIColor blackColor];
        cell.userInteractionEnabled = YES;
        cell.contentView.alpha = 1.0;
    }

    UIFont *nameFont = [UIFont systemFontOfSize:20 weight:UIFontWeightMedium];
    NSMutableAttributedString *line = [[NSMutableAttributedString alloc] initWithString:baseName attributes:@{NSFontAttributeName:nameFont, NSForegroundColorAttributeName:nameColor}];
     
     if (profile.isPaired) {
         // 4pt 间距
         NSAttributedString *space = [[NSAttributedString alloc] initWithString:@" " attributes:@{NSKernAttributeName:@(4)}];
         [line appendAttributedString:space];
         
         NSString *pillText = profile.isLandscapeLayout ? @"横屏" : @"竖屏";
         BOOL pillDisabled = (self.isPairingMode && (!canSelect || isCurrentSelectedProfileRow));
         BOOL pillSelected = self.isPairingMode ? isPairSelectionRow : isCurrentSelectedProfileRow;
         UIImage *pill = [self osc_makeOrientationPill:pillText selected:pillSelected disabled:pillDisabled];
         if (pill) {
             NSTextAttachment *att = [[NSTextAttachment alloc] init];
             att.image = pill;
             att.bounds = CGRectMake(0, -2, pill.size.width, pill.size.height);
             [line appendAttributedString:[NSAttributedString attributedStringWithAttachment:att]];
         }
     }
     
     cell.name.attributedText = line;
     cell.name.backgroundColor = [UIColor clearColor];
     cell.name.alpha = 1.0;
     cell.name.font = nameFont;
     // 去掉阴影
     cell.name.shadowColor = nil;
     cell.name.shadowOffset = CGSizeZero;

    // Set cell and contentView background colors
    BOOL isCurrentRowInPairingMode = (self.isPairingMode && isCurrentSelectedProfileRow);
    cell.backgroundColor = isCurrentRowInPairingMode ? [[UIColor systemTealColor] colorWithAlphaComponent:0.08] : [UIColor clearColor];
    cell.contentView.backgroundColor = [UIColor clearColor];

    // 在配对模式下为“当前布局”行右侧添加 14pt 小字
    UILabel *currentBadge = (UILabel *)[cell viewWithTag:201];
    if (isCurrentRowInPairingMode) {
        if (!currentBadge) {
            currentBadge = [[UILabel alloc] init];
            currentBadge.tag = 201;
            currentBadge.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
            currentBadge.textColor = [[UIColor blackColor] colorWithAlphaComponent:0.3];
            currentBadge.textAlignment = NSTextAlignmentRight;
            currentBadge.backgroundColor = [UIColor clearColor];
            currentBadge.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
            [cell addSubview:currentBadge];
        }
        currentBadge.hidden = NO;
        currentBadge.text = [LocalizationHelper localizedStringForKey:@"CurrentLayoutShort"];
        currentBadge.textColor = [[UIColor systemTealColor] colorWithAlphaComponent:0.9];
        CGSize txt = [currentBadge.text sizeWithAttributes:@{NSFontAttributeName: currentBadge.font}];
        CGFloat paddingRight = 16.0;
        CGFloat x = cell.bounds.size.width - paddingRight - txt.width;
        CGFloat y = floor((cell.bounds.size.height - txt.height) * 0.5);
        currentBadge.frame = CGRectMake(x, y, txt.width, txt.height);
    } else if (currentBadge) {
        currentBadge.hidden = YES;
    }
    
    // Configure the checkmark accessory
    if (self.isPairingMode) {
        // 配对模式：隐藏当前使用布局的小勾；仅对选中的配对目标显示小勾
        cell.accessoryType = UITableViewCellAccessoryNone;
    } else {
        if (isCurrentSelectedProfileRow) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    }
    
    // Remove existing custom separators to avoid duplicates
    UIView *existingSeparator = [cell viewWithTag:100];
    if (existingSeparator) {
        [existingSeparator removeFromSuperview];
    }

    // Add custom separator with increased height (thickness)
    CGFloat separatorHeight = 1.0; // Adjust this value for thicker line
    // 使用 cell 的宽度，确保分隔线在 accessory 区域下方也能显示完整
    UIView *separatorView = [[UIView alloc] initWithFrame:CGRectMake(0, cell.bounds.size.height - separatorHeight, cell.bounds.size.width, separatorHeight)];
    
    // 分隔线：黑色 12% 透明度
    separatorView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.12];
    separatorView.tag = 100;  // Assign a tag to identify the separator view
    separatorView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;

    // 加到 cell 上以避免 contentView 宽度被 accessory 缩短导致分隔线变短
    [cell addSubview:separatorView];
    [cell bringSubviewToFront:separatorView];


    // Replace the default checkmark with a UILabel displaying a checkmark character
    if (self.isPairingMode) {
        if (isPairSelectionRow) {
            UILabel *checkmarkLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 20, 20)];
            checkmarkLabel.text = @"✓";
            checkmarkLabel.font = [UIFont systemFontOfSize:25];
            checkmarkLabel.textAlignment = NSTextAlignmentCenter;
            checkmarkLabel.textColor = [UIColor systemTealColor];
            cell.accessoryView = checkmarkLabel;
            checkmarkLabel.layer.zPosition = 0;
        } else {
            cell.accessoryView = nil;
        }
        // 当前布局：强制隐藏系统默认 accessoryType
        cell.accessoryType = UITableViewCellAccessoryNone;
    } else {
        if (isCurrentSelectedProfileRow) {
            UILabel *checkmarkLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 20, 20)];
            checkmarkLabel.text = @"✓";
            checkmarkLabel.font = [UIFont systemFontOfSize:25];
            checkmarkLabel.textAlignment = NSTextAlignmentCenter;
            checkmarkLabel.textColor = [UIColor systemTealColor];
            cell.accessoryView = checkmarkLabel;
            checkmarkLabel.layer.zPosition = 0;
        } else {
            cell.accessoryView = nil;
        }
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
            NSString *message = [LocalizationHelper localizedStringForKey:@"DeleteTemplateNotAllowed:%@", profileToDelete.name];
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"" message:message preferredStyle:UIAlertControllerStyleAlert];
            
            [alertController addAction:[UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Ok"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                [alertController dismissViewControllerAnimated:NO completion:nil];
            }]];
            [self presentViewController:alertController animated:YES completion:nil];
            return;
        }
        
        // 删除确认弹窗
        NSString *confirmMessage = [LocalizationHelper localizedStringForKey:@"ConfirmDeleteProfile:%@", profileToDelete.name];
        UIAlertController *confirmController = [UIAlertController alertControllerWithTitle:[LocalizationHelper localizedStringForKey:@"ConfirmDelete"] message:confirmMessage preferredStyle:UIAlertControllerStyleAlert];
        
        [confirmController addAction:[UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Cancel"] style:UIAlertActionStyleCancel handler:nil]];
        [confirmController addAction:[UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Delete"] style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
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
            if (self.systemBottomToolbar) {
                [self updateSystemToolbarItems];
            }
            // 刷新整表以更新：
            // 1) 选中配对目标行（小勾 + teal）
            // 2) 当前使用的布局行（隐藏小勾 + 30% 黑）
            // 3) 不可选项（变灰）
            [self.tableView reloadData];
            // 滚动确保选中项可见
            NSIndexPath *visible = [NSIndexPath indexPathForRow:indexPath.row inSection:0];
            [self.tableView scrollToRowAtIndexPath:visible atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
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
        selectedCell.accessoryType = UITableViewCellAccessoryCheckmark;
        // 选中时的勾颜色统一为青色
        selectedCell.accessoryView.tintColor = [UIColor systemTealColor];
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
    // 系统 UIToolbar 优先：如果 storyboard 连接了系统 toolbar，则同步系统 toolbar
    if (self.systemBottomToolbar) {
        [self updateSystemToolbarItems];
        return;
    }
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

#pragma mark - System UIToolbar Support

- (void)updateSystemToolbarItems {
    if (!self.systemBottomToolbar || !self.pairRotationalToolbarItem) {
        return;
    }

    OSCProfile *selectedProfile = [profilesManager getSelectedProfile];
    BOOL isTemplate = selectedProfile && [profilesManager isTemplateProfile:selectedProfile.name];
    BOOL isCurrentProfilePaired = selectedProfile ? selectedProfile.isPaired : NO;
    BOOL isLandscape = [profilesManager isCurrentOrientationLandscape];

    if (self.isPairingMode) {
        // 配对模式：主按钮=保存；右侧问号=取消
        self.pairRotationalToolbarItem.title = [LocalizationHelper localizedStringForKey:@"Save"];
        self.pairRotationalToolbarItem.enabled = (self.selectedProfileForPairing != nil);
        self.pairRotationalToolbarItem.target = self;
        self.pairRotationalToolbarItem.action = @selector(savePairingTapped:);
        if (self.helpToolbarItem) {
            self.helpToolbarItem.title = [LocalizationHelper localizedStringForKey:@"Cancel"];
            self.helpToolbarItem.image = nil;
            self.helpToolbarItem.target = self;
            self.helpToolbarItem.action = @selector(cancelPairingTapped:);
            self.helpToolbarItem.enabled = YES;
        }
        // 强制保持 items 排列：flexibleSpace + pair + help
        UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
        if (self.helpToolbarItem) {
            [self.systemBottomToolbar setItems:@[flex, self.pairRotationalToolbarItem, self.helpToolbarItem] animated:NO];
        }
        return;
    }

    // 普通模式
    self.pairRotationalToolbarItem.enabled = !isTemplate;
    self.pairRotationalToolbarItem.target = self;
    self.pairRotationalToolbarItem.action = @selector(pairRotationalToolbarTapped:);

    if (isTemplate) {
        NSString *opposite = isLandscape ? [LocalizationHelper localizedStringForKey:@"PortraitShort"] : [LocalizationHelper localizedStringForKey:@"LandscapeShort"];
        self.pairRotationalToolbarItem.title = [LocalizationHelper localizedStringForKey:@"BindOrientationLayout:%@", opposite];
        self.pairRotationalToolbarItem.enabled = NO;
    } else if (isCurrentProfilePaired) {
        self.pairRotationalToolbarItem.title = [LocalizationHelper localizedStringForKey:@"Unpair"];
    } else {
        NSString *opposite = isLandscape ? [LocalizationHelper localizedStringForKey:@"PortraitShort"] : [LocalizationHelper localizedStringForKey:@"LandscapeShort"];
        self.pairRotationalToolbarItem.title = [LocalizationHelper localizedStringForKey:@"BindOrientationLayout:%@", opposite];
    }

    if (self.helpToolbarItem) {
        // 正常模式：问号作为“帮助”，点击弹出说明
        self.helpToolbarItem.title = nil; // 保持问号图标
        // 退出配对模式后恢复问号图标
        #if __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
        if (@available(iOS 13.0, *)) {
            self.helpToolbarItem.image = [UIImage systemImageNamed:@"questionmark.circle"];
        }
        #endif
        self.helpToolbarItem.target = self;
        self.helpToolbarItem.action = @selector(helpToolbarTapped:);
        self.helpToolbarItem.enabled = !isTemplate; // 模板布局置灰
    }

    // 强制保持 items 排列：flexibleSpace + pair + help
    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    if (self.helpToolbarItem) {
        [self.systemBottomToolbar setItems:@[flex, self.pairRotationalToolbarItem, self.helpToolbarItem] animated:NO];
    }
}

- (IBAction)pairRotationalToolbarTapped:(id)sender {
    if (self.isPairingMode) {
        if (self.selectedProfileForPairing) {
            [self savePairingTapped:sender];
        } else {
            [self cancelPairingTapped:sender];
        }
        return;
    }

    OSCProfile *selectedProfile = [profilesManager getSelectedProfile];
    if (selectedProfile && selectedProfile.isPaired) {
        [self unpairTapped:sender];
    } else {
        [self startPairingTapped:sender];
    }
    [self updateSystemToolbarItems];
}

- (IBAction)helpToolbarTapped:(id)sender {
    NSString *message = [LocalizationHelper localizedStringForKey:@"PairingHelpMessage"];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[LocalizationHelper localizedStringForKey:@"PairingHelpTitle"] message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"OK"] style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)createPairingModeButtons {
    // 创建取消按钮
    self.cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.cancelButton setTitle:[LocalizationHelper localizedStringForKey:@"Cancel"] forState:UIControlStateNormal];
    [self.cancelButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.cancelButton addTarget:self action:@selector(cancelPairingTapped:) forControlEvents:UIControlEventTouchUpInside];
    self.cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.bottomToolbarView addSubview:self.cancelButton];
    
    // 创建保存按钮
    self.saveButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.saveButton setTitle:[LocalizationHelper localizedStringForKey:@"Save"] forState:UIControlStateNormal];
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
    if (self.systemBottomToolbar) {
        [self updateSystemToolbarItems];
    }
    // 隐藏顶部导航按钮并设置标题
    UINavigationItem *navItem = self.navigationController ? self.navigationController.navigationBar.topItem : self.profileTableViewNavigationBar.topItem;
    if (navItem) {
        storedLeftBarItems = navItem.leftBarButtonItems;
        storedRightBarItems = navItem.rightBarButtonItems;
        storedNavTitle = navItem.title;
        navItem.leftBarButtonItems = @[];
        navItem.rightBarButtonItems = @[];
        BOOL isLandscape = [profilesManager isCurrentOrientationLandscape];
        NSString *dir = isLandscape ? [LocalizationHelper localizedStringForKey:@"LandscapeShort"] : [LocalizationHelper localizedStringForKey:@"PortraitShort"];
        navItem.title = [LocalizationHelper localizedStringForKey:@"SelectLayoutToPair:%@", dir];
    }
    [self.tableView reloadData];
}

- (IBAction)unpairTapped:(id)sender {
    OSCProfile *selectedProfile = [profilesManager getSelectedProfile];
    if (selectedProfile && selectedProfile.isPaired) {
        [profilesManager unpairProfile:selectedProfile.name];
        [self updateToolbarButtons];
        if (self.systemBottomToolbar) {
            [self updateSystemToolbarItems];
        }
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
            if (self.systemBottomToolbar) {
                [self updateSystemToolbarItems];
            }
            // 恢复导航按钮和标题
            UINavigationItem *navItem = self.navigationController ? self.navigationController.navigationBar.topItem : self.profileTableViewNavigationBar.topItem;
            if (navItem) {
                navItem.leftBarButtonItems = storedLeftBarItems;
                navItem.rightBarButtonItems = storedRightBarItems;
                navItem.title = storedNavTitle;
            }
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
    if (self.systemBottomToolbar) {
        [self updateSystemToolbarItems];
    }
    // 恢复导航按钮和标题
    UINavigationItem *navItem = self.navigationController ? self.navigationController.navigationBar.topItem : self.profileTableViewNavigationBar.topItem;
    if (navItem) {
        navItem.leftBarButtonItems = storedLeftBarItems;
        navItem.rightBarButtonItems = storedRightBarItems;
        navItem.title = storedNavTitle;
    }
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

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    // 仅当点击在 tableView 之外时，才触发手势
    CGPoint p = [touch locationInView:self.view];
    if (CGRectContainsPoint(self.tableView.frame, p)) {
        return NO;
    }
    return YES;
}

- (void)handleBackgroundTap:(UITapGestureRecognizer *)gr {
    if (gr.state == UIGestureRecognizerStateEnded) {
        [self dismissViewControllerAnimated:YES completion:nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"OSCProfilesOverlayRemove" object:nil];
    }
}

// 绘制“横屏/竖屏”胶囊
- (UIImage *)osc_makeOrientationPill:(NSString *)text selected:(BOOL)selected disabled:(BOOL)disabled {
    const CGFloat pillHeight = 18.0; // 调整为 18pt 高
    const CGFloat cornerRadius = 3.0;
    const CGFloat horizontalPadding = 4.0; // 左右各 4pt
    UIFont *font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightRegular]; // 字号 13pt
    UIColor *teal = [UIColor systemTealColor];
    UIColor *fillColor;
    UIColor *textColor;
    if (disabled) {
        fillColor = [[UIColor blackColor] colorWithAlphaComponent:0.08];
        textColor = [[UIColor blackColor] colorWithAlphaComponent:0.3];
    } else {
        fillColor = selected ? [teal colorWithAlphaComponent:0.12] : [[UIColor blackColor] colorWithAlphaComponent:0.12];
        textColor = selected ? [teal colorWithAlphaComponent:0.8] : [[UIColor blackColor] colorWithAlphaComponent:0.8];
    }

    NSDictionary *attrs = @{ NSFontAttributeName: font, NSForegroundColorAttributeName: textColor };
    CGSize textSize = [text sizeWithAttributes:attrs];
    CGFloat pillWidth = ceil(textSize.width) + horizontalPadding * 2.0;
    CGSize canvas = CGSizeMake(pillWidth, pillHeight);

    UIGraphicsBeginImageContextWithOptions(canvas, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (ctx) {
        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, canvas.width, canvas.height) cornerRadius:cornerRadius];
        [fillColor setFill];
        [path fill];
        
        // 居中绘制文字
        CGFloat tx = horizontalPadding;
        CGFloat ty = floor((pillHeight - textSize.height) * 0.5);
        [text drawAtPoint:CGPointMake(tx, ty) withAttributes:attrs];
    }
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

@end
