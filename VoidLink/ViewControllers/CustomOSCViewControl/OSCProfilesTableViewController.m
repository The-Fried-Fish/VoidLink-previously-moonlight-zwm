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
    
    profilesManager = [OSCProfilesManager sharedManager:_streamViewBounds];
    
    self.tableView.tableHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, NAV_BAR_HEIGHT)];
    
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    [self.tableView registerNib:[UINib nibWithNibName:@"ProfileTableViewCell" bundle:nil]
         forCellReuseIdentifier:@"Cell"]; // Register the custom cell nib file with the table view
    self.tableView.alpha = 0.7;
    //self.tableView.backgroundColor = [[UIColor colorWithRed:0.5 green:0.7 blue:1.0 alpha:1.0] colorWithAlphaComponent:0.2]; // set background color & transparency
    self.tableView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.1]; // set background color & transparency
    // self.tableView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.2]; // set background color & transparency

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
            
            if ([enteredProfileName isEqualToString:@"Default"]) {  // don't let user user overwrite the 'Default' profile
                UIAlertController *alertController = [UIAlertController alertControllerWithTitle: [NSString stringWithFormat:@""] message: [LocalizationHelper localizedStringForKey:@"Saving over the 'Default' profile is not allowed"] preferredStyle:UIAlertControllerStyleAlert];
                
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
    if (self.needToUpdateOscLayoutTVC) {    // tells the presenting view controller to lay out the on screen buttons according to the selected profile's instructions
        self.needToUpdateOscLayoutTVC();
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:@"OscLayoutProfileSelctedInTableView" object:self]; // notify other view that oscLayoutManager is closing
}

- (IBAction) deleteTapped:(id)sender{// delete can be executed simply by calling this 2 methods.
    [profilesManager deleteCurrentSelectedProfile];
    [self profileViewRefresh];
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
    OSCProfile *profile = [[profilesManager getAllProfiles] objectAtIndex:indexPath.row];
    cell.name.text = profile.name;
    cell.name.backgroundColor = [UIColor clearColor];
    cell.name.alpha = 1.0;
    cell.name.textColor = [UIColor whiteColor];  // Opaque white text
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
    return YES;
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 60.0; // Set your desired cell height here
}


- (void) tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    NSMutableArray *profiles = [profilesManager getAllProfiles];

    if ([[[profiles objectAtIndex:indexPath.row] name] isEqualToString:@"Default"]) {   // if user is attempting to delete the 'Default' profile then show a pop up telling user they can't do that and return out of this method
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle: [NSString stringWithFormat:@""] message: @"Deleting the 'Default' profile is not allowed" preferredStyle:UIAlertControllerStyleAlert];
        
        [alertController addAction:[UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Ok"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [alertController dismissViewControllerAnimated:NO completion:nil];
        }]];
        [self presentViewController:alertController animated:YES completion:nil];
        
        return;
    }
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        OSCProfile *profile = [profiles objectAtIndex:indexPath.row];
        if (profile.isSelected) {   // if user is deleting the currently selected OSC profile then make the  profile at its previous index the currently selected profile
            if (indexPath.row > 0) {    // check that row is greater than zero to avoid an out of bounds crash, although that should not be possible right now since the 'Default' profile is always at row 0 and they're not allowed to delete it
                OSCProfile *profile = [profiles objectAtIndex:indexPath.row - 1];
                profile.isSelected = YES;
            }
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
        
        [tableView reloadData]; 
    }
}


#pragma mark - TableView Delegate

/* When user taps a cell it moves the checkmark to that cell indicating to the user the profile associated with that cell is now the selected profile. It also sets that cell's associated OSCProfile object's 'isSelected' property to YES  */
- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSIndexPath *selectedIndexPath = [NSIndexPath indexPathForRow:indexPath.row inSection:0];
    NSIndexPath *lastSelectedIndexPath = [NSIndexPath indexPathForRow:[profilesManager getIndexOfSelectedProfile] inSection:0];

    if (selectedIndexPath != lastSelectedIndexPath) {
        /* Place checkmark on selected cell and set profile associated with cell as selected profile */
        UITableViewCell *selectedCell = [tableView cellForRowAtIndexPath: selectedIndexPath];
        selectedCell.accessoryType = UITableViewCellAccessoryCheckmark;  // add checkmark to the cell the user tapped
        selectedCell.accessoryView.tintColor = [[UIColor colorWithRed:0.5 green:0.5 blue:1.0 alpha:0.85] colorWithAlphaComponent:1.0];
        OSCProfile *profile = [[profilesManager getAllProfiles] objectAtIndex:indexPath.row];
        [profilesManager setProfileToSelected: profile.name];   // set the profile associated with this cell's 'isSelected' property to YES
        
        /* Remove checkmark on the previously selected cell  */
        UITableViewCell *lastSelectedCell = [tableView cellForRowAtIndexPath: lastSelectedIndexPath];
        lastSelectedCell.accessoryType = UITableViewCellAccessoryNone; 
        [tableView deselectRowAtIndexPath:lastSelectedIndexPath animated:YES];
    }
    [self profileViewRefresh]; // update OSC layout when table view option is changed
}


@end
