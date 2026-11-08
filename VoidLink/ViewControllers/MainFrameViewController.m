//  MainFrameViewController.m
//  Moonlight
//
//  Created by Diego Waxemberg on 1/17/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//
//  Modified by True砖家 since 2024.6.29
//  Copyright © 2024 True砖家 @ Bilibili. All rights reserved.
//

@import ImageIO;

#import "MainFrameViewController.h"
#import "SceneDelegate.h"
#import "CryptoManager.h"
#import "HttpManager.h"
#import "Connection.h"
#import "StreamManager.h"
#import "Utils.h"
#import "AppDelegate.h"
#import "TemporaryHost.h"
#import "TemporaryApp.h"
#import "WakeOnLanManager.h"
#import "AppListResponse.h"
#import "ServerInfoResponse.h"
#import "StreamFrameViewController.h"
#import "LoadingFrameViewController.h"
#import "IdManager.h"
#import "ConnectionHelper.h"
#import "LocalizationHelper.h"
#import "Plot.h"
#if !TARGET_OS_TV
#import "CustomEdgeSlideGestureRecognizer.h"
#endif
#import "VoidLink-Swift.h"

#if TARGET_OS_TV
#import <sys/utsname.h>
#endif

#import <VideoToolbox/VideoToolbox.h>

#include <Limelight.h>


@interface MainFrameViewController() <AppCallback, HostCardActionDelegate, AppViewUpdateLoopDelegate, ControllerNavigatorRadialMenuDelegate, ControllerUtilDelegate>
#if TARGET_OS_TV
@property (weak, nonatomic) ProfileSelectorViewController* gameProfileSelectorVC;
#else
@property (weak, nonatomic) LayoutOnScreenControlsViewController* gameProfileSelectorVC;
#endif
@property (nonatomic, strong, readwrite) NSArray<TemporaryApp *> *sortedAppList;
@property (nonatomic, assign) bool settingsViewExpanded;
@property (nonatomic, strong, readwrite) DeeplinkCoordinator *deeplinkCoordinator;
@end

#if TARGET_OS_TV
@interface MainFrameViewController (TVProfileSelector)
- (void)openGameProfileSeletorWithAnimated:(bool)animated;
@end
#endif

static NSArray<UIBarButtonItem *> *VLBarButtonItems(UIBarButtonItem *first, UIBarButtonItem *second) {
    NSMutableArray<UIBarButtonItem *> *items = [NSMutableArray arrayWithCapacity:2];
    if (first) [items addObject:first];
    if (second) [items addObject:second];
    return items;
}

@implementation MainFrameViewController {
    UILabel* waterMark;
    UIBarButtonItem* _addHostButton;
    UIBarButtonItem* _helpButton;
    UIBarButtonItem* _upButton;
    NSArray<NSLayoutConstraint *> *_appCollectionSafeAreaConstraints;
    UIViewAutoresizing _appCollectionOriginalAutoresizingMask;
    BOOL _appCollectionOriginalTranslatesAutoresizingMask;
#if DEBUG
    NSMutableDictionary<NSString *, NSString *> *_appCollectionLayoutDiagnosticStates;
#endif
    BOOL _profilesButtonUsesCompactSymbol;

    UILabel* hostViewTitleLabel;
    //CGFloat recordedScreenWidth;
    NSOperationQueue* _opQueue;
    TemporaryHost* _selectedHost;
    BOOL _showHiddenApps;
    NSString* _uniqueId;
    NSData* _clientCert;
    DiscoveryManager* _discMan;
    AppAssetManager* _appManager;
    StreamConfiguration* _streamConfig;
    UIAlertController* _pairAlert;
    LoadingFrameViewController* _loadingFrame;
    FrontViewPosition currentPosition;
    NSCache* _boxArtCache;
    NSOperationQueue* _boxArtQueue;
    bool _background;
    bool _enteredAppView;
    UIView* menuSeparator;
    UIView* snapshot;
    __weak StreamFrameViewController* streamFrameViewController;
    id navBarAppearanceStandard;
    bool _viewJustAppeared;
    TemporaryApp * launchedApp;

    NSTimer *_foregroundHostUpdateTimer;
    
    id _controllerConnectObserver;
    BOOL _openingDeeplinkHost;
    id _controllerDisconnectObserver;
    UIView* _debugGamepadOverlay;

}
static NSMutableSet* hostList;

- (DeeplinkCoordinator *)deeplinkCoordinator {
    if (!_deeplinkCoordinator) {
        _deeplinkCoordinator = [[DeeplinkCoordinator alloc] initWithMainFrame:self];
    }
    return _deeplinkCoordinator;
}

- (BOOL)wakeDeeplinkHost:(TemporaryHost *)host {
    if (host.mac.length == 0 || [host.mac isEqualToString:@"00:00:00:00:00:00"]) return NO;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [WakeOnLanManager wakeHost:host];
    });
    return YES;
}

- (void)prepareDeeplinkHostView {
    [self closeSettingViewAnimated:NO];
    [self switchToHostView];
    [_discMan startDiscovery];
    [self.hostCollectionVC reportOnlineHostsForDeeplink];
}

- (void)openDeeplinkHost:(TemporaryHost *)host showHiddenApps:(BOOL)showHiddenApps {
    if ([self isStreaming]) return;
    _selectedHost = host;
    _showHiddenApps = showHiddenApps;
    if (host.pairState == PairStatePaired) {
        _openingDeeplinkHost = YES;
        [self switchToAppView];
        _openingDeeplinkHost = NO;
    } else {
        [self pairButtonTappedForHost:host];
    }
}


- (void)startPairing:(NSString *)PIN {
    // Needs to be synchronous to ensure the alert is shown before any potential
    // failure callback could be invoked.
    dispatch_sync(dispatch_get_main_queue(), ^{
        self->_pairAlert = [UIAlertController alertControllerWithTitle:[LocalizationHelper localizedStringForKey:@"Pairing"]
                                                               message:[LocalizationHelper localizedStringForKey:@"Enter_PIN_Msg", PIN]
                                                        preferredStyle:UIAlertControllerStyleAlert];
        [self->_pairAlert addAction:[UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Cancel"] style:UIAlertActionStyleDestructive handler:^(UIAlertAction* action) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self->_pairAlert = nil;
                [self->_discMan startDiscovery];
                [self hideLoadingFrame: ^{
                    [self switchToHostView];
                }];
            });
        }]];
        [[self activeViewController] presentViewController:self->_pairAlert animated:YES completion:nil];
    });
}

- (void)displayPairingFailureDialog:(NSString *)message {
    UIAlertController* failedDialog = [UIAlertController alertControllerWithTitle:[LocalizationHelper localizedStringForKey:@"Pairing Failed"]
                                                                          message:message
                                                                   preferredStyle:UIAlertControllerStyleAlert];
    [Utils addHelpOptionToDialog:failedDialog];
    [failedDialog addAction:[UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Ok"] style:UIAlertActionStyleDefault handler:nil]];
    
    [_discMan startDiscovery];
    
    [self hideLoadingFrame: ^{
        [self switchToHostView];
        [[self activeViewController] presentViewController:failedDialog animated:YES completion:nil];
    }];
}

- (void)pairFailed:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self->_pairAlert != nil) {
            [self->_pairAlert dismissViewControllerAnimated:YES completion:^{
                [self displayPairingFailureDialog:message];
            }];
            self->_pairAlert = nil;
        }
    });
}

- (void)pairSuccessful:(NSData*)serverCert {
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_selectedHost.serverCert = serverCert;
        UIAlertController *pairAlert = self->_pairAlert;
        self->_pairAlert = nil;
        void (^continueToApps)(void) = ^{
            [self->_discMan startDiscovery];
            if ([self->_deeplinkCoordinator isWaitingForAppsForHost:self->_selectedHost]) {
                self->_openingDeeplinkHost = YES;
                [self switchToAppView];
                self->_openingDeeplinkHost = NO;
            } else {
                [self alreadyPaired];
            }
        };
        if (pairAlert) [pairAlert dismissViewControllerAnimated:YES completion:continueToApps];
        else continueToApps();
    });
}


- (void)updateTitle {

#if TARGET_OS_TV
    self.navigationController.navigationBar.titleTextAttributes = @{
        NSFontAttributeName: [UIFont systemFontOfSize:PublicUtils.isTVOS?42:20 weight: PublicUtils.isTVOS?UIFontWeightSemibold:UIFontWeightMedium],
        NSForegroundColorAttributeName: ThemeManager.textColor
    };
#else
    if (@available(iOS 13.0, *)) {
        UINavigationBarAppearance* appearance = navBarAppearanceStandard;
        NSDictionary* titleTextAttributes = @{
            NSFontAttributeName: [UIFont systemFontOfSize:20 weight:UIFontWeightMedium],
            NSForegroundColorAttributeName: ThemeManager.textColor // 可选，设置标题颜色
        };
        appearance.titleTextAttributes = titleTextAttributes;
        navBarAppearanceStandard = appearance;
    }
#endif

    if (_selectedHost != nil) {
        self.title = _selectedHost.name;
    }
    else if ([hostList count] == 0) {

        self.title = [LocalizationHelper localizedStringForKey: @"Searching for PCs on your network..."] ;
    }
    else {
#if !TARGET_OS_TV
        if (@available(iOS 13.0, *)) {

            UINavigationBarAppearance* appearance = navBarAppearanceStandard;
            NSDictionary* titleTextAttributes = @{
                NSFontAttributeName: [UIFont systemFontOfSize:20 weight:UIFontWeightMedium],
                NSForegroundColorAttributeName: ThemeManager.textColor // 可选，设置标题颜色
            };
            appearance.titleTextAttributes = titleTextAttributes;
            navBarAppearanceStandard = appearance;
        }
#endif
        /*
        self.navigationController.navigationBar.titleTextAttributes = @{
            NSFontAttributeName: [UIFont systemFontOfSize:24 weight:UIFontWeightSemibold],
            NSForegroundColorAttributeName: ThemeManager.textColor // 可选，设置标题颜色
        };*/
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.title = [LocalizationHelper localizedStringForKey:
                          (PublicUtils.isTVOS && self->_hostCollectionVC.items.count>0) ? @"" : @"Hosts" ];
        });
        //self.title = nil;
    }
    [self applyNavBarAppearance];
}

- (void)alreadyPaired {
    BOOL usingCachedAppList = false;
    
    // Capture the host here because it can change once we
    // leave the main thread
    TemporaryHost* host = _selectedHost;
    if (host == nil) {
        [self hideLoadingFrame: nil];
        return;
    }
    
    if ([host.appList count] > 0) {
        usingCachedAppList = true;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (host != self->_selectedHost) {
                [self hideLoadingFrame: nil];
                return;
            }
            
            [self updateAppsForHost:host];
            [self hideLoadingFrame: nil];
        });
    }
    Log(LOG_I, @"Using cached app list: %d", usingCachedAppList);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // Exempt this host from discovery while handling the applist query
        [self->_discMan pauseDiscoveryForHost:host];
        
        AppListResponse* appListResp = [ConnectionHelper getAppListForHost:host];
        
        [self->_discMan resumeDiscoveryForHost:host];
        
        if (![appListResp isStatusOk] || [appListResp getAppList] == nil) {
            Log(LOG_W, @"Failed to get applist: %@", appListResp.statusMessage);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (host != self->_selectedHost) {
                    [self hideLoadingFrame: nil];
                    return;
                }
                
                UIAlertController* applistAlert = [UIAlertController alertControllerWithTitle:[LocalizationHelper localizedStringForKey:@"Connection Interrupted"]
                                                                                      message:appListResp.statusMessage
                                                                               preferredStyle:UIAlertControllerStyleAlert];
                [Utils addHelpOptionToDialog:applistAlert];
                [applistAlert addAction:[UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Ok"] style:UIAlertActionStyleDefault handler:nil]];
                [self hideLoadingFrame: ^{
                    [self switchToHostView];
                    [[self activeViewController] presentViewController:applistAlert animated:YES completion:nil];
                }];
                host.state = StateOffline;
                [self hostCardContentsDidChange:host];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self updateApplist:[appListResp getAppList] forHost:host];
                
                if (host != self->_selectedHost) {
                    [self hideLoadingFrame: nil];
                    return;
                }
                
                [self updateAppsForHost:host];
                [self->_appManager stopRetrieving];
                [self->_appManager retrieveAssetsFromHost:host];
                [self hideLoadingFrame:^{
                    [self->_deeplinkCoordinator appsDidRefreshFor:host];
                }];
            });
        }
    });
}

- (void) updateAppEntry:(TemporaryApp*)app forHost:(TemporaryHost*)host {
    DataManager* database = [[DataManager alloc] init];
    NSMutableSet* newHostAppList = [NSMutableSet setWithSet:host.appList];
    
    for (TemporaryApp* savedApp in newHostAppList) {
        if ([app.id isEqualToString:savedApp.id]) {
            savedApp.name = app.name;
            savedApp.hdrSupported = app.hdrSupported;
            savedApp.hidden = app.hidden;
            
            host.appList = newHostAppList;
            
            [database updateAppsForExistingHost:host];
            return;
        }
    }
}

- (void) updateApplist:(NSSet*) newList forHost:(TemporaryHost*)host {
    DataManager* database = [[DataManager alloc] init];
    NSMutableSet* newHostAppList = [NSMutableSet setWithSet:host.appList];
    
    for (TemporaryApp* app in newList) {
        BOOL appAlreadyInList = NO;
        for (TemporaryApp* savedApp in newHostAppList) {
            if ([app.id isEqualToString:savedApp.id]) {
                savedApp.name = app.name;
                savedApp.hdrSupported = app.hdrSupported;
                // Don't propagate hidden, because we want the local data to prevail
                appAlreadyInList = YES;
                break;
            }
        }
        if (!appAlreadyInList) {
            app.host = host;
            [newHostAppList addObject:app];
        }
    }
    
    BOOL appWasRemoved;
    do {
        appWasRemoved = NO;
        
        for (TemporaryApp* app in newHostAppList) {
            appWasRemoved = YES;
            for (TemporaryApp* mergedApp in newList) {
                if ([mergedApp.id isEqualToString:app.id]) {
                    appWasRemoved = NO;
                    break;
                }
            }
            if (appWasRemoved) {
                // Removing the app mutates the list we're iterating (which isn't legal).
                // We need to jump out of this loop and restart enumeration.
                
                [newHostAppList removeObject:app];
                
                // It's important to remove the app record from the database
                // since we'll have a constraint violation now that appList
                // doesn't have this app in it.
                [database removeApp:app];
                
                break;
            }
        }
        
        // Keep looping until the list is no longer being mutated
    } while (appWasRemoved);
    
    host.appList = newHostAppList;
    
    [database updateAppsForExistingHost:host];
    
    // This host may be eligible for a shortcut now that the app list
    // has been populated
    [self updateHostShortcuts];
}

- (void)switchToHostView {
    [_deeplinkCoordinator didReturnToHostView];
    _enteredAppView = false;
    [_appManager stopRetrieving];
    _showHiddenApps = NO;
    _selectedHost = nil;
    self.sortedAppList = nil;
    
    // [self.collectionView removeFromSuperview]; // necessary for new scroll host view reloading mechanism
    self.hostCollectionVC.view.hidden = NO;
    if (![self isStreaming]) {
        [self.hostCollectionVC refreshVisibleHostCards];
    }
    self.collectionView.hidden = YES;
    [self updateTitle];
    self.navigationItem.rightBarButtonItems = PublicUtils.isTVOS
                                            ? VLBarButtonItems(nil, nil)
                                            : VLBarButtonItems(_helpButton, _addHostButton);
    self.revealViewController.mainFrameIsInHostView = true;  // to allow orientation change only in app view, tell top view controller the mainframe is not in host view
    
    if (@available(iOS 13.0, *)){
        [GamepadNavigationIllustrationHud showInKeyWindow];
        [ControllerNavigator setUINavigationDelegate:self.isInAppView ? self.hostCollectionVC : self.hostCollectionVC];
        if(ControllerNavigator.radialMenuView.superview) [ControllerNavigator updateRadialMenu];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (ControllerNavigator.uiNavigationDelegate == self.hostCollectionVC && ![self isStreaming]) {
                [ControllerNavigator restoreUINavigationHighlight];
            }
        });
    }
}

- (void) receivedAssetForApp:(TemporaryApp*)app {
    // Refresh downloaded assets on the same bounded queue as cache prefetches.
    [_boxArtQueue addOperationWithBlock:^{
        @autoreleasepool {
            [self->_boxArtCache removeObjectForKey:app];
            [self updateBoxArtCacheForApp:app];

            dispatch_async(dispatch_get_main_queue(), ^{
                if (![self isInAppView] || app.host != self->_selectedHost) return;
                for (UICollectionViewCell* cell in self.collectionView.visibleCells) {
                    for (UIView* view in cell.subviews) {
                        if ([view isKindOfClass:[UIAppView class]]) {
                            UIAppView* appView = (UIAppView*)view;
                            if (appView.app.host == app.host && [appView.app.id isEqualToString:app.id]) {
                                [appView updateAppImage];
                                return;
                            }
                        }
                    }
                }
            });
        }
    }];
}

- (void)displayDnsFailedDialog {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:[LocalizationHelper localizedStringForKey:@"Network Error"]
                                                                   message:[LocalizationHelper localizedStringForKey:@"Failed to resolve host."]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [Utils addHelpOptionToDialog:alert];
    [alert addAction:[UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Ok"] style:UIAlertActionStyleDefault handler:nil]];
    [[self activeViewController] presentViewController:alert animated:YES completion:nil];
}

- (void)switchToAppView{
    if (!_openingDeeplinkHost) [_deeplinkCoordinator userWillEnterAppView];
    if (@available(iOS 13.0, *)) {
        [ControllerNavigator setUINavigationDelegate:self];
    }
    
    _enteredAppView = true;
    //_appManager = [[AppAssetManager alloc] initWithCallback:self];
    [self.collectionView setCollectionViewLayout:self.collectionViewLayout];
    [self.collectionView reloadData]; //for new scroll host view reloading mechanism
    // [self.view bringSubviewToFront:self.collectionView];
    self.hostCollectionVC.view.hidden = YES;
    self.collectionView.hidden = NO;
    self.collectionView.backgroundColor = ThemeManager.hostViewBackgroundColor;
    //self.view.backgroundColor = [ThemeManager appBackgroundColor];

    // [self.collectionView setContentOffset:CGPointZero animated:NO];
    
    [self attachWaterMark];
    self.navigationItem.rightBarButtonItems = VLBarButtonItems(PublicUtils.tvOS26Aavailable || !PublicUtils.isTVOS ? _upButton : nil, nil);
    self.revealViewController.mainFrameIsInHostView = false;
    // [self disableNavigation];
    [self updateTitle];
    if (_openingDeeplinkHost) {
        [self hideLoadingFrame:^{ [self->_deeplinkCoordinator didEnterDeeplinkAppView]; }];
    }
    [self alreadyPaired];
    [self refreshAppCollectionLayout];
    // self.navigationController.navigationBar.backgroundColor = [ThemeManager appBackgroundColor];
    // self.navigationController.navigationBar.translucent = NO;
    //[self applyNavBarAppearance:navBarAppearance];
    
    [self refreshAppNavigationHighlight];
}

- (void)appButtonTappedForHost:(TemporaryHost *)host{
    if (host.state != StateOnline) return;
    _selectedHost = host;
    if(host.state == StateOnline && host.pairState == PairStatePaired){
        [self updateAppsForHost:host];
        if(host.appList.count>0) [self switchToAppView];
    }
}

- (void)launchButtonTappedForHost:(TemporaryHost *)host {
    if(self.revealViewController.isStreaming) return;
    _selectedHost = host;
    if (host.state == StateOnline && host.pairState == PairStatePaired && host.appList.count > 0) {
        [self closeSettingViewAnimated:NO];
        // [self switchToAppView];
        [self updateAppsForHost:_selectedHost];
        [self prepareToStreamApp:self.sortedAppList.firstObject];
        [self performSegueWithIdentifier:@"createStreamFrame" sender:nil];
        return;
    }
}

- (void)wakeupButtonTappedForHost:(TemporaryHost *)host{
    _selectedHost = host;
    bool hasValidMac = host.mac != nil && ![host.mac isEqualToString:@"00:00:00:00:00:00"];

    //if (hasValidMac) {
    UIAlertController* wolAlert = [UIAlertController alertControllerWithTitle:[LocalizationHelper localizedStringForKey:@"Wake-On-LAN"] message:@"" preferredStyle:UIAlertControllerStyleAlert];
    [wolAlert addAction:[UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Ok"] style:UIAlertActionStyleDefault handler:nil]];
    
    if (!hasValidMac) {
        wolAlert.message = [LocalizationHelper localizedStringForKey: @"Host MAC unknown, unable to send WOL Packet"];
    } else {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [WakeOnLanManager wakeHost:host];
        });
        wolAlert.message = [LocalizationHelper localizedStringForKey:@"Successfully sent wake-up request. It may take a few moments for the PC to wake. If it never wakes up, ensure it's properly configured for Wake-on-LAN."];
    }
    [[self activeViewController] presentViewController:wolAlert animated:YES completion:nil];
    //}
}

- (void)pairButtonTappedForHost:(TemporaryHost *)host{
    _selectedHost = host;
    [self showLoadingFrame: ^{
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            // Wait for the PC's status to be known
            while (host.state == StateUnknown) {
                sleep(1);
            }

            // Don't bother polling if the server is already offline
            if (host.state == StateOffline) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self hideLoadingFrame:^{
                        [self switchToHostView];
                    }];
                });
                return;
            }

            HttpManager* hMan = [[HttpManager alloc] initWithHost:host];
            ServerInfoResponse* serverInfoResp = [[ServerInfoResponse alloc] init];

            // Exempt this host from discovery while handling the serverinfo request
            [self->_discMan pauseDiscoveryForHost:host];
            [hMan executeRequestSynchronously:[HttpRequest requestForResponse:serverInfoResp withUrlRequest:[hMan newServerInfoRequest:false]
                                                                fallbackError:401 fallbackRequest:[hMan newHttpServerInfoRequest]]];
            [self->_discMan resumeDiscoveryForHost:host];

            if (![serverInfoResp isStatusOk]) {
                Log(LOG_W, @"Failed to get server info: %@", serverInfoResp.statusMessage);
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (host != self->_selectedHost) {
                        [self hideLoadingFrame:nil];
                        return;
                    }

                    UIAlertController* applistAlert = [UIAlertController alertControllerWithTitle:[LocalizationHelper localizedStringForKey:@"Connection Failed"]
                                                                                          message:serverInfoResp.statusMessage
                                                                                   preferredStyle:UIAlertControllerStyleAlert];
                    [Utils addHelpOptionToDialog:applistAlert];
                    [applistAlert addAction:[UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Ok"] style:UIAlertActionStyleDefault handler:nil]];

                    // Only display an alert if this was the result of a real
                    // user action, not just passively entering the foreground again
                    [self hideLoadingFrame: ^{
                        [self switchToHostView];
                            [[self activeViewController] presentViewController:applistAlert animated:YES completion:nil];
                    }];

                    host.state = StateOffline;
                    [self hostCardContentsDidChange:host];
                });
            } else {
                // Update the host object with this data
                [serverInfoResp populateHost:host];
                [self hostCardContentsDidChange:host];
                // Only pair when this was the result of explicit user action
                    Log(LOG_I, @"Trying to pairTrying to pair");
                    // Polling the server while pairing causes the server to screw up
                    [self->_discMan stopDiscoveryBlocking];
                    PairManager* pMan = [[PairManager alloc] initWithManager:hMan clientCert:self->_clientCert callback:self];
                    [self->_opQueue addOperation:pMan];

            }
        });
    }];
}


- (void) noneUserInitiatedHostAction:(TemporaryHost *)host view:(UIView *)view {
    NSLog(@"Clicked host: %@", host.name);
    _selectedHost = host;
    //_appManager = [[AppAssetManager alloc] initWithCallback:self];
    [self.collectionView setCollectionViewLayout:self.collectionViewLayout];
    [self.collectionView reloadData]; //for new scroll host view reloading mechanism
    [self.view addSubview:self.collectionView]; //for new scroll host view reloading mechanism
    [self constrainIPhoneAppViewToSafeArea];
    [self refreshAppNavigationHighlight];
    
    // 若未在线或未配对, 有以下:
    
    [self showLoadingFrame: ^{
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            // Wait for the PC's status to be known
            while (host.state == StateUnknown) {
                sleep(1);
            }
            
            // Don't bother polling if the server is already offline
            if (host.state == StateOffline) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self hideLoadingFrame:^{
                        [self switchToHostView];
                    }];
                });
                return;
            }
            
            HttpManager* hMan = [[HttpManager alloc] initWithHost:host];
            ServerInfoResponse* serverInfoResp = [[ServerInfoResponse alloc] init];
            
            // Exempt this host from discovery while handling the serverinfo request
            [self->_discMan pauseDiscoveryForHost:host];
            [hMan executeRequestSynchronously:[HttpRequest requestForResponse:serverInfoResp withUrlRequest:[hMan newServerInfoRequest:false]
                                                                fallbackError:401 fallbackRequest:[hMan newHttpServerInfoRequest]]];
            [self->_discMan resumeDiscoveryForHost:host];
            
            if (![serverInfoResp isStatusOk]) {
                Log(LOG_W, @"Failed to get server info: %@", serverInfoResp.statusMessage);
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (host != self->_selectedHost) {
                        [self hideLoadingFrame:nil];
                        return;
                    }
                    
                    UIAlertController* applistAlert = [UIAlertController alertControllerWithTitle:[LocalizationHelper localizedStringForKey:@"Connection Failed"]
                                                                                          message:serverInfoResp.statusMessage
                                                                                   preferredStyle:UIAlertControllerStyleAlert];
                    [Utils addHelpOptionToDialog:applistAlert];
                    [applistAlert addAction:[UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Ok"] style:UIAlertActionStyleDefault handler:nil]];
                    
                    // Only display an alert if this was the result of a real
                    // user action, not just passively entering the foreground again
                    [self hideLoadingFrame: ^{
                        [self switchToHostView];
                    }];
                    host.state = StateOffline;
                    [self hostCardContentsDidChange:host];
                });
            } else {
                // Update the host object with this data
                [serverInfoResp populateHost:host];
                [self hostCardContentsDidChange:host];
                if (host.pairState == PairStatePaired) {
                    Log(LOG_I, @"Already Paired");
                    [self alreadyPaired];
                }
                else if (view == nil) {
                    // Not user action, so just return to host screen
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self hideLoadingFrame:^{
                            [self switchToHostView];
                        }];
                    });
                }
            }
        });
    }];
}


- (UIViewController*) activeViewController {
    UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;
    
    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }
    
    return topController;
}

- (void)restoreTintColorForAllSubViews{
    for(UIView* view in self.view.subviews){  // iterates all on-screen widget views in StreamFrameView
        view.tintAdjustmentMode = UIViewTintAdjustmentModeNormal;
    }
}

- (void)hostCardLongPressed:(TemporaryHost *)host view:(UIView *)view {
    _selectedHost = host;
    Log(LOG_D, @"Long clicked host: %@", host.name);
    NSString* message;
    
    NSString* hostAddress = [Utils addressPortStringToAddress:host.activeAddress];
    
    switch (host.state) {
        case StateOffline:
            message = [LocalizationHelper localizedStringForKey:@"Offline\n%@", hostAddress ? hostAddress : @"Unknown address"];
            break;
            
        case StateOnline:
            if (host.pairState == PairStatePaired) {
                message = [LocalizationHelper localizedStringForKey:@"Online - Paired\n%@", hostAddress ? hostAddress : @"Unknown address"];
            }
            else {
                message = [LocalizationHelper localizedStringForKey:@"Online - Not Paired\n%@", hostAddress ? hostAddress : @"Unknown address"];
            }
            break;
            
        case StateUnknown:
            message = [LocalizationHelper localizedStringForKey:@"Connecting\n"];
            break;
            
        default:
            break;
    }
    
    UIAlertController* longClickAlert = [UIAlertController alertControllerWithTitle:host.name message:message preferredStyle:UIAlertControllerStyleActionSheet];

    if (host.state != StateOnline) {
        [longClickAlert addAction:[UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Wake PC"] style:UIAlertActionStyleDefault handler:^(UIAlertAction* action){
            UIAlertController* wolAlert = [UIAlertController alertControllerWithTitle:[LocalizationHelper localizedStringForKey:@"Wake-On-LAN"] message:@"" preferredStyle:UIAlertControllerStyleAlert];
            [wolAlert addAction:[UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Ok"] style:UIAlertActionStyleDefault handler:nil]];
            if (host.mac == nil || [host.mac isEqualToString:@"00:00:00:00:00:00"]) {
                wolAlert.message = [LocalizationHelper localizedStringForKey: @"Host MAC unknown, unable to send WOL Packet"];
            } else {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    [WakeOnLanManager wakeHost:host];
                });
                wolAlert.message = [LocalizationHelper localizedStringForKey:@"Successfully sent wake-up request. It may take a few moments for the PC to wake. If it never wakes up, ensure it's properly configured for Wake-on-LAN."];
            }
            [[self activeViewController] presentViewController:wolAlert animated:YES completion:nil];
        }]];
    }
    else if (host.pairState == PairStatePaired) {
        [longClickAlert addAction:[UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"View All Apps"] style:UIAlertActionStyleDefault handler:^(UIAlertAction* action){
            self->_showHiddenApps = YES;
            [self appButtonTappedForHost:host];
        }]];
        
#if !TARGET_OS_TV
      
#endif
    }
    /*[longClickAlert addAction:[UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Test Network"] style:UIAlertActionStyleDefault handler:^(UIAlertAction* action) {
        [self showLoadingFrame:^{
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                // Perform the network test on a GCD worker thread. It may take a while.
                unsigned int portTestResult = LiTestClientConnectivity([host.activeAddress UTF8String], 443, ML_PORT_FLAG_ALL);
                dispatch_sync(dispatch_get_main_queue(), ^{
                    [self hideLoadingFrame:^{
                        NSString* message;
                        
                        if (portTestResult == 0) {
                            message = [LocalizationHelper localizedStringForKey:@"NetTestOK"];
                        }
                        else if (portTestResult == ML_TEST_RESULT_INCONCLUSIVE) {
                            message = [LocalizationHelper localizedStringForKey:@"ML_TEST_RESULT_INCONCLUSIVE"];
                        }
                        else {
                            char blockedPorts[512];
                            LiStringifyPortFlags(portTestResult, "\n", blockedPorts, sizeof(blockedPorts));
                            message = [LocalizationHelper localizedStringForKey:@"NetTestFailed", blockedPorts];
                        }
                        
                        UIAlertController* netTestAlert = [UIAlertController alertControllerWithTitle:[LocalizationHelper localizedStringForKey:@"Network Test Complete"] message:message preferredStyle:UIAlertControllerStyleAlert];
                        [netTestAlert addAction:[UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Ok"] style:UIAlertActionStyleDefault handler:nil]];
                        [[self activeViewController] presentViewController:netTestAlert animated:YES completion:^{
                            [self restoreTintColorForAllSubViews];
                        }];
                    }];
                });
            });
        }];
    }]];*/
#if !TARGET_OS_TV
    /*
    if (host.state != StateOnline) {
        [longClickAlert addAction:[UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"NVIDIA GameStream End-of-Service"] style:UIAlertActionStyleDefault handler:^(UIAlertAction* action){
            [Utils launchUrl:@"https://github.com/moonlight-stream/moonlight-docs/wiki/NVIDIA-GameStream-End-Of-Service-Announcement-FAQ"];
        }]];
        [longClickAlert addAction:[UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Connection Help"] style:UIAlertActionStyleDefault handler:^(UIAlertAction* action){
            [Utils launchUrl:@"https://github.com/moonlight-stream/moonlight-docs/wiki/Troubleshooting"];
        }]];
    }*/
#endif
    if (host.pairState == PairStatePaired) {
        [DeeplinkCoordinator addLinkActionTo:longClickAlert presenter:self host:host appID:nil];
    }
    [longClickAlert addAction:[UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Remove Host"] style:UIAlertActionStyleDestructive handler:^(UIAlertAction* action) {   // host removed here
        [self->_discMan removeHostFromDiscovery:host];
        [self.hostCollectionVC removeHost:host];
        DataManager* dataMan = [[DataManager alloc] init];
        [dataMan removeHost:host];
        @synchronized(hostList) {
            [hostList removeObject:host];
            [self updateAllHosts:[hostList allObjects]];
        }
        
    }]];
    [longClickAlert addAction:[UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Cancel"] style:UIAlertActionStyleCancel handler:nil]];
    
    // these two lines are required for iPad support of UIAlertSheet
    longClickAlert.popoverPresentationController.sourceView = view;
    
    longClickAlert.popoverPresentationController.sourceRect = CGRectMake(view.bounds.size.width / 2.0, view.bounds.size.height / 2.0, 1.0, 1.0); // center of the view
    [[self activeViewController] presentViewController:longClickAlert animated:YES completion:nil];
}

- (void) addHostTapped {
    [self applyThemeToNavigationControls];
    Log(LOG_D, @"Tapped add host");
    GenericUtils.autoPopSoftKeyboard = !PublicUtils.isIPhone;
    UIAlertController* alertController = [UIAlertController alertControllerWithTitle:[LocalizationHelper localizedStringForKey:@"Add Host Manually"]
                                                                             message:[LocalizationHelper localizedStringForKey:PublicUtils.isTVOS ? @"tvOSManualIpTip" : @"Enter IP address to add host manually"]
                                                                      preferredStyle:UIAlertControllerStyleAlert];

    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = PublicUtils.isTVOS ? @"Enter host IP for VoidLink TV from iPhone/iPad" : @"192.168.0.100 or [2001:db8::1]";
        textField.keyboardType = UIKeyboardTypeASCIICapable;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
        textField.spellCheckingType = UITextSpellCheckingTypeNo;
        textField.delegate = self;
        if(PublicUtils.isTVOS){
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [textField becomeFirstResponder];
            });
        }
    }];

    [alertController addAction:[UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Cancel"]
                                                        style:UIAlertActionStyleCancel
                                                      handler:nil]];

    [alertController addAction:[UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Ok"]
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction* action) {
        UITextField *textField = alertController.textFields.firstObject;
        NSString *hostAddress = [textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

        [self showLoadingFrame:^{
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                [self->_discMan discoverHost:hostAddress withCallback:^(TemporaryHost* host, NSString* error){
                    if (host != nil) {
                        [alertController dismissViewControllerAnimated:false completion:^{
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self hideLoadingFrame:^{
                                    @synchronized(hostList) {
                                        [hostList addObject:host];
                                    }
                                    [self updateHosts];
                                }];
                            });
                        }];
                    } else {
                        unsigned int portTestResults = LiTestClientConnectivity([host.activeAddress UTF8String], 443,
                                                                                ML_PORT_FLAG_TCP_47984 | ML_PORT_FLAG_TCP_47989);
                        if (portTestResults != ML_TEST_RESULT_INCONCLUSIVE && portTestResults != 0) {
                            error = [error stringByAppendingString:[LocalizationHelper localizedStringForKey:@"!ML_TEST_RESULT_INCONCLUSIVE"]];
                        }
                        
                        UIAlertController* hostNotFoundAlert = [UIAlertController alertControllerWithTitle:[LocalizationHelper localizedStringForKey:@"Add Host Manually"] message:error preferredStyle:UIAlertControllerStyleAlert];
                        [Utils addHelpOptionToDialog:hostNotFoundAlert];
                        [hostNotFoundAlert addAction:[UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Ok"] style:UIAlertActionStyleDefault handler:nil]];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [alertController dismissViewControllerAnimated:true completion:^{
                                [self hideLoadingFrame:^{
                                    if([error isEqualToString:[LocalizationHelper localizedStringForKey:@"Host information updated"]]){
                                        DataManager* dataMan = [[DataManager alloc] init];
                                        [dataMan updateHost:host];
                                    }
                                    [self presentViewController:hostNotFoundAlert animated:YES completion:nil];
                                }];
                           }];
                        });
                    }
                }];
            });
        }];
    }]];
    [[self activeViewController] presentViewController:alertController animated:YES completion:nil];
}

- (void) prepareToStreamApp:(TemporaryApp *)app {
    
    self.navigationController.navigationBar.hidden = true;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.navigationController.navigationBar.hidden = false;
    });
    
    launchedApp = app;
    [self updateResolutionAccordingly];
    self.revealViewController.isStreaming = true; // tell the revealViewController streaming is started.
    _streamConfig = [[StreamConfiguration alloc] init];
    _streamConfig.host = app.host.activeAddress;
    _streamConfig.httpsPort = app.host.httpsPort;
    _streamConfig.appID = app.id;
    _streamConfig.appName = app.name;
    _streamConfig.serverCert = app.host.serverCert;
    _streamConfig.serverCodecModeSupport = app.host.serverCodecModeSupport;
    [self reloadStreamConfig];
}

- (void) reloadStreamConfig {
    DataManager* dataMan = [[DataManager alloc] init];
    TemporarySettings* streamSettings = [dataMan getSettings];
    [VideoDecoderRenderer setFrameInterpolationEnabled: streamSettings.framePacingMode.intValue == FramePacingModeInterpolation];
    _streamConfig.frameRate = [streamSettings.framerate intValue];
    if (@available(iOS 10.3, *)) {
        UIWindow *window = UIApplication.sharedApplication.windows.firstObject;
        NSInteger maximumFramesPerSecond = window.screen.maximumFramesPerSecond;
        if(UIScreen.screens.count > 1 && streamSettings.externalDisplayMode.intValue == 1){ //AirPlaying
            maximumFramesPerSecond = UIScreen.screens.lastObject.maximumFramesPerSecond;
        }
        // Don't stream more FPS than the display can show
        if (_streamConfig.frameRate > maximumFramesPerSecond) {
            _streamConfig.frameRate = (int)maximumFramesPerSecond;
            Log(LOG_W, @"Clamping FPS to maximum refresh rate: %d", _streamConfig.frameRate);
        }
    }
    
    _streamConfig.height = streamSettings.height.intValue;
    _streamConfig.width = streamSettings.width.intValue;
    
    NSLog(@"saveSettings.width %d, %d", _streamConfig.width, _streamConfig.height);
#if TARGET_OS_TV
    // Don't allow streaming 4K on the Apple TV HD
    struct utsname systemInfo;
    uname(&systemInfo);
    if (strcmp(systemInfo.machine, "AppleTV5,3") == 0 && _streamConfig.height >= 2160) {
        Log(LOG_W, @"4K streaming not supported on Apple TV HD");
        _streamConfig.width = 1920;
        _streamConfig.height = 1080;
    }
#endif
    
    _streamConfig.bitRate = [streamSettings.bitrate intValue];
    _streamConfig.optimizeGameSettings = streamSettings.optimizeGames;
    _streamConfig.playAudioOnPC = streamSettings.playAudioOnPC;
    _streamConfig.redirectMic = streamSettings.redirectMic;
    _streamConfig.localVolume = streamSettings.localVolume.floatValue;
    _streamConfig.swapABXYButtons = streamSettings.swapABXYButtons;
    _streamConfig.buttonVisualFeedback = streamSettings.buttonVisualFeedback;
    _streamConfig.enableYUV444 = streamSettings.enableYUV444;
    _streamConfig.enablePIP = streamSettings.enablePIP;
    _streamConfig.fullColorRange = streamSettings.fullColorRange;
    _streamConfig.enableHdr = streamSettings.enableHdr;
    _streamConfig.sdrPerformanceWorkaround = streamSettings.sdrPerformanceWorkaround;
    _streamConfig.asyncNativeTouchPriority = streamSettings.asyncNativeTouchPriority; // new streamConfig segment
    _streamConfig.gyroMode = [streamSettings.gyroMode intValue];
    _streamConfig.emulatedControllerType = streamSettings.emulatedControllerType.intValue;
    _streamConfig.hapticEngine = streamSettings.hapticEngine.intValue;
    //NSLog(@"gyroMode from settings: %ld", _streamConfig.gyroMode);
    
    // multiController must be set before calling getConnectedGamepadMask
    _streamConfig.multiController = streamSettings.multiController;
    _streamConfig.gamepadMask = [ControllerSupport getConnectedGamepadMask:_streamConfig];
    _streamConfig.localMousePointerMode = streamSettings.localMousePointerMode.intValue;
    
    // Probe for supported channel configurations
    int physicalOutputChannels = (int)[AVAudioSession sharedInstance].maximumOutputNumberOfChannels;
    Log(LOG_I, @"Audio device supports %d channels", physicalOutputChannels);
    if (@available(iOS 18.0, tvOS 18.0, *)) {
        physicalOutputChannels = 8;
        Log(LOG_I, @"System-provided spatial audio available, pretending device has %d channels", physicalOutputChannels);
    }

    int numberOfChannels = MIN([streamSettings.audioConfig intValue], physicalOutputChannels);
    
    Log(LOG_I, @"Selected number of audio channels %d", numberOfChannels);
    if (numberOfChannels >= AudioConfigSDL71) {
        _streamConfig.audioConfiguration = AUDIO_CONFIGURATION_71_SURROUND;
    }
    else if (numberOfChannels >= AudioConfigSDL51) {
        _streamConfig.audioConfiguration = AUDIO_CONFIGURATION_51_SURROUND;
    }
    else {
        _streamConfig.audioConfiguration = AUDIO_CONFIGURATION_STEREO;
    }
    
    Connection.useSystemAudioEngine = streamSettings.audioConfig.intValue == AudioConfigStereo;
    
    bool sdrPerformanceWorkaround = false;
    switch (streamSettings.preferredCodec) {
        case TemporarySettingsCodecPreferenceAv1:
#if defined(__IPHONE_16_0) || defined(__TVOS_16_0)
            if (VTIsHardwareDecodeSupported(kCMVideoCodecType_AV1)) {
                _streamConfig.fullColorRange = false;
                if (streamSettings.enableYUV444) {
                    _streamConfig.supportedVideoFormats |= VIDEO_FORMAT_AV1_HIGH8_444;
                }
                else {
                    if(sdrPerformanceWorkaround && [Utils hdrSupported]) _streamConfig.supportedVideoFormats |= VIDEO_FORMAT_AV1_MAIN10; // 8bit performance degradation workaround for av1
                    else _streamConfig.supportedVideoFormats |= VIDEO_FORMAT_AV1_MAIN8;
                }
            }
#endif
            // Fall-through
            
        case TemporarySettingsCodecPreferenceAuto:
        case TemporarySettingsCodecPreferenceHevc:
            if (VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC)) {
                if (streamSettings.enableYUV444) {
                    if(sdrPerformanceWorkaround && [Utils hdrSupported]) _streamConfig.supportedVideoFormats |= VIDEO_FORMAT_H265_REXT10_444; // 8bit performance degradation workaround
                    else _streamConfig.supportedVideoFormats |= VIDEO_FORMAT_H265_REXT8_444;
                }
                else {
                    // _streamConfig.supportedVideoFormats |= VIDEO_FORMAT_H265;
                    if(sdrPerformanceWorkaround && [Utils hdrSupported]) _streamConfig.supportedVideoFormats |= VIDEO_FORMAT_H265_MAIN10; // 8bit performance degradation workaround
                    else _streamConfig.supportedVideoFormats |= VIDEO_FORMAT_H265;
                }
            }
            // Fall-through
            
        case TemporarySettingsCodecPreferenceH264:
            if (streamSettings.enableYUV444) {
                _streamConfig.supportedVideoFormats |= VIDEO_FORMAT_H264_HIGH8_444;
            } else {
                _streamConfig.supportedVideoFormats |= VIDEO_FORMAT_H264;
            }
            break;
    }
    
    // HEVC is supported if the user wants it (or it's required by the chosen resolution) and the SoC supports it
    if ((_streamConfig.width > 4096 || _streamConfig.height > 4096 || streamSettings.enableHdr) && VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC)) {
        
        if(sdrPerformanceWorkaround && [Utils hdrSupported]) _streamConfig.supportedVideoFormats |= VIDEO_FORMAT_H265_MAIN10; // 8bit performance degradation workaround
        else _streamConfig.supportedVideoFormats |= VIDEO_FORMAT_H265;

        // HEVC Main10 is supported if the user wants it and the display supports it
        if (streamSettings.enableHdr && (AVPlayer.availableHDRModes & AVPlayerHDRModeHDR10) != 0) {
            if (streamSettings.enableYUV444) {
                _streamConfig.supportedVideoFormats |= VIDEO_FORMAT_H265_REXT10_444;
            }
            else {
                _streamConfig.supportedVideoFormats |= VIDEO_FORMAT_H265_MAIN10;
            }
        }
    }
    
#if defined(__IPHONE_16_0) || defined(__TVOS_16_0)
    // Add the AV1 Main10 format if AV1 and HDR are both enabled and supported
    if ((_streamConfig.supportedVideoFormats & VIDEO_FORMAT_MASK_AV1) && streamSettings.enableHdr &&
        VTIsHardwareDecodeSupported(kCMVideoCodecType_AV1) && (AVPlayer.availableHDRModes & AVPlayerHDRModeHDR10) != 0) {
        if (streamSettings.enableYUV444) {
            _streamConfig.supportedVideoFormats |= VIDEO_FORMAT_AV1_HIGH10_444;
        } else {
            _streamConfig.supportedVideoFormats |= VIDEO_FORMAT_AV1_MAIN10;
        }
    }
#endif
}

- (NSInteger)requestForBitrate:(NSInteger)bitrateKbps{
    HttpManager* hMan = [[HttpManager alloc] initWithHost:launchedApp.host];
    HttpResponse* bitrateResponse = [[HttpResponse alloc] init];
    HttpRequest* bitrateRequest = [HttpRequest requestForResponse: bitrateResponse withUrlRequest:[hMan newBirateRequest:bitrateKbps forClient:@"unknown"]];
    [hMan executeRequestSynchronously:bitrateRequest];
    NSLog(@"bitrate request status code: %ld", (long)bitrateResponse.statusCode);
    return bitrateResponse.statusCode;
}

- (HttpResponse* )requestToQuitApp:(TemporaryApp* )app{
    HttpManager* hMan = [[HttpManager alloc] initWithHost:app.host];
    HttpResponse* quitResponse = [[HttpResponse alloc] init];
    HttpRequest* quitRequest = [HttpRequest requestForResponse: quitResponse withUrlRequest:[hMan newQuitAppRequest]];

    // Exempt this host from discovery while handling the quit operation
    [self->_discMan pauseDiscoveryForHost:app.host];
    [hMan executeRequestSynchronously:quitRequest];
    if (quitResponse.statusCode == 200 && [[[quitResponse getStringTag:@"cancel"] trim] isEqualToString:@"0"]) {
        quitResponse.statusCode = 599;
    }
    if (quitResponse.statusCode == 200) {
        // /cancel acknowledges the request before Sunshine finishes shutting down.
        const dispatch_time_t deadline = dispatch_time(DISPATCH_TIME_NOW, 12 * NSEC_PER_SEC);
        const NSTimeInterval end = NSProcessInfo.processInfo.systemUptime + 12;
        BOOL fastFail = NO;
        for (;;) {
            ServerInfoResponse *info = [[ServerInfoResponse alloc] init];
            HttpRequest *request = [HttpRequest requestForResponse:info
                                                  withUrlRequest:[hMan newServerInfoRequest:fastFail]
                                                   fallbackError:401 fallbackRequest:[hMan newHttpServerInfoRequest:fastFail]];
            [hMan executeRequestSynchronously:request deadline:deadline];
            NSString *state = [[info getStringTag:@"state"] trim];
            if ([info isStatusOk] && state.length > @"_SERVER_FREE".length && [state hasSuffix:@"_SERVER_FREE"]) {
                [info populateHost:app.host];
                [self hostCardContentsDidChange:app.host];
                break;
            }
            BOOL sunshineBusy = [info isStatusOk] && [state isEqualToString:@"SUNSHINE_SERVER_BUSY"];
            if (([info isStatusOk] && [state hasSuffix:@"_SERVER_BUSY"] && !sunshineBusy) ||
                (info.statusCode >= 400 && info.statusCode < 500) ||
                (!sunshineBusy && app.host.isNvidiaServerSoftware)) {
                quitResponse.statusCode = [info isStatusOk] ? 599 : info.statusCode;
                quitResponse.statusMessage = info.statusMessage;
                break;
            }
            if (NSProcessInfo.processInfo.systemUptime + 1 >= end) {
                quitResponse.statusCode = NSURLErrorTimedOut;
                quitResponse.statusMessage = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil].localizedDescription;
                break;
            }
            [NSThread sleepForTimeInterval:1];
            fastFail = YES;
        }
    }
    [self->_discMan resumeDiscoveryForHost:app.host];
    return quitResponse;
}

- (void)quitApp:(TemporaryApp *)app {
    if (!app || ![PublicUtils hasNoPresentedVC:self]) return;
    [self quitApp:app completion:^(BOOL success) {}];
}

- (void)quitApp:(TemporaryApp *)app completion:(void (^)(BOOL))completion {
    if (!app) { completion(NO); return; }
    [self showLoadingFrame:^{
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            HttpResponse *response = [self requestToQuitApp:app];
            dispatch_async(dispatch_get_main_queue(), ^{
                BOOL success = response.statusCode == 200;
                [self hideLoadingFrame:^{
                    if (!success) {
                        [self updateAppsForHost:app.host];
                        NSString *message = response.statusCode == NSURLErrorTimedOut ? response.statusMessage :
                            [LocalizationHelper localizedStringForKey:@"Failed to quit app. If this app was started by another device, you'll need to quit from that device."];
                        UIAlertController *alert = [UIAlertController alertControllerWithTitle:[LocalizationHelper localizedStringForKey:@"Quitting App Failed"] message:message preferredStyle:UIAlertControllerStyleAlert];
                        [alert addAction:[UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Ok"] style:UIAlertActionStyleDefault handler:nil]];
                        [[self activeViewController] presentViewController:alert animated:YES completion:nil];
                    }
                    completion(success);
                }];
            });
        });
    }];
}

- (void)quitLaunchedApp {
    [self quitApp:launchedApp];
}

- (void)quitRunningAppAndStart:(TemporaryApp *)app {
    TemporaryApp *current = [self findRunningApp:app.host];
    [self quitApp:app completion:^(BOOL success) {
        if (success && ![app.id isEqualToString:current.id]) [self launchApp:app];
    }];
}

- (void)launchApp:(TemporaryApp *)app {
    if(self.revealViewController.isStreaming) return;
    [self prepareToStreamApp:app];
    [self performSegueWithIdentifier:@"createStreamFrame" sender:nil];
}

- (void)appLongClicked:(TemporaryApp *)app view:(UIView *)view {
    Log(LOG_D, @"Long clicked app: %@", app.name);
    
    [_appManager stopRetrieving];
    
#if !TARGET_OS_TV
    if (currentPosition != FrontViewPositionLeft) {
        // This must not be animated because we need the position
        // to change (and notify our callback to save settings data)
        // before we call prepareToStreamApp.
        [[self revealViewController] revealToggleAnimated:NO];
    }
#endif

    TemporaryApp* currentApp = [self findRunningApp:app.host];
    
    NSString* message;
    
    if (currentApp == nil || [app.id isEqualToString:currentApp.id]) {
        if (app.hidden) {
            message = @"Hidden";
        }
        else {
            message = @"";
        }
    }
    else {
        message = [LocalizationHelper localizedStringForKey:@"%@ is currently running", currentApp.name];
    }
    
    UIAlertController* alertController = [UIAlertController
                                          alertControllerWithTitle: app.name
                                          message:message
                                          preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alertController addAction:[UIAlertAction
                                actionWithTitle:currentApp == nil ? [LocalizationHelper localizedStringForKey:@"Launch App"] : ([app.id isEqualToString:currentApp.id] ? [LocalizationHelper localizedStringForKey: @"Resume App"] : [LocalizationHelper localizedStringForKey: @"Resume Running App"]) style:UIAlertActionStyleDefault handler:^(UIAlertAction* action){
        if (currentApp != nil) {
            Log(LOG_I, @"Resuming application: %@", currentApp.name);
            [self prepareToStreamApp:currentApp];
        }
        else {
            Log(LOG_I, @"Launching application: %@", app.name);
            [self prepareToStreamApp:app];
        }

        [self performSegueWithIdentifier:@"createStreamFrame" sender:nil];
    }]];
    
    if (currentApp != nil) {
        [alertController addAction:[UIAlertAction actionWithTitle:
                                    [app.id isEqualToString:currentApp.id] ? [LocalizationHelper localizedStringForKey:@"Quit App"] : [LocalizationHelper localizedStringForKey:@"Quit Running App and Start"] style:UIAlertActionStyleDestructive handler:^(UIAlertAction* action){
                                        Log(LOG_I, @"Quitting application: %@", currentApp.name);
                                        [self quitRunningAppAndStart:app];
                                    }]];
    }

    if (app.host && app.id.length > 0) {
        [DeeplinkCoordinator addLinkActionTo:alertController presenter:self host:app.host appID:app.id];
    }

    if (currentApp == nil || ![app.id isEqualToString:currentApp.id] || app.hidden) {
        [alertController addAction:[UIAlertAction actionWithTitle:app.hidden ? [LocalizationHelper localizedStringForKey: @"Show App"] : [LocalizationHelper localizedStringForKey: @"Hide App"]
                                                            style:app.hidden ? UIAlertActionStyleDefault : UIAlertActionStyleDestructive
                                                          handler:^(UIAlertAction* action) {
            app.hidden = !app.hidden;
            [self updateAppEntry:app forHost:app.host];
            
            // Don't call updateAppsForHost because that will nuke this
            // app immediately if we're not showing hidden apps.
        }]];
    }
    
    [alertController addAction:[UIAlertAction actionWithTitle:[LocalizationHelper localizedStringForKey:@"Cancel"] style:UIAlertActionStyleCancel handler:nil]];

    // these two lines are required for iPad support of UIAlertSheet
    alertController.popoverPresentationController.sourceView = view;
    
    alertController.popoverPresentationController.sourceRect = CGRectMake(view.bounds.size.width / 2.0, view.bounds.size.height / 2.0, 1.0, 1.0); // center of the view
    [[self activeViewController] presentViewController:alertController animated:YES completion:nil];
}

- (void) appClicked:(TemporaryApp *)app view:(UIView *)view {
    Log(LOG_D, @"Clicked app: %@", app.name);
    
    [_appManager stopRetrieving];
    
#if !TARGET_OS_TV
    if (currentPosition != FrontViewPositionLeft) {
        // This must not be animated because we need the position
        // to change (and notify our callback to save settings data)
        // before we call prepareToStreamApp.
        [[self revealViewController] revealToggleAnimated:NO];
    }
#endif
    
    if ([self findRunningApp:app.host]) {
        // If there's a running app, display a menu
        [self appLongClicked:app view:view];
    } else {
        [self prepareToStreamApp:app];
        [self performSegueWithIdentifier:@"createStreamFrame" sender:nil];
    }
}

- (TemporaryApp*) findRunningApp:(TemporaryHost*)host {
    for (TemporaryApp* app in host.appList) {
        if ([app.id isEqualToString:host.currentGame]) {
            return app;
        }
    }
    return nil;
}


- (void)expandSettingsView { //simulate pressing the setting button, called from setting view controller.
    if (currentPosition == FrontViewPositionLeft) {
        [[self revealViewController] revealToggleAnimated:YES];
    }
}

- (void)closeSettingViewAnimated:(BOOL)anaimated { //simulate pressing the setting button, called from setting view controller.
    if (currentPosition != FrontViewPositionLeft) {
        [[self revealViewController] revealToggleAnimated:anaimated];
    }
}

- (void)openGameProfileSeletorWithAnimated:(bool)animated {
    if(self.settingsViewController){
        [self.settingsViewController mainFrameGameProfileButtonTapped:animated];
        return;
    }

#if TARGET_OS_TV
    ProfileSelectorViewController *profileSelectorVC = [[ProfileSelectorViewController alloc] init];
    profileSelectorVC.loadingMode = ProfileSelectorLoadingModeSelectProfileFromMainFrame;
    profileSelectorVC.modalPresentationStyle = UIModalPresentationOverCurrentContext;
    self.gameProfileSelectorVC = profileSelectorVC;
    [self presentViewController:profileSelectorVC animated:animated completion:nil];
    
#else
    
    LayoutOnScreenControlsViewController* layoutToolVC;
    BOOL isIPhone = ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone);
    if (isIPhone) {
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"iPhone" bundle:nil];
        layoutToolVC = [storyboard instantiateViewControllerWithIdentifier:@"LayoutOnScreenControlsViewController"];
    }
    else {
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"iPad" bundle:nil];
        layoutToolVC = [storyboard instantiateViewControllerWithIdentifier:@"LayoutOnScreenControlsViewController"];
        layoutToolVC.modalPresentationStyle = UIModalPresentationFullScreen;
    }
    layoutToolVC.view.backgroundColor = UIColor.clearColor;
    layoutToolVC.modalPresentationStyle = UIModalPresentationOverCurrentContext;
    
    
    layoutToolVC.profileSelectorLoadingMode = ProfileSelectorLoadingModeSelectProfileFromMainFrame;
    layoutToolVC.toolbarStackView.hidden = true;
    layoutToolVC.toolbarRootView.hidden = true;
    
    self.gameProfileSelectorVC = layoutToolVC;
    [self presentViewController:layoutToolVC animated:false completion:^{
        [layoutToolVC presentProfileSelectorWith:ProfileSelectorLoadingModeSelectProfileFromMainFrame animated:animated];
    }];
#endif
}

#if !TARGET_OS_TV
- (void)profilesButtonTapped {
    if([GenericUtils isFirstTappingGameProfileSelectorFromMainFrame]){
        
        DataManager* dataMan = [[DataManager alloc] init];
        Settings* settings = [dataMan retrieveSettings];

        
        NSString* edgeSide = settings.slideToSettingsScreenEdge.intValue != UIRectEdgeLeft ? [LocalizationHelper localizedStringForKey:@"left"] : [LocalizationHelper localizedStringForKey:@"right"];
        NSString* slideDist = [NSString stringWithFormat:@"%d%%", (int)(settings.slideToSettingsDistance.floatValue*100)];

        [AlertControllerUtil showAlertIn:self
                                        title:[LocalizationHelper localizedStringForKey:@"Game Profile"]
                                      message:[LocalizationHelper localizedStringForKey:@"gameProfileIntroduction", edgeSide, slideDist]
                                   withCancel:NO
                                  buttonTitle:[LocalizationHelper localizedStringForKey:@"Got it!"]
                                    countdown:6
                                       action:^{}
                                   completion:^{
            [self openGameProfileSeletorWithAnimated:false];
        }];
    }
    else [self openGameProfileSeletorWithAnimated:false];
}

#endif

// currently obselete:
- (void) setNeedsUpdateAllowedOrientation{
    if (@available(iOS 16.0, *)) {
        [self setNeedsUpdateOfSupportedInterfaceOrientations];
    } else {
        // Fallback on earlier versions
    }
}

- (void)revealController:(SWRevealViewController *)revealController willMoveToPosition:(FrontViewPosition)position {
    self.settingsViewController = (SettingsViewController*)[revealController rearViewController];
    revealController.navBarMenuDelegate = self.settingsViewController;
    
    _settingsViewExpanded = position != FrontViewPositionLeft;
    if (position == FrontViewPositionLeft) {
        if (@available(iOS 13.0, *)){
            self.settingsExpandedInStreamView = false;
            if(!self.revealViewController.isStreaming) [ControllerNavigator setUINavigationDelegate: self.isInAppView ? self : self.hostCollectionVC];
            else [ControllerNavigator setUINavigationDelegate: [StreamFrameViewController sharedInstance]];
        }
#if !TARGET_OS_TV
        if (@available(iOS 26.0, *)) {
            _settingsButton.sharesBackground = false;
            _profilesButton.sharesBackground = false;
        }
#endif
        self.navigationItem.leftBarButtonItems = PublicUtils.isTVOS
        ? VLBarButtonItems(_settingsButton, nil)
        : VLBarButtonItems(_settingsButton, _profilesButton);

        if(streamFrameViewController.streamMan){
            // NSLog(@"setNeedRequeuing %f", CACurrentMediaTime());
            double delayInSeconds = 0.1;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^{
                [self->streamFrameViewController.streamMan setNeedRequeuing:true];
            });
        }
    }
    else {
#if TARGET_OS_TV
        [self.settingsViewController consumeTvOSInitialSettingsSnapshotForMenuPresentation];
#endif
        if(self.revealViewController.isStreaming) self.settingsExpandedInStreamView = true; //notify mainFrameViewContorller that this is a setting expansion in stream view, some settings shall be disabled.
        if (@available(iOS 13.0, *)) [ControllerNavigator setUINavigationDelegate:self.settingsViewController];
        self.navigationItem.leftBarButtonItems = PublicUtils.isTVOS
        ? VLBarButtonItems(nil, nil)
        : VLBarButtonItems(_profilesButton, nil);
        [self.settingsViewController updateTheme];
    }

    self.settingsViewController.mainFrameViewController = self;
    // enable / disable widgets acoordingly: in streamview, disable, outside of streamview, enable.
    if(self.settingsExpandedInStreamView) [revealController buttonsInStreaming];
    else [revealController buttonsNotInStreaming];
    
    // DataManager* dataMan = [[DataManager alloc] init];
    // TemporarySettings* currentSettings = [dataMan getSettings];

    [streamFrameViewController setUserInteractionEnabledForStreamView:!_settingsExpandedInStreamView || position == FrontViewPositionLeft];
    if (@available(iOS 14.0, *)) {
        if (self.settingsViewController.usesSwiftUISettings) {
            [self.settingsViewController updateSwiftUISettingsStreamingState:revealController.isStreaming
                                                               menuIsOpening:position != FrontViewPositionLeft];
            if (position != FrontViewPositionLeft && ControllerUtil.primaryGCController) {
                [ControllerNavigator restoreUINavigationHighlight];
            }
            return;
        }
    }
}

- (void)revealController:(SWRevealViewController *)revealController didMoveToPosition:(FrontViewPosition)position {
        // If we moved back to the center position, we should save the settings
    self.settingsViewController = (SettingsViewController*)[revealController rearViewController];
    self.settingsViewController.mainFrameViewController = self;

    if (position == FrontViewPositionLeft) {
        if (@available(iOS 13.0, *)) [ControllerNavigator persistUINavigationHighlight];
        [self.settingsViewController saveSettings];
        _settingsButton.enabled = YES; // make sure these 2 buttons are enabled after closing setting view.
        _upButton.enabled = YES; // here is the select new host button
    }
    
    currentPosition = position;
}
// #endif

#if TARGET_OS_TV
- (void)profilesButtonTapped {
    [self openGameProfileSeletorWithAnimated:true];
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    [self appClicked:self.sortedAppList[indexPath.row] view:nil];
}
#endif

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.destinationViewController isKindOfClass:[StreamFrameViewController class]]) {
        streamFrameViewController = segue.destinationViewController;
        streamFrameViewController.mainFrameViewcontroller = self;
        streamFrameViewController.streamConfig = _streamConfig;
    }
    NSLog(@"streamVC seque... %lu %f",(uintptr_t)streamFrameViewController , CACurrentMediaTime());
}

- (void) showLoadingFrame:(void (^)(void))completion {
    [_loadingFrame showLoadingFrame:completion];
}

- (void) hideLoadingFrame:(void (^)(void))completion {
    [self enableNavigation];
    [_loadingFrame dismissLoadingFrame:completion];
}

- (void)adjustScrollViewForSafeArea:(UIScrollView*)view {
    if (@available(iOS 11.0, *)) {
        BOOL needsHorizontalInset = self.view.safeAreaInsets.left >= 20 || self.view.safeAreaInsets.right >= 20;
#if !TARGET_OS_TV
        if ((PublicUtils.isIPhone && !PublicUtils.isFoldableIPhone) ||
            UIInterfaceOrientationIsPortrait([self appViewInterfaceOrientation])) {
            // Make the compact portrait layout explicit, including on first entry.
            needsHorizontalInset = YES;
        }
#endif
        UIEdgeInsets insets = view.contentInset;
        insets.left = insets.right = needsHorizontalInset ? 20 : 0;
        if (!UIEdgeInsetsEqualToEdgeInsets(view.contentInset, insets)) {
            view.contentInset = insets;
        }
    }
}

#if !TARGET_OS_TV
- (UIInterfaceOrientation)appViewInterfaceOrientation {
    if (@available(iOS 26.0, *)) {
        return self.view.window.windowScene.effectiveGeometry.interfaceOrientation;
    } else if (@available(iOS 13.0, *)) {
        return self.view.window.windowScene.interfaceOrientation;
    } else {
        return UIApplication.sharedApplication.statusBarOrientation;
    }
}
#endif

- (void)constrainIPhoneAppViewToSafeArea {
    /*
    if(!PublicUtils.isIPhone) {
        [self logAppCollectionLayout:@"skip-not-iphone"];
        return;
    }
    if (self.collectionView == self.view || self.collectionView.superview != self.view) {
        [self logAppCollectionLayout:@"skip-hierarchy"];
        return;
    } */
    CGFloat horizontalInset = 0;
    if (!PublicUtils.isFoldableIPhone) {
#if !TARGET_OS_TV
        UIInterfaceOrientation orientation = [self appViewInterfaceOrientation];
        if (PublicUtils.isIPhone && UIInterfaceOrientationIsPortrait(orientation)) {
            horizontalInset = [self appCollectionCellSize].width / 4.6;
        } else
#endif
        {
            // Ordinary iPhones return to their original full-width layout in landscape.
            if (_appCollectionSafeAreaConstraints.count > 0) {
                [NSLayoutConstraint deactivateConstraints:_appCollectionSafeAreaConstraints];
                _appCollectionSafeAreaConstraints = nil;
                self.collectionView.translatesAutoresizingMaskIntoConstraints = _appCollectionOriginalTranslatesAutoresizingMask;
                self.collectionView.autoresizingMask = _appCollectionOriginalAutoresizingMask;
                self.collectionView.frame = self.view.bounds;
            }
            // [self logAppCollectionLayout:@"skip-nonportrait"];
            return;
        }
    }
    // Removing the collection view on re-entry also removes its parent constraints.
    // Reuse them while attached, and recreate them after the next mounting.
    if (_appCollectionSafeAreaConstraints.count > 0 && _appCollectionSafeAreaConstraints.firstObject.active) {
        if (_appCollectionSafeAreaConstraints[0].constant != horizontalInset) {
            _appCollectionSafeAreaConstraints[0].constant = horizontalInset;
        }
        if (_appCollectionSafeAreaConstraints[1].constant != -horizontalInset) {
            _appCollectionSafeAreaConstraints[1].constant = -horizontalInset;
        }
        // [self logAppCollectionLayout:@"constraints-updated"];
        return;
    }
    if (_appCollectionSafeAreaConstraints.count == 0) {
        _appCollectionOriginalAutoresizingMask = self.collectionView.autoresizingMask;
        _appCollectionOriginalTranslatesAutoresizingMask = self.collectionView.translatesAutoresizingMaskIntoConstraints;
    }
    [NSLayoutConstraint deactivateConstraints:_appCollectionSafeAreaConstraints ?: @[]];
    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    _appCollectionSafeAreaConstraints = @[
        [self.collectionView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:horizontalInset],
        [self.collectionView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-horizontalInset],
        [self.collectionView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.collectionView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ];
    [NSLayoutConstraint activateConstraints:_appCollectionSafeAreaConstraints];
    // [self logAppCollectionLayout:@"constraints-created"];
}

/*
- (void)logAppCollectionLayout:(NSString *)phase {
#if DEBUG && !TARGET_OS_TV
    // On by default for this investigation. Disable with launch arguments:
    // -VLAppCollectionLayoutDiagnostics NO
    NSNumber *enabled = [NSUserDefaults.standardUserDefaults objectForKey:@"VLAppCollectionLayoutDiagnostics"];
    if (enabled != nil && !enabled.boolValue) { return; }
    UIWindow *window = self.viewIfLoaded.window;
    UIInterfaceOrientation orientation = UIInterfaceOrientationUnknown;
    UIInterfaceOrientation legacyOrientation = UIInterfaceOrientationUnknown;
    if (@available(iOS 13.0, *)) {
        legacyOrientation = window.windowScene.interfaceOrientation;
        orientation = legacyOrientation;
    }
    if (@available(iOS 26.0, *)) {
        orientation = window.windowScene.effectiveGeometry.interfaceOrientation;
    }
    NSUInteger activeConstraints = 0;
    for (NSLayoutConstraint *constraint in _appCollectionSafeAreaConstraints) {
        if (constraint.active) { activeConstraints++; }
    }
    UICollectionViewCell *visibleCell = self.collectionView.visibleCells.firstObject;
    NSString *state = [NSString stringWithFormat:
        @"iOS=%@ main=%d phone=%d fold=%d entered=%d hidden=%d orientation=%ld legacy=%ld "
         "view=%@ parent=%@ sameView=%d window=%@ viewBounds=%@ safe=%@ "
         "collectionFrame=%@ collectionBounds=%@ insets=%@ adjustedInsets=%@ "
         "constraints=%lu/%lu left=%.3f right=%.3f translates=%d ambiguous=%d "
         "apps=%lu expectedCardWidth=%.3f visibleCellFrame=%@",
        UIDevice.currentDevice.systemVersion, NSThread.isMainThread, PublicUtils.isIPhone,
        PublicUtils.isFoldableIPhone, _enteredAppView, self.collectionView.hidden,
        (long)orientation, (long)legacyOrientation,
        NSStringFromClass(self.view.class), NSStringFromClass(self.collectionView.superview.class),
        self.collectionView == self.view, NSStringFromCGRect(window.bounds),
        NSStringFromCGRect(self.view.bounds), NSStringFromCGRect(self.view.safeAreaLayoutGuide.layoutFrame),
        NSStringFromCGRect(self.collectionView.frame), NSStringFromCGRect(self.collectionView.bounds),
        NSStringFromUIEdgeInsets(self.collectionView.contentInset),
        NSStringFromUIEdgeInsets(self.collectionView.adjustedContentInset),
        (unsigned long)activeConstraints, (unsigned long)_appCollectionSafeAreaConstraints.count,
        _appCollectionSafeAreaConstraints.firstObject.constant,
        _appCollectionSafeAreaConstraints.count > 1 ? _appCollectionSafeAreaConstraints[1].constant : 0,
        self.collectionView.translatesAutoresizingMaskIntoConstraints, self.collectionView.hasAmbiguousLayout,
        (unsigned long)self.sortedAppList.count, [self appCollectionCellSize].width,
        NSStringFromCGRect(visibleCell.frame)];
    if ([_appCollectionLayoutDiagnosticStates[phase] isEqualToString:state]) { return; }
    if (_appCollectionLayoutDiagnosticStates == nil) {
        _appCollectionLayoutDiagnosticStates = [NSMutableDictionary dictionary];
    }
    _appCollectionLayoutDiagnosticStates[phase] = state;
    NSLog(@"[AppCollectionLayout] %@ %@", phase, state);
#endif
}
 */

- (void)refreshAppCollectionLayout {
    /*
    if (!PublicUtils.isIPhone || self.collectionView.superview != self.view) {
        [self logAppCollectionLayout:@"refresh-skipped"];
        return;
    } */
    [self constrainIPhoneAppViewToSafeArea];
    [self adjustScrollViewForSafeArea:self.collectionView];
    // Resolve the collection's new bounds before preparing its cell positions.
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
    [self.collectionView.collectionViewLayout invalidateLayout];
    [self.collectionView layoutIfNeeded];
    // [self logAppCollectionLayout:@"refresh-completed"];
}

// Adjust the subviews for the safe area on the iPhone X.
- (void)viewSafeAreaInsetsDidChange {
    [super viewSafeAreaInsetsDidChange];
    
    [self adjustScrollViewForSafeArea:self.collectionView];
}

- (void)waterMarkTapped {
    // Handle the tap action here, e.g., open a URL
    NSURL *url = [NSURL URLWithString:[LocalizationHelper localizedStringForKey:@"supportLink"]];
    if ([[UIApplication sharedApplication] canOpenURL:url]) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    }
}

- (BOOL)isFullScreenRequired {
    NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
    NSNumber *requiresFullScreen = infoDictionary[@"UIRequiresFullScreen"];
    
    if (requiresFullScreen != nil) {
        return [requiresFullScreen boolValue];
    }
    // Default behavior if the key is not set
    return YES;
}


- (void)attachWaterMark {
    // Create and configure the label
    if (@available(iOS 13.0, *)) return;
    else {
        [self->waterMark removeFromSuperview]; // removed before activate contraint
        self->waterMark = [[UILabel alloc] init];
        self->waterMark.translatesAutoresizingMaskIntoConstraints = NO;
        self->waterMark.numberOfLines = 1;
        self->waterMark.font = [UIFont systemFontOfSize:22];
        self->waterMark.text = [LocalizationHelper localizedStringForKey:@"waterMarkText"];
        CGFloat labelHeight = 60;
        // the app is unable to automatically lock screen orientation in app window resizable mode(aka. not require fullscreen)
        self->waterMark.textColor = UIColor.whiteColor;
        self->waterMark.alpha = 0.2;
        self->waterMark.textAlignment = NSTextAlignmentCenter;
        self->waterMark.backgroundColor = [UIColor clearColor];
        self->waterMark.userInteractionEnabled = YES; // Enable user interaction for tap gesture
        // Add tap gesture recognizer to handle hyperlink action
        UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(waterMarkTapped)];
        [self->waterMark addGestureRecognizer:tapGesture];
        // Add the label to the view hierarchy
        [self.view addSubview:self->waterMark];
        // Set up constraints
        [NSLayoutConstraint activateConstraints:@[
            [self->waterMark.centerXAnchor constraintEqualToAnchor:self.view.rightAnchor constant:-210], // Aligns the horizontal center of label to the horizontal center of view
            [self->waterMark.centerYAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-(labelHeight+10)], // Aligns the vertical center of label to the vertical center of view
            [self->waterMark.widthAnchor constraintEqualToConstant:500],                     // Sets the width of label to 200 points
            [self->waterMark.heightAnchor constraintEqualToConstant:labelHeight]                      // Sets the height of label to 50 points
        ]];
    }
}

- (BOOL)needPopupAboutView {
    if(PublicUtils.isTVOS) return false;
    // NSString *key = @"appHasLaunchedBefore";
    NSString *key = @"needPopupAboutView20260215";
    BOOL keyExists = [[NSUserDefaults standardUserDefaults] boolForKey:key];

    if (!keyExists) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:key];
        [[NSUserDefaults standardUserDefaults] synchronize]; // iOS 12+ 可省略
        return YES;
    }
    return NO;
}


- (bool)isIPhonePortrait{
    bool isIPhone = ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone);
    CGFloat screenHeightInPoints = CGRectGetHeight([[PublicUtils screenForView:self.viewIfLoaded] bounds]);
    CGFloat screenWidthInPoints = CGRectGetWidth([[PublicUtils screenForView:self.viewIfLoaded] bounds]);
    bool isPortrait = screenHeightInPoints > screenWidthInPoints;
    return isIPhone && isPortrait;
   // return isPortrait;
}

- (UIBarButtonItem *)createAddHostButton{
    // 创建按钮
    
    bool liquidGlassEnabled = PublicUtils.liquidGlassEnabled;
    // bool liquidGlassEnabled = false;

    CGFloat buttonHeight = 30;
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.backgroundColor = liquidGlassEnabled ? ThemeManager.appPrimaryColor : ThemeManager.appPrimaryColor; // #0A85FF
    button.layer.cornerRadius = buttonHeight/2;
    if (@available(iOS 13.0, *)) button.layer.cornerCurve = kCACornerCurveContinuous;
    button.clipsToBounds = !liquidGlassEnabled;

    // 设置图标（SF Symbol）

    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration
                                              configurationWithPointSize:liquidGlassEnabled ? 18.7 :17
                                              weight:liquidGlassEnabled ? UIImageSymbolWeightRegular :UIImageSymbolWeightMedium];
        UIImage *image = [UIImage systemImageNamed:@"plus.circle" withConfiguration:config];
        [button setImage:image forState:UIControlStateNormal];
        button.imageEdgeInsets = liquidGlassEnabled ? UIEdgeInsetsMake(0, 7.6, 0.75, 0) : UIEdgeInsetsZero;;
        NSString* buttonStringHead = liquidGlassEnabled ? @"  " : @"";
        [button setTitle: [buttonStringHead stringByAppendingString:
                           [LocalizationHelper localizedStringForKey:@" Add Host"]]
                forState:UIControlStateNormal]; // 注意空格用于间隔
    } else {
        [button setTitle:[LocalizationHelper localizedStringForKey:@"Add Host"] forState:UIControlStateNormal]; // 注意空格用于间隔
    }
    // [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];

    button.titleLabel.font = [UIFont systemFontOfSize:liquidGlassEnabled ? 16 : 16 weight:UIFontWeightMedium];
    // 文字颜色设置为 tintColor 控制
    if(liquidGlassEnabled) {
        button.contentEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 10);
        button.titleEdgeInsets = UIEdgeInsetsMake(0, 0, 0.9, 0);
    }
    button.tintColor = liquidGlassEnabled ? ThemeManager.appPrimaryColor : UIColor.whiteColor;
    [button setTitleColor:button.tintColor forState:UIControlStateNormal];
    // button.tintColor = UIColor.whiteColor;
    // [button setTitleColor:button.tintColor forState:UIControlStateNormal];

    // 设置按下时的 tintColor（变灰或淡）
    UIColor *highlightColor = ThemeManager.textColorGray;
    [button setTitleColor:highlightColor forState:UIControlStateHighlighted];
    button.adjustsImageWhenHighlighted = YES; // 图标自动变淡

    // 手动设定大小（如图中大约宽118高40）
    button.frame = CGRectMake(0, 0, 130, buttonHeight);

    // 添加点击事件
    [button addTarget:self action:@selector(addHostTapped) forControlEvents:UIControlEventTouchUpInside];

    // 创建 UIBarButtonItem
    UIBarButtonItem *barItem = [[UIBarButtonItem alloc] initWithCustomView:button];
#if !TARGET_OS_TV
    if (@available(iOS 26.0, *)) barItem.sharesBackground = false;
#endif
    return barItem;
}

- (UIBarButtonItem *)createHelpButton{
    // 创建按钮
    CGFloat buttonHeight = 30;
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.backgroundColor = [UIColor clearColor]; // #0A85FF
    // button.layer.cornerRadius = buttonHeight/2;
    button.clipsToBounds = YES;
    
    // 设置图标（SF Symbol）
    if (@available(iOS 13.0, *)) {
        CGFloat symbolSize = PublicUtils.isTVOS
        ? buttonHeight*0.95
        : (PublicUtils.liquidGlassEnabled ? buttonHeight*0.73 : buttonHeight*0.85);
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:symbolSize
                                            weight:UIImageSymbolWeightRegular];
        UIImage *image = [UIImage systemImageNamed:@"questionmark.circle" withConfiguration:config];
        [button setImage:image forState:UIControlStateNormal];
        [button setTitle:@"" forState:UIControlStateNormal]; // 注意空格用于间隔
    } else {
        [button setTitle:[LocalizationHelper localizedStringForKey:@"About"] forState:UIControlStateNormal]; // 注意空格用于间隔
    }
    // [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];

    button.titleLabel.font = [UIFont systemFontOfSize:buttonHeight*0.6 weight:UIFontWeightMedium];
    // 文字颜色设置为 tintColor 控制
    button.tintColor = ThemeManager.appPrimaryColor;
    [button setTitleColor:button.tintColor forState:UIControlStateNormal];

    button.frame = CGRectMake(0, 0, buttonHeight*1.3, buttonHeight*1.05);

    // 添加点击事件
    [button addTarget:self action:@selector(helpButtonTapped) forControlEvents:UIControlEventTouchUpInside];

    // 创建 UIBarButtonItem
    UIBarButtonItem *barItem = [[UIBarButtonItem alloc] initWithCustomView:button];
    if(PublicUtils.isTVOS) barItem.style = UIBarButtonItemStyleBordered;

#if !TARGET_OS_TV
    if (@available(iOS 26.0, *)) barItem.sharesBackground = false;
#endif

    return barItem;
}

- (void)helpButtonTapped{
    if (@available(iOS 13.0, *)) {
        AboutViewController *aboutVC = [[AboutViewController alloc] init];
        aboutVC.modalPresentationStyle = UIModalPresentationFormSheet;
        [self presentViewController:aboutVC animated:YES completion:nil];
    } else {
        // Fallback on earlier versions
    }
}

- (void)applyNavBarAppearance{
#if TARGET_OS_TV
    UINavigationBar *navigationBar = self.navigationController.navigationBar;
    UIColor *backgroundColor = ThemeManager.hostViewBackgroundColor;
    navigationBar.backgroundColor = backgroundColor;
    navigationBar.barTintColor = backgroundColor;
    navigationBar.translucent = NO;
    navigationBar.shadowImage = [UIImage new];
#else
    if (@available(iOS 13.0, *)) {
        self.navigationController.navigationBar.standardAppearance.backgroundColor = [UIColor clearColor]; // old ios depend on this, do not remove
        self.navigationController.navigationBar.standardAppearance = navBarAppearanceStandard;
        self.navigationController.navigationBar.scrollEdgeAppearance = navBarAppearanceStandard;
    }
    else{
        self.navigationController.navigationBar.backgroundColor = [UIColor clearColor]; // old ios depend on this, do not remove
        self.navigationController.navigationBar.barTintColor = [UIColor clearColor]; // ios 14 depend on this, do not remove
        self.navigationController.navigationBar.barTintColor = ThemeManager.hostViewBackgroundColor; // ios 14 depend on this, do not remove
    }
#endif
}

- (void)applyThemeToNavigationButton:(UIBarButtonItem *)barButtonItem {
    if (!barButtonItem) return;

    barButtonItem.tintColor = ThemeManager.appPrimaryColor;

    if (@available(iOS 13.0, *)) {
        UIUserInterfaceStyle style = ThemeManager.overrideUserInterfaceStyle;
        UIView *customView = barButtonItem.customView;
        customView.overrideUserInterfaceStyle = style;

        if ([customView isKindOfClass:UIButton.class]) {
            UIButton *button = (UIButton *)customView;
            button.tintColor = ThemeManager.appPrimaryColor;
            [button setTitleColor:button.tintColor forState:UIControlStateNormal];
            [button setTitleColor:ThemeManager.textColorGray forState:UIControlStateHighlighted];
        }
    }

    if (barButtonItem == _addHostButton && [barButtonItem.customView isKindOfClass:UIButton.class]) {
        UIButton *button = (UIButton *)barButtonItem.customView;
        button.backgroundColor = PublicUtils.liquidGlassEnabled ? UIColor.clearColor : ThemeManager.appPrimaryColor;
        button.tintColor = PublicUtils.liquidGlassEnabled ? ThemeManager.appPrimaryColor : UIColor.whiteColor;
        [button setTitleColor:button.tintColor forState:UIControlStateNormal];
    }
}

- (void)applyThemeToNavigationControls {
    if (@available(iOS 13.0, *)) {
        UIUserInterfaceStyle style = ThemeManager.overrideUserInterfaceStyle;
        self.overrideUserInterfaceStyle = style;
        self.view.overrideUserInterfaceStyle = style;
        self.navigationController.overrideUserInterfaceStyle = style;
        self.navigationController.view.overrideUserInterfaceStyle = style;
        self.navigationController.navigationBar.overrideUserInterfaceStyle = style;
        self.navigationItem.titleView.overrideUserInterfaceStyle = style;
    }

    NSMutableArray<UIBarButtonItem *> *barButtonItems = [NSMutableArray array];
    if (self.navigationItem.leftBarButtonItems) [barButtonItems addObjectsFromArray:self.navigationItem.leftBarButtonItems];
    if (self.navigationItem.rightBarButtonItems) [barButtonItems addObjectsFromArray:self.navigationItem.rightBarButtonItems];
    if (_settingsButton) [barButtonItems addObject:_settingsButton];
    if (_profilesButton) [barButtonItems addObject:_profilesButton];
    if (_addHostButton) [barButtonItems addObject:_addHostButton];
    if (_helpButton) [barButtonItems addObject:_helpButton];
    if (_upButton) [barButtonItems addObject:_upButton];

    for (UIBarButtonItem *barButtonItem in barButtonItems) {
        [self applyThemeToNavigationButton:barButtonItem];
#if !TARGET_OS_TV
        if (@available(iOS 26.0, *)) {
            // barButtonItem.sharesBackground = barButtonItem == _addHostButton || barButtonItem == _helpButton;
        }
#endif
    }
}

- (void)setupNavBar{
#if TARGET_OS_TV
    self.navigationController.navigationBar.barTintColor = ThemeManager.hostViewBackgroundColor;
    self.navigationController.navigationBar.titleTextAttributes = @{
        NSForegroundColorAttributeName: ThemeManager.textColor
    };
    self.navigationController.navigationBar.shadowImage = [UIImage new];
#else
    if (@available(iOS 13.0, *)) {
        UINavigationBarAppearance* appearance = [[UINavigationBarAppearance alloc] init];
        [appearance configureWithOpaqueBackground];
        appearance.backgroundColor = ThemeManager.hostViewBackgroundColor;
        appearance.shadowColor = nil;
        NSDictionary* titleTextAttributes = @{
            NSForegroundColorAttributeName: ThemeManager.textColor
        };
        appearance.titleTextAttributes = titleTextAttributes;
        appearance.shadowColor = [UIColor clearColor];
        appearance.backgroundImage = nil;
        navBarAppearanceStandard = appearance;
    }
#endif
    [self applyNavBarAppearance];

    if (!_settingsButton) {
        _settingsButton = [[UIBarButtonItem alloc] initWithTitle:[LocalizationHelper localizedStringForKey:@"Settings"]
                                                           style:UIBarButtonItemStylePlain
                                                          target:nil
                                                          action:nil];
    }
    if (!_profilesButton) {
        _profilesButton = [[UIBarButtonItem alloc] initWithTitle:[LocalizationHelper localizedStringForKey:@"Game Profile"]
                                                           style:UIBarButtonItemStylePlain
                                                          target:nil
                                                          action:nil];
    }
    self->_addHostButton = [self createAddHostButton];
    self->_helpButton = [self createHelpButton];
    if (PublicUtils.liquidGlassEnabled) {
        if (@available(iOS 26.0, *)) {
            // _addHostButton.hidesSharedBackground = true;
            // _helpButton.hidesSharedBackground = true;
        }
    }
    //[self setupHostViewTitle];



    self.navigationItem.rightBarButtonItems = PublicUtils.isTVOS
    ? VLBarButtonItems(nil, nil)
    : VLBarButtonItems(_helpButton, _addHostButton); // 顺序：右边靠右的是第一个

    // Set the side bar button action. When it's tapped, it'll show the sidebar.

    [_settingsButton setTarget:self.revealViewController];
    [_settingsButton setAction:@selector(revealToggle:)];
    if (@available(iOS 13.0, *)) {
        [_settingsButton setTitle:nil];
        CGFloat symbolSize = PublicUtils.isTVOS ? 34 : (PublicUtils.liquidGlassEnabled ? 18 : 23);
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:symbolSize weight:PublicUtils.isTVOS ? UIImageSymbolWeightRegular : UIImageSymbolWeightMedium ];
        UIImage *image = [[UIImage systemImageNamed:@"sidebar.left" withConfiguration:config] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        [_settingsButton setImage:image];
        _settingsButton.imageInsets = PublicUtils.liquidGlassEnabled
        ? UIEdgeInsetsMake(0, 0, 0, 0.55)
        : (PublicUtils.tvOS26Aavailable ? UIEdgeInsetsMake(10, 10, 0, 0) : UIEdgeInsetsMake(0, 0, 0, 0));
        if(PublicUtils.liquidGlassEnabled){
            // if(@available(iOS 26.0, *)) _settingsButton.hidesSharedBackground = YES;
            _settingsButton.tintColor = ThemeManager.appPrimaryColor;
        }
    } else {
        [_settingsButton setTitle:[LocalizationHelper localizedStringForKey:@"Settings"]];
    }
    
    [_profilesButton setTarget:self];
    [_profilesButton setAction:@selector(profilesButtonTapped)];
    if (@available(iOS 13.0, *)) {
        [_profilesButton setTitle:nil];
        
        UIImageSymbolConfiguration *config;
        UIImage *image;
        if(PublicUtils.iOS18Available){
            config = [UIImageSymbolConfiguration configurationWithPointSize:PublicUtils.liquidGlassEnabled ? 20.5 : 22.5 weight:PublicUtils.liquidGlassEnabled ? UIImageSymbolWeightRegular :  UIImageSymbolWeightRegular];
            image = [[UIImage systemImageNamed: @"gamecontroller.circle" withConfiguration:config] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            [_profilesButton setImage:image];
            _profilesButton.imageInsets = PublicUtils.liquidGlassEnabled ? UIEdgeInsetsMake(0, 0, 0, 0.55) : UIEdgeInsetsMake(10, 10, 0, 0);
            if(PublicUtils.liquidGlassEnabled){
                _profilesButton.tintColor = ThemeManager.appPrimaryColor;
            }
        }
        else{
            image = [[UIImage imageNamed: @"gamecontroller.circle.regular"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            [_profilesButton setImage:image];
            _profilesButton.imageInsets = UIEdgeInsetsMake(-1.5, 0, -1.5, 0);
            _profilesButton.tintColor = ThemeManager.appPrimaryColor;
            _profilesButtonUsesCompactSymbol = NO;
            [self updateLegacyCompactProfilesNavigationIcon];
        }
        
    } else {
        [_profilesButton setTitle:[LocalizationHelper localizedStringForKey:@"Game Profile"]];
    }
    
#if !TARGET_OS_TV
    if (@available(iOS 26.0, *)) {
        _settingsButton.sharesBackground = false;
        _profilesButton.sharesBackground = false;
        _addHostButton.sharesBackground = false;
        _helpButton.sharesBackground = false;
     }
#endif

    
    
    // Set the host name button action. When it's tapped, it'll show the host selection view.
    _upButton = [[UIBarButtonItem alloc] init];
    
    
    if (@available(iOS 13.0, *)) {
        [_upButton setTitle:@""];
        CGFloat symbolSize = PublicUtils.isTVOS ? 27.5 : (PublicUtils.liquidGlassEnabled ? 16 : 21.5);
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:symbolSize weight:UIImageSymbolWeightMedium];
        UIImage *image = [[UIImage systemImageNamed:PublicUtils.liquidGlassEnabled ? @"macwindow.on.rectangle" : @"tv" withConfiguration:config] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        [_upButton setImage:image];
        _upButton.imageInsets = PublicUtils.liquidGlassEnabled ? UIEdgeInsetsMake(0, 0, 0, 1) : UIEdgeInsetsMake(25, 20, 0, 15);
    } else {
        [_upButton setTitle:[LocalizationHelper localizedStringForKey:@"Select New Host"]];
    }
    
    //[self->_upButton setTitle: [LocalizationHelper localizedStringForKey: @"Select New Host"]];
    [_upButton setTarget:self];
    [_upButton setAction:@selector(switchToHostView)];
}

- (void)updateTheme {
    self.view.backgroundColor = ThemeManager.hostViewBackgroundColor;
    self.hostCollectionVC.view.backgroundColor = ThemeManager.hostViewBackgroundColor;
    self.collectionView.backgroundColor = ThemeManager.hostViewBackgroundColor;

#if TARGET_OS_TV
    self.navigationController.navigationBar.barTintColor = ThemeManager.hostViewBackgroundColor;
    self.navigationController.navigationBar.titleTextAttributes = @{
        NSForegroundColorAttributeName: ThemeManager.textColor
    };
#else
    if (@available(iOS 13.0, *)) {
        UINavigationBarAppearance* appearance = navBarAppearanceStandard;
        appearance.backgroundColor = ThemeManager.hostViewBackgroundColor;
        NSDictionary* titleTextAttributes = @{
            NSForegroundColorAttributeName: ThemeManager.textColor
        };
        appearance.titleTextAttributes = titleTextAttributes;
        navBarAppearanceStandard = appearance;
    }
#endif
    
    _settingsButton.tintColor = ThemeManager.appPrimaryColor;
    _profilesButton.tintColor = ThemeManager.appPrimaryColor;
    _upButton.tintColor = ThemeManager.appPrimaryColor;
    ((UIButton*)_addHostButton.customView).backgroundColor = PublicUtils.liquidGlassEnabled ? UIColor.clearColor : ThemeManager.appPrimaryColor;
    ((UIButton*)_helpButton.customView).tintColor = ThemeManager.appPrimaryColor;
    [self applyThemeToNavigationControls];

    [self applyNavBarAppearance];
    [self updateTitle];
    if (hostViewTitleLabel) {
        hostViewTitleLabel.textColor = ThemeManager.textColor;
    }
    
    if (@available(iOS 13.0, *)) [GamepadNavigationIllustrationHud updateCurrentTheme];

    [self.hostCollectionVC updateTheme];
    [self updateAppCollectionTheme];
}

- (void)updateAppCollectionTheme {
    for (UICollectionViewCell *cell in self.collectionView.visibleCells) {
        for (UIView *view in cell.subviews) {
            if ([view isKindOfClass:[UIAppView class]]) {
                [(UIAppView *)view updateTheme];
            }
        }
    }
}

- (void)updateLegacyCompactProfilesNavigationIcon {
    if (PublicUtils.iOS18Available || !_profilesButton) return;
    BOOL compact = [PublicUtils isCompactNavigationBar:self.navigationController.navigationBar];
    if (_profilesButtonUsesCompactSymbol == compact) return;
    _profilesButtonUsesCompactSymbol = compact;

    UIImage *image;
    if (compact) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration
            configurationWithPointSize:18 weight:UIImageSymbolWeightRegular];
        image = [UIImage systemImageNamed:@"gamecontroller.fill" withConfiguration:config];
        _profilesButton.imageInsets = UIEdgeInsetsZero;
    } else {
        image = [UIImage imageNamed:@"gamecontroller.circle.regular"];
        _profilesButton.imageInsets = UIEdgeInsetsMake(-1.5, 0, -1.5, 0);
    }
    _profilesButton.image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

// Called when the system's theme (light/dark mode) changes
// will not be active if the app is streaming
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        DataManager* dataMan = [[DataManager alloc] init];
        TemporarySettings* tempSettings = [dataMan getSettings];
        if(tempSettings.appTheme.intValue != UIUserInterfaceStyleUnspecified) return;
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [ThemeManager systemUserInterfaceStyleDidChange:self.traitCollection.userInterfaceStyle];
        }
    }
}

- (void)viewDidLoad{
    [super viewDidLoad];
    
    DataManager* dataMan = [[DataManager alloc] init];
    TemporarySettings* tempSettings = [dataMan getSettings];
    [ThemeManager setUserInterfaceStyle:tempSettings.appTheme.intValue];
    
    self.settingsExpandedInStreamView = false; // init this flag
    self.revealViewController.isStreaming = false; //init this flag for rvlVC
    self.revealViewController.mainFrameIsInHostView = true;
    
    [self.revealViewController setDelegate:self];
    
    // Disable bounce-back on reveal VC otherwise the settings will snap closed
    // if the user drags all the way off the screen opposite the settings pane.
    self.revealViewController.bounceBackOnOverdraw = NO;
    
    [self setupNavBar];
    
#if !TARGET_OS_TV
    // Set the gesture
    [self.view addGestureRecognizer:self.revealViewController.panGestureRecognizer];
#else
    // Restore focus on the selected app on view controller pop navigation
    self.restoresFocusAfterTransition = NO;
    self.collectionView.remembersLastFocusedIndexPath = YES;
    
    self.navigationController.navigationBar.titleTextAttributes = [NSDictionary dictionaryWithObject:[UIColor whiteColor] forKey:NSForegroundColorAttributeName];
#endif
    
    _loadingFrame = [self.storyboard instantiateViewControllerWithIdentifier:@"loadingFrame"];
    
    // Set the current position to the center
    currentPosition = FrontViewPositionLeft;
    
    // Set up crypto
    [CryptoManager generateKeyPairUsingSSL];
    _uniqueId = [IdManager getUniqueId];
    _clientCert = [CryptoManager readCertFromFile];

    _appManager = [[AppAssetManager alloc] initWithCallback:self];
    _opQueue = [[NSOperationQueue alloc] init];
    
    // Only initialize the host picker list once
    if (hostList == nil) {
        hostList = [[NSMutableSet alloc] init];
    }
    
    _boxArtCache = [[NSCache alloc] init];
    _boxArtCache.totalCostLimit = 32 * 1024 * 1024;
    _boxArtQueue = [[NSOperationQueue alloc] init];
    _boxArtQueue.maxConcurrentOperationCount = 2;
    _boxArtQueue.qualityOfService = NSQualityOfServiceUtility;


    self.collectionView.delaysContentTouches = NO;
    self.collectionView.allowsMultipleSelection = NO;
    #if !TARGET_OS_TV
    self.collectionView.multipleTouchEnabled = NO;
    #else
    // This is the only way to get long press events on a UICollectionViewCell :(
    UILongPressGestureRecognizer* cellLongPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleCollectionViewLongPress:)];
    cellLongPress.delaysTouchesBegan = YES;
    [self.collectionView addGestureRecognizer:cellLongPress];
    #endif

    [self updateTitle];
    
    [self retrieveSavedHosts];

    _discMan = [[DiscoveryManager alloc] initWithHosts:[hostList allObjects] andCallback:self];


    //if([SettingsViewController isLandscapeNow] != _streamConfig.width > _streamConfig.height)
    //[self simulateSettingsButtonPress]; //force expand setting view if orientation changed since last quit from app.
    //[self simulateSettingsButtonPress]; //force expand setting view if orientation changed since last quit from app.
    //[self updateResolutionAccordingly];
    
    // SettingsViewController* self.settingsViewController = (SettingsViewController*)[self.revealViewController rearViewController];
    // [self.settingsViewController updateResolutionTable];
    
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleMenuResize:)];
    longPress.delaysTouchesBegan = false;
    longPress.delaysTouchesEnded = false;
    [self.view addGestureRecognizer:longPress];


    #if !TARGET_OS_TV
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:PublicUtils.isIPhone?@"iPhone":@"iPad" bundle:nil];
    SettingsViewController *viewController = [storyboard instantiateViewControllerWithIdentifier:@"settingsViewController"];
    // 强制加载视图
    __unused UIView *view = viewController.view;
    #endif
    
    snapshot = nil;
    
    _controllerConnectObserver = [[NSNotificationCenter defaultCenter] addObserverForName:GCControllerDidConnectNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        Log(LOG_I, @"Controller connected!");
        GCController* controller = note.object;
        if (controller.extendedGamepad != nil) {
            if (@available(iOS 14.0, tvOS 14.0, *)) {
                for (GCControllerElement* element in controller.physicalInputProfile.allElements) {
                    element.preferredSystemGestureState = GCSystemGestureStateDisabled;
                }
            }
        }
    }];
    
    _controllerDisconnectObserver = [[NSNotificationCenter defaultCenter] addObserverForName:GCControllerDidDisconnectNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        Log(LOG_I, @"Controller disconnected!");
        
        GCController* controller = note.object;
        [self unregisterControllerCallbacks:controller];
    }];
    
    [self prewarmSoftKeyboard];
        
    
    [IAPManager.shared fetchProducts];
    [GenericUtils handleAddOnProductPurchaseIntentFor:AddOnProductPencilProPack];
    
    /*
    if (@available(iOS 15.0, *)) {
        [IAPManager checkPurchaseInfo:AddOnProductPencilProPack completion:^(PurchaseInfo* info) {
            switch (info.status) {
                case PurchaseStatusPurchased:
                    NSLog(@"PurchaseStatus Purchased");
                    break;
                case PurchaseStatusNotPurchased:
                    NSLog(@"PurchaseStatus NotPurchased");
                    break;
                case PurchaseStatusRevoked:
                    NSLog(@"PurchaseStatus Revoked");
                    break;
                default:
                    break;
            }
            NSLog(@"PurchaseStatus Valid: %d", info.valid);
            NSLog(@"PurchaseStatus Expiration: %@", info.expirationDate);
        }];
    }
    */
}

- (void)prewarmSoftKeyboard {
    if(PublicUtils.isTVOS) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        UITextField *tf = [[UITextField alloc] initWithFrame:CGRectZero];
        tf.hidden = YES;
        [[UIApplication sharedApplication].windows.firstObject addSubview:tf];
        [tf becomeFirstResponder];
        [tf resignFirstResponder];
        [tf removeFromSuperview];
    });
}

-(void)viewDidLayoutSubviews{
    [super viewDidLayoutSubviews];
    [self constrainIPhoneAppViewToSafeArea];
    // [self logAppCollectionLayout:@"parent-layout-completed"];
    [self updateLegacyCompactProfilesNavigationIcon];
    [self updateHosts];
    // if (@available(iOS 13.0, *)) [GamepadNavigationIllustrationHud showInKeyWindow];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    if (!PublicUtils.isIPhone || PublicUtils.isFoldableIPhone) { return; }
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [self refreshAppCollectionLayout];
    } completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [self refreshAppCollectionLayout];
    }];
}

-(void) fillResolutionTable:(CMVideoDimensions *)resolutionTable externalDisplayMode:(NSInteger)externalDisplayMode{
    UIWindow *window = self.view.window;
    NSLog(@" window %@", window);

    CGFloat screenScale = window.screen.scale;
    CGFloat safeAreaWidth = (window.frame.size.width - window.safeAreaInsets.left - window.safeAreaInsets.right) * screenScale;
    CGFloat appWindowWidth = window.frame.size.width * screenScale;
    CGFloat appWindowHeight = window.frame.size.height * screenScale;

    if(externalDisplayMode == 1 && UIScreen.screens.count > 1){
        CGRect bounds = [UIScreen.screens.lastObject bounds];
        screenScale = [UIScreen.screens.lastObject scale];
        appWindowWidth = bounds.size.width * screenScale;
        appWindowHeight = bounds.size.height * screenScale;
    }
    
    bool needSwapWidthAndHeight = appWindowWidth < appWindowHeight;
    
    resolutionTable[0] = (CMVideoDimensions){ .width = 1280, .height = 720 };
    resolutionTable[1] = (CMVideoDimensions){ .width = 1920, .height = 1080 };
    resolutionTable[2] = (CMVideoDimensions){ .width = 3840, .height = 2160 };
    
    for(uint8_t i=0;i<6;i++){
        int32_t longSideLen = MAX(resolutionTable[i].width, resolutionTable[i].height);
        int32_t shortSideLen = MIN(resolutionTable[i].width, resolutionTable[i].height);
        if(needSwapWidthAndHeight) resolutionTable[i] = (CMVideoDimensions){ .width = shortSideLen, .height = longSideLen };
        else resolutionTable[i] = (CMVideoDimensions){ .width = longSideLen, .height = shortSideLen };
    }

    // add app window resolution and not swap width and height
    resolutionTable[3] = (CMVideoDimensions){ .width = (int32_t)safeAreaWidth, .height = (int32_t)appWindowHeight };
    resolutionTable[4] = (CMVideoDimensions){ .width = (int32_t)appWindowWidth, .height = (int32_t)appWindowHeight };
}

-(void) updateResolutionAccordingly {
    DataManager* dataMan = [[DataManager alloc] init];
    Settings *currentSettings = [dataMan retrieveSettings];

    CMVideoDimensions tempResolutionTable[6] = {0};
    tempResolutionTable[5] = (CMVideoDimensions){
        .width = (int32_t)currentSettings.width.intValue,
        .height = (int32_t)currentSettings.height.intValue,
    };
    [self fillResolutionTable:tempResolutionTable externalDisplayMode:currentSettings.externalDisplayMode.intValue];
    return;
    
    /*
    int selectedIndex = currentSettings.resolutionSelected.intValue;
    if (selectedIndex >= 0 && selectedIndex < 6) {
        CMVideoDimensions originalDimensions = tempResolutionTable[selectedIndex];
        CMVideoDimensions targetDimensions = originalDimensions;
        currentSettings.width = @(targetDimensions.width);
        currentSettings.height = @(targetDimensions.height);
        NSLog(@"Updated resolution to: %@ x %@", currentSettings.width, currentSettings.height);
    }
    [dataMan saveData];
     */
}

#if TARGET_OS_TV
-(void)handleCollectionViewLongPress:(UILongPressGestureRecognizer *)gestureRecognizer
{
    // FIXME: Something is delaying touches so we only get to the Begin state
    // before we actually want to signal the long press.
    if (gestureRecognizer.state != UIGestureRecognizerStateBegan) {
        return;
    }
    
    CGPoint point = [gestureRecognizer locationInView:self.collectionView];
    NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:point];
    if (indexPath != nil) {
        [self appLongClicked:self.sortedAppList[indexPath.row] view:nil];
    }
}

- (void)openTvSettings:(id)sender
{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString] options:@{} completionHandler:nil];
}
#endif

-(void)beginForegroundRefresh
{
    if (!_background || _viewJustAppeared) {
        // This will kick off box art caching

        _viewJustAppeared = false;

        [_foregroundHostUpdateTimer invalidate];
        _foregroundHostUpdateTimer = nil;
        
        _foregroundHostUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:5 repeats:YES block:^(NSTimer *timer) {
           [self updateHosts];
        }];
        
        
        [_discMan startDiscovery];
        
        // This will refresh the applist when a paired host is selected
        if (_selectedHost != nil && _selectedHost.pairState == PairStatePaired) {
            [self noneUserInitiatedHostAction:_selectedHost view:nil];
        }
    }
}

-(void)handlePendingShortcutAction
{
    // Check if we have a pending shortcut action
    AppDelegate* delegate = (AppDelegate*)[UIApplication sharedApplication].delegate;
    if (delegate.pcUuidToLoad != nil) {
        // Find the host it corresponds to
        TemporaryHost* matchingHost = nil;
        for (TemporaryHost* host in hostList) {
            if ([host.uuid isEqualToString:delegate.pcUuidToLoad]) {
                matchingHost = host;
                break;
            }
        }
        
        // Clear the pending shortcut action
        delegate.pcUuidToLoad = nil;
        
        // Complete the request
        if (delegate.shortcutCompletionHandler != nil) {
            delegate.shortcutCompletionHandler(matchingHost != nil);
            delegate.shortcutCompletionHandler = nil;
        }
        
        if (matchingHost != nil && _selectedHost != matchingHost) {
            // Navigate to the host page
            [self noneUserInitiatedHostAction:matchingHost view:nil];
        }
    }
}

-(void)handleReturnToForeground
{
    _background = NO;
    [self applyThemeToNavigationControls];
    
    [self beginForegroundRefresh];
    
    // Check for a pending shortcut action when returning to foreground
    [self handlePendingShortcutAction];
}

- (void)handleAboutViewDismissal:(NSNotification *)notification
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self applyThemeToNavigationControls];
    });
}

-(void)handleEnterBackground
{
    _background = YES;
    
    [_discMan stopDiscovery];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:NO];
    [self refreshAppCollectionLayout];

    _viewJustAppeared = true;

    [self beginForegroundRefresh];

    // [self setupHostViewTitle];
    // [self reloadScrollHostView]; //remove this for proper test
    [self attachWaterMark];
    if (@available(iOS 13.0, *)) [GamepadNavigationIllustrationHud showInKeyWindow];

// #if !TARGET_OS_TV
    
    [[self revealViewController] setPrimaryViewController:self];
    self.revealViewController.isStreaming = false; // tell the revealViewController streaming is finished
    [self.hostCollectionVC refreshVisibleHostCards];
    if (@available(iOS 13.0, *)) {
        if (ControllerNavigator.uiNavigationDelegate == self ||
            ControllerNavigator.uiNavigationDelegate == self.hostCollectionVC) {
            [ControllerNavigator restoreUINavigationHighlight];
        }
    }
    //[self.settingsButton setEnabled:![self isIPhonePortrait]]; //make sure settings button is disabled in iphone portrait mode.
    //recordedScreenWidth = CGRectGetWidth([[PublicUtils screenForView:self.viewIfLoaded] bounds]); // Get the screen's bounds (in points), update recorded screen width
// #endif
    
    [self.navigationController setNavigationBarHidden:NO animated:NO];
    
    // Hide 1px border line
    UIImage* fakeImage = [[UIImage alloc] init];
    // [self.navigationController.navigationBar setShadowImage:fakeImage];
    // [self.navigationController.navigationBar setBackgroundImage:fakeImage forBarPosition:UIBarPositionAny barMetrics:UIBarMetricsDefault];
    
    // Check for a pending shortcut action when appearing
    [self handlePendingShortcutAction];
    
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(handleReturnToForeground)
                                                 name: UIApplicationDidBecomeActiveNotification
                                               object: nil];
    
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(handleEnterBackground)
                                                 name: UIApplicationWillResignActiveNotification
                                               object: nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleAboutViewDismissal:)
                                                 name:@"AboutViewDidDismissNotification"
                                               object:nil];
    //[self simulateSettingsButtonPress]; //force reload resolution table in the setting
    //[self simulateSettingsButtonPress];
    [self updateResolutionAccordingly];
    if([self needPopupAboutView])[self helpButtonTapped];
    
    if (@available(iOS 13.0, *)) {
        ControllerUtil.delegate = self;
        [ControllerUtil installControllerObserversIfNeeded];
        [ControllerNavigator setRadialMenuDelegate:self];
        DataManager* dataMan = [[DataManager alloc] init];
        Settings* settings = [dataMan retrieveSettings];
        ControllerNavigator.enabled = settings.enableControllerNavigation;
        ControllerNavigator.localRadialMenuButton = (ControllerElement)settings.localRadialMenuButton.intValue;
        ControllerNavigator.customPositionForLocalRadialMenuButton = (ControllerElementPosition)settings.customLocalRadialMenuButtonPosition.intValue;
        ControllerNavigator.customPositionForStreamingRadialMenuButton = (ControllerElementPosition)settings.customStreamingRadialMenuButtonPosition.intValue;
        ControllerNavigator.streamingRadialMenuButton = (ControllerElement)settings.streamingRadialMenuButton.intValue;
        ControllerNavigator.streamingRadialMenuDelay = (NSTimeInterval)settings.streamingRadialMenuDelay.floatValue;
        ControllerNavigator.controllerMouseStick = (ControllerElement)settings.controllerMouseStick.intValue;
        ControllerNavigator.controllerMouseLeftButton = (ControllerElement)settings.controllerMouseLeftButton.intValue;
        ControllerNavigator.controllerMouseRightButton = (ControllerElement)settings.controllerMouseRightButton.intValue;
        ControllerNavigator.controllerMouseExpo = settings.controllerMouseExpo.floatValue;
        if(ControllerNavigator.enabled) [ControllerNavigator start];
    }
    
    [self.deeplinkCoordinator mainFrameDidAppear];
    
#if !TARGET_OS_TV
    if(!self.presentedViewController) {
        [GenericUtils handleBarrelRollRedminderIn:self];
    }
#else
    [ControllerUtil handleGameControllerRequiredTipIn:self delay:1];
#endif
}

- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    [_deeplinkCoordinator viewWillLeave];
    [_foregroundHostUpdateTimer invalidate];
    _foregroundHostUpdateTimer = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:NO];

    // StreamFrameViewController hides the navigation bar. Restore it before
    // rebuilding the collection views so their first layout uses final safe-area geometry.
    [self.navigationController setNavigationBarHidden:NO animated:NO];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateTheme)
                                             name:ThemeManager.ThemeDidChangeNotification
                                               object:nil];

    /* this makes background color works*/
    
    if(!_settingsViewExpanded){
        for (UIView *subview in self.view.subviews) {
            [subview removeFromSuperview]; // 暂时移除所有子视图
        }
    }
    
    // We can get here on home press while streaming
    // since the stream view segues to us just before
    // entering the background. We can't check the app
    // state here (since it's in transition), so we have
    // to use this function that will use our internal
    // state here to determine whether we're foreground.
    //
    // Note that this is neccessary here as we may enter
    // this view via an error dialog from the stream
    // view, so we won't get a return to active notification
    // for that which would normally fire beginForegroundRefresh.
    
    [self.view addSubview:self.collectionView];
    [self constrainIPhoneAppViewToSafeArea];
    [self initHostCollection];
    if(!_enteredAppView) [self switchToHostView];
    else if (@available(iOS 13.0, *)) [ControllerNavigator setUINavigationDelegate:self];
    
    [self updateTheme];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    // when discovery stops, we must create a new instance because
    // you cannot restart an NSOperation when it is finished
    [_discMan stopDiscovery];
    
    // Purge the box art cache
    [_boxArtCache removeAllObjects];
    
    // Remove our lifetime observers to avoid triggering them
    // while streaming
    [[NSNotificationCenter defaultCenter] removeObserver:_controllerConnectObserver];
    [[NSNotificationCenter defaultCenter] removeObserver:_controllerDisconnectObserver];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) retrieveSavedHosts {
    DataManager* dataMan = [[DataManager alloc] init];
    NSArray* hosts = [dataMan getHosts];
    @synchronized(hostList) {
        [hostList addObjectsFromArray:hosts];
        
        // Initialize the non-persistent host state
        for (TemporaryHost* host in hostList) {
            if (host.activeAddress == nil) {
                host.activeAddress = host.localAddress;
            }
            if (host.activeAddress == nil) {
                host.activeAddress = host.externalAddress;
            }
            if (host.activeAddress == nil) {
                host.activeAddress = host.address;
            }
            if (host.activeAddress == nil) {
                host.activeAddress = host.ipv6Address;
            }
        }
    }
}

- (void) hostCardContentsDidChange:(TemporaryHost*)host {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (![self isStreaming]) {
            [self.hostCollectionVC refreshHostCardForHost:host];
        }
    });
}

- (void) updateAllHosts:(NSArray *)hosts {
    // We must copy the array here because it could be modified
    // before our main thread dispatch happens.
    NSArray* hostsCopy = [NSArray arrayWithArray:hosts];
    dispatch_async(dispatch_get_main_queue(), ^{
        Log(LOG_D, @"New host list:");
        for (TemporaryHost* host in hostsCopy) {
            Log(LOG_D, @"Host: \n{\n\t name:%@ \n\t address:%@ \n\t localAddress:%@ \n\t externalAddress:%@ \n\t ipv6Address:%@ \n\t uuid:%@ \n\t mac:%@ \n\t pairState:%d \n\t online:%d \n\t activeAddress:%@ \n}", host.name, host.address, host.localAddress, host.externalAddress, host.ipv6Address, host.uuid, host.mac, host.pairState, host.state, host.activeAddress);
        }
        @synchronized(hostList) {
            [hostList removeAllObjects];
            [hostList addObjectsFromArray:hostsCopy];
        }
        [self updateHosts];
    });
}

- (void)updateHostShortcuts {
#if !TARGET_OS_TV
    NSMutableArray* quickActions = [[NSMutableArray alloc] init];
    
    @synchronized (hostList) {
        for (TemporaryHost* host in hostList) {
            // Pair state may be unknown if we haven't polled it yet, but the app list
            // count will persist from paired PCs
            if ([host.appList count] > 0) {
                UIApplicationShortcutItem* shortcut = [[UIApplicationShortcutItem alloc]
                                                       initWithType:@"PC"
                                                       localizedTitle:host.name
                                                       localizedSubtitle:nil
                                                       icon:[UIApplicationShortcutIcon iconWithType:UIApplicationShortcutIconTypePlay]
                                                       userInfo:[NSDictionary dictionaryWithObject:host.uuid forKey:@"UUID"]];
                [quickActions addObject: shortcut];
            }
        }
    }
    
    [UIApplication sharedApplication].shortcutItems = quickActions;
#endif
}

- (void)updateHosts {
    // Log(LOG_I, @"Updating hosts %f", CACurrentMediaTime());
    @synchronized (hostList) {
        // Sort the host list in alphabetical order
        NSArray* sortedHostList = [[hostList allObjects] sortedArrayUsingSelector:@selector(compareName:)];
        for (TemporaryHost* comp in sortedHostList) {
            
            // if(comp.state == StateOnline || comp.pairState == PairStatePaired || comp.pairState == PairStateUnknown) [self.hostCollectionVC addHost:comp];
            [self.hostCollectionVC addHost:comp];

            // Start jobs to decode the box art in advance
            for (TemporaryApp* app in comp.appList) {
                [_boxArtQueue addOperationWithBlock:^{
                    @autoreleasepool {
                        [self updateBoxArtCacheForApp:app];
                    }
                }];
            }
        }
    }
    
    // Create or delete host shortcuts as needed
    [self updateHostShortcuts];
    
    // Update the title in case we now have a PC
    // [self updateTitle];
    
    // Reset state first so we can rediscover hosts that were deleted before
    [_discMan resetDiscoveryState];
}

- (void) updateBoxArtCacheForApp:(TemporaryApp*)app {
    if ([_boxArtCache objectForKey:app] == nil) {
        UIImage* image = [AppAssetManager loadBoxArtForApp:app];
        if (image != nil) {
            // Add the image to our cache if it was present
            [_boxArtCache setObject:image forKey:app
                               cost:CGImageGetBytesPerRow(image.CGImage) * CGImageGetHeight(image.CGImage)];
        }
    }
}

- (void) updateAppsForHost:(TemporaryHost*)host {
    if (host != _selectedHost) {
        Log(LOG_W, @"Mismatched host during app update");
        return;
    }
    
    self.sortedAppList = [host.appList allObjects];
    self.sortedAppList = [self.sortedAppList sortedArrayUsingSelector:@selector(compareName:)];
    
    if (!_showHiddenApps) {
        NSMutableArray* visibleAppList = [NSMutableArray array];
        for (TemporaryApp* app in self.sortedAppList) {
            if (!app.hidden) {
                [visibleAppList addObject:app];
            }
        }
        self.sortedAppList = visibleAppList;
    }

    [self.collectionView reloadData];
    [self refreshAppCollectionLayout];
    [self refreshAppNavigationHighlight];
}

- (void)refreshAppNavigationHighlight {
    if (@available(iOS 13.0, *)) {
        if (ControllerNavigator.uiNavigationDelegate == self) {
            [ControllerNavigator restoreUINavigationHighlight];
        }
    }
}

- (bool)isInAppView{
    return !self.revealViewController.isStreaming && _enteredAppView;
}

- (bool)isStreaming{
    return self.revealViewController.isStreaming;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell* cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"AppCell" forIndexPath:indexPath];
    
    TemporaryApp* app = self.sortedAppList[indexPath.row];
    UIAppView* appView = [[UIAppView alloc] initWithApp:app cache:_boxArtCache andCallback:self];
    appView.updateLoopDelegate = (id<AppViewUpdateLoopDelegate>)self;
    
    if (appView.bounds.size.width > 10.0) {
        CGFloat scale = cell.bounds.size.width / appView.bounds.size.width;
        [appView setCenter:CGPointMake(appView.bounds.size.width / 2 * scale, appView.bounds.size.height / 2 * scale)];
        appView.transform = CGAffineTransformMakeScale(scale, scale); // view resize
    }
    
    [cell.subviews.firstObject removeFromSuperview]; // Remove a view that was previously added
    [cell addSubview:appView];
    // [self.settingsButton setEnabled:![self isIPhonePortrait]]; // update settings button after host is clicked & appview loaded
    // Shadow opacity is controlled inside UIAppView based on whether the app
    // is hidden or not during the update cycle.
    //UIBezierPath *shadowPath = [UIBezierPath bezierPathWithRect:cell.bounds];
    //cell.layer.masksToBounds = YES;
    //cell.layer.shadowColor = [UIColor blackColor].CGColor;
    //cell.layer.shadowOffset = CGSizeMake(1.0f, 5.0f);
    //cell.layer.shadowPath = shadowPath.CGPath;
    
#if !TARGET_OS_TV
    //cell.layer.borderWidth = 1;
    //cell.layer.borderColor = [[UIColor colorWithRed:0 green:0 blue:0 alpha:0.3f] CGColor];
    cell.exclusiveTouch = YES;
#endif

    return cell;
}

- (void)collectionView:(UICollectionView*)collectionView willDisplayCell:(UICollectionViewCell*)cell forItemAtIndexPath:(NSIndexPath*)indexPath {
    if (@available(iOS 13.0, *)) {
        [self applyAppNavigationHighlightToCell:cell atIndexPath:indexPath];
    }
}

- (CGSize)appCollectionCellSize {
    CGSize cellSize;
    UIScreen* referenceScreen = PublicUtils.isFoldableRAMCached ? UIScreen.screens.firstObject : [PublicUtils screenForView:self.viewIfLoaded];
    CGRect referenceBounds = [referenceScreen bounds];
    if(PublicUtils.isFoldableRAMCached || PublicUtils.isIPhone) cellSize.height = 0.365*MIN(referenceBounds.size.height,referenceBounds.size.width);
    else cellSize.height = 0.272*MIN(referenceBounds.size.height,referenceBounds.size.width);
    CGSize defaultSize = UIAppView.defaultSize;
    cellSize.width = cellSize.height * defaultSize.width / defaultSize.height;
    return cellSize;
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return [self appCollectionCellSize];
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1; // App collection only
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    if (_selectedHost != nil && self.sortedAppList != nil) {
        return self.sortedAppList.count;
    }
    else {
        return 0;
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
    // Purge the box art cache on low memory
    [_boxArtCache removeAllObjects];
}

- (UIView* )findMenuSeparator{
    BOOL shouldBreak = NO;
    UIView* seperator=self.view;
    while(seperator && !shouldBreak) {
        for(UIView* view in seperator.subviews) {
            if([view.accessibilityIdentifier isEqualToString:@"menuSeparator"]) {
                seperator = view;
                shouldBreak = YES;
                break;
            }
        }
        if (shouldBreak) break;
        seperator = seperator.superview;
    }
    return seperator;
}

- (void)handleMenuResize:(UILongPressGestureRecognizer *)gesture {
    CGPoint locationInView = [gesture locationInView:self.view];
    CGPoint locationInSuperView = [gesture locationInView:self.revealViewController.view];
    CGFloat screenHeight = [PublicUtils screenForView:self.viewIfLoaded].bounds.size.height;
    CGFloat screenWidth = [PublicUtils screenForView:self.viewIfLoaded].bounds.size.width;

    menuSeparator = [self findMenuSeparator];
    if(menuSeparator.hidden || menuSeparator == nil) return;

    if(gesture.state == UIGestureRecognizerStateBegan){
        if(locationInView.x < 30) {
            snapshot = [[UIView alloc] init];
            snapshot.backgroundColor = [UIColor systemBlueColor];
            screenHeight = [PublicUtils screenForView:self.viewIfLoaded].bounds.size.height;
            snapshot.frame = CGRectMake(locationInSuperView.x,0, 2, screenHeight);
            [self.revealViewController.view addSubview:snapshot];
        }
        return;
    }
    
    bool isPortrait = screenHeight>screenWidth;

    CGFloat limitedWidth = MIN(MAX(locationInSuperView.x, isPortrait ? 200 : 280),isPortrait ? screenWidth*0.75 : screenWidth/2);
    if(gesture.state == UIGestureRecognizerStateChanged){
        if(snapshot) snapshot.center = CGPointMake(limitedWidth, snapshot.center.y);
    }
    if(gesture.state == UIGestureRecognizerStateEnded){
        if(!snapshot) return;
        [snapshot removeFromSuperview];
        snapshot = nil;
        self.revealViewController.rearViewRevealWidth = limitedWidth;
        [self.revealViewController.view setNeedsLayout];
        [self.revealViewController.view layoutIfNeeded];
        [self.revealViewController setupNavigationBar];
        [self.revealViewController.view setNeedsLayout];
        [self.revealViewController.view layoutIfNeeded];
        if (@available(iOS 14.0, *)) {
            if (self.settingsViewController.usesSwiftUISettings) {
                [self.settingsViewController refreshSwiftUISettingsGeometry];
            }
        }
        if(self.revealViewController.isStreaming) [self.revealViewController buttonsInStreaming];
        else [self.revealViewController buttonsNotInStreaming];
        DataManager* dataMan = [[DataManager alloc] init];
        Settings* settings = [dataMan retrieveSettings];
        settings.settingsMenuWidth = [NSNumber numberWithFloat:self.revealViewController.rearViewRevealWidth];
        [dataMan saveData];



    }
}


- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [self.view endEditing:YES];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    /*
    NSLog(@"%f touchesMoved", CACurrentMediaTime());
    UITouch* touch = touches.anyObject;
    CGPoint touchPoint = [touch locationInView:self.view.superview];
    if(snapshot){
        snapshot.center = CGPointMake(touchPoint.x, snapshot.center.y);
    }
     */
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    [snapshot removeFromSuperview];
}


- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
    if (GenericUtils.autoPopSoftKeyboard) {
        return YES;
    } else {
        GenericUtils.autoPopSoftKeyboard = YES;
        return NO;
    }
}

#if !TARGET_OS_TV
- (BOOL)shouldAutorotate {
    return YES;
}
#endif

- (void) disableNavigation {
    self.navigationController.navigationBar.topItem.rightBarButtonItem.enabled = NO;
    self.navigationController.navigationBar.topItem.leftBarButtonItem.enabled = NO;
}

- (void) enableNavigation {
    self.navigationController.navigationBar.topItem.rightBarButtonItem.enabled = YES;
    self.navigationController.navigationBar.topItem.leftBarButtonItem.enabled = YES;
}

#if TARGET_OS_TV
- (BOOL)canBecomeFocused {
    return NO;
}

- (BOOL)shouldUpdateFocusInContext:(UIFocusUpdateContext *)context {
    NSLog(@"shouldUpdateFocusInContext .........");
    return context.nextFocusedItem == nil ||
        [NSStringFromClass([context.nextFocusedItem class]) containsString:@"VoidLinkFocusSinkView"];
}
#endif

- (void)didUpdateFocusInContext:(UIFocusUpdateContext *)context withAnimationCoordinator:(UIFocusAnimationCoordinator *)coordinator {
    
#if !TARGET_OS_TV
    if (context.nextFocusedView != nil) {
        [context.nextFocusedView setAlpha:0.8];
    }
    [context.previouslyFocusedView setAlpha:1.0];
#endif
}


- (CGSize)getHostCardSize{
    CGSize cardSize;
    UIScreen* referenceScreen = PublicUtils.isFoldableRAMCached ? UIScreen.screens.firstObject : [PublicUtils screenForView:self.viewIfLoaded];
    CGRect referenceBounds = [referenceScreen bounds];
    if(PublicUtils.isFoldableRAMCached || PublicUtils.isIPhone) cardSize.height = 0.37*MIN(referenceBounds.size.width, referenceBounds.size.height);
    else cardSize.height = 0.25*MIN(referenceBounds.size.width, referenceBounds.size.height);
    TemporaryHost* dummyHost = [[TemporaryHost alloc] init];
    HostCardView* dummyCard = [[HostCardView alloc] initWithHost:dummyHost];
    cardSize.width = cardSize.height * (dummyCard.size.width/dummyCard.size.height);
    // cardSize.width =
    return cardSize;
}

- (void)initHostCollection{
    // 初始化 HostCollectionViewController
    self.hostCollectionVC = [[HostCollectionViewController alloc] init];
    self.hostCollectionVC.deeplinkCoordinator = self.deeplinkCoordinator;
    self.hostCollectionVC.cellSize = [self getHostCardSize];
    self.hostCollectionVC.interItemMinimumSpacing = 25;
    self.hostCollectionVC.minimumLineSpacing = PublicUtils.isTVOS ? 49 : 25;
    // 添加为子控制器
    [self addChildViewController:self.hostCollectionVC];
    
    if(self.hostCollectionVC.view.superview == nil){
        [self.view addSubview:self.hostCollectionVC.view];
        CGFloat leftPadding = PublicUtils.isIPhone ? 30 : 0;
        CGFloat rightPadding = 0;
        if(PublicUtils.isFoldableIPhone) {
            leftPadding = 15;
            rightPadding = -15;
        }
        self.hostCollectionVC.view.translatesAutoresizingMaskIntoConstraints = NO;
        [NSLayoutConstraint activateConstraints:@[
            [self.hostCollectionVC.view.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:0],
            [self.hostCollectionVC.view.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:leftPadding],
            [self.hostCollectionVC.view.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:rightPadding],
        ]];
    }
    
    // 通知子控制器已添加完成
    [self.hostCollectionVC didMoveToParentViewController:self];

}

-(void) unregisterControllerCallbacks:(GCController*) controller
{
    if (controller != NULL) {
        controller.controllerPausedHandler = NULL;
        if (controller.extendedGamepad != NULL) {
            controller.extendedGamepad.valueChangedHandler = NULL;
        }
    }
}

- (void)controllerNavigatorDidSelectWithItem:(RadialMenuItem)item API_AVAILABLE(ios(13.0)){
    dispatch_async(dispatch_get_main_queue(), ^{
        switch (item) {
            case RadialMenuItemSettings:
                if(self.isStreaming && !self.settingsViewExpanded) [self->streamFrameViewController expandSettingsView];
                else [[self revealViewController] revealToggleAnimated:YES];
                break;
            case RadialMenuItemAllSettings:
                [self.revealViewController allSettingSelected];
                break;
            case RadialMenuItemFavoriteSettings:
                [self.revealViewController favoriteSettingSelected];
                break;
            case RadialMenuItemGameProfiles:
                if([GenericUtils isFirstTappingGameProfileSelectorFromMainFrame]){
                    DataManager* dataMan = [[DataManager alloc] init];
                    Settings* settings = [dataMan retrieveSettings];
                    NSString* edgeSide = settings.slideToSettingsScreenEdge.intValue != UIRectEdgeLeft ? [LocalizationHelper localizedStringForKey:@"left"] : [LocalizationHelper localizedStringForKey:@"right"];
                    NSString* slideDist = [NSString stringWithFormat:@"%d%%", (int)(settings.slideToSettingsDistance.floatValue*100)];
                    [AlertControllerUtil showAlertIn:self
                                               title:[LocalizationHelper localizedStringForKey:@"Game Profile"]
                                             message:[LocalizationHelper localizedStringForKey:@"gameProfileIntroduction", edgeSide, slideDist]
                                          withCancel:NO
                                         buttonTitle:[LocalizationHelper localizedStringForKey:@"Got it!"]
                                           countdown:6
                                              action:^{}
                                          completion:^{
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self openGameProfileSeletorWithAnimated:false];
                        });
                    }];
                }
                else [self openGameProfileSeletorWithAnimated:true];
                break;
            case RadialMenuItemHostView:
                [self switchToHostView];
                break;
            case RadialMenuItemAddHost:
                [self addHostTapped];
                break;
            case RadialMenuItemAboutView:
                [self helpButtonTapped];
                break;
            default:
                break;
        }
    });
}

- (void)controllerNavigatorDidSelectSettings {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[self revealViewController] revealToggleAnimated:YES];
    });
}

- (void)controllerNavigatorDidSelectGameProfiles {
    dispatch_async(dispatch_get_main_queue(), ^{
#if TARGET_OS_TV
        if(!self.gameProfileSelectorVC) [self openGameProfileSeletorWithAnimated:true];
        else [self.gameProfileSelectorVC dismissViewControllerAnimated:true completion:^{
            self.gameProfileSelectorVC = nil;
        }];
#else
        if(!self.gameProfileSelectorVC && !self.settingsViewController.layoutOnScreenControlsVC) [self openGameProfileSeletorWithAnimated:true];
        else if (self.gameProfileSelectorVC) [self.gameProfileSelectorVC.profileSelectorViewController dismissViewControllerAnimated:true completion:^{}];
        else if (self.settingsViewController.layoutOnScreenControlsVC) [self.settingsViewController.layoutOnScreenControlsVC.profileSelectorViewController dismissViewControllerAnimated:true completion:^{}];
#endif
    });
}

- (void)controllerNavigatorDidSelectHostView {
    [self switchToHostView];
}

- (void)controllerNavigatorDidSelectExit {
}

@end
