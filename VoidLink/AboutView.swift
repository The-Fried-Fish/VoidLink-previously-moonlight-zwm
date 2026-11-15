//
//  AboutView.swift
//  VoidLink
//
//  Created by True砖家 on 5/18/25.
//  Copyright © 2025 True砖家 @ Bilibili. All rights reserved.
//


import SwiftUI

@available(iOS 13.0, *)
private extension View {
    @ViewBuilder
    func paddingWhenNotTVOS() -> some View {
        if !PublicUtils.isTVOS {
            self.padding()
        } else {
            self
        }
    }
}

@available(iOS 13.0, *)

public struct AboutView: View {
    @Environment(\.presentationMode) var presentationMode
    
    public var iconSize: CGFloat = PublicUtils.isTVOS ? 150 : 90

    public var aboutVC:UIViewController
    
    public var body: some View {
        VStack(spacing: PublicUtils.isTVOS ? 15 : 7) {
            // App 图标
            Image(uiImage: UIImage(named: "AppIconMedium") ?? UIImage())
                // .resizable()
                .resizable(capInsets:EdgeInsets(top: 3.5, leading: 3.5, bottom: 3.5, trailing: 3.5))
                .frame(width: iconSize, height: iconSize)
                .clipShape(RoundedRectangle(cornerRadius: 28))

            // App 名称
            #if os(tvOS)
            Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "App Name")
                .font(.title3)
                .bold()
            #else
            Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "App Name")
                .font(.title)
                .bold()
            #endif
            

            // 版本号
            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                Text("Version \(version)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            if PublicUtils.isZhHans {
                if #available(iOS 14.0, *) {
                    Text("闽ICP备17012590号-3A   主办单位：福州创图信息技术有限公司").font(.caption2)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .frame(maxWidth: PublicUtils.isTVOS ? 760 : 570) // ✅ 避免 Text 被拉得太宽无法换行
                        //.padding()
                } else {
                    Text("闽ICP备17012590号-3A   主办单位：福州创图信息技术有限公司").font(.caption)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .frame(maxWidth: 570) // ✅ 避免 Text 被拉得太宽无法换行
                        //.padding()
                }
            }
            
            // 说明文字
            Text(LocalizationHelper.localizedString(forKey: "From the player community, to the player community."))
                .multilineTextAlignment(.center)
                .font(Font.caption.italic())
                .lineLimit(nil)
                .frame(maxWidth:PublicUtils.isTVOS ? 760 : 570) // ✅ 避免 Text 被拉得太宽无法换行
                .paddingWhenNotTVOS()

            if !PublicUtils.isTVOS {
                Text(LocalizationHelper.localizedString(forKey: "VoidLink delivers better performance now!"))
                    .multilineTextAlignment(.center)
                    .font(Font.callout.bold())
                    .lineLimit(nil)
                    .frame(maxWidth: PublicUtils.isTVOS ? 760 : 570) // ✅ 避免 Text 被拉得太宽无法换行
                
                // 链接按钮
                if #available(iOS 14.0, *) {
                    
                    HStack(spacing: 20) {
                        Link(LocalizationHelper.localizedString(forKey: "Learn more"), destination: URL(string: LocalizationHelper.localizedString(forKey: "supportLink"))!)
                        
                        if #available(iOS 16, *) {
                            let languageCode = Locale.current.language.languageCode?.identifier
                            if languageCode == "zh" {
                                Link(LocalizationHelper.localizedString(forKey: "加入QQ群"), destination: URL(string: "https://voidlink.yuque.com/org-wiki-voidlink-znirha/biuzs1/qbnhtdnpwne0m83r")!)
                            }
                        }
                        if PublicUtils.isIPhone {
                            Link(LocalizationHelper.localizedString(forKey: "joinCommunity"), destination: URL(string: LocalizationHelper.localizedString(forKey: "communityLink"))!)
                        }
                    }
                    .padding(.top, 10)
                    
                    if !PublicUtils.isIPhone {
                        Link(LocalizationHelper.localizedString(forKey: "joinCommunity"), destination: URL(string: LocalizationHelper.localizedString(forKey: "communityLink"))!)
                    }
                    
                    HStack(spacing: 15) {
                        // Xcode 27 can infer TupleContent here, which is unavailable on
                        // older systems. Keep the stack's content explicitly TupleView.
                        TupleView((artistPurchaseButton, dismissButton))
                    }
                    
                    
                } else {
                    HStack(spacing: 20) {
                        // Xcode 27 may select TupleContent in this fallback branch.
                        // Its type is resolved on iOS 15 even though the branch is unused.
                        TupleView((legacyJoinButton, legacyDismissButton))
                    }
                    .padding(.top, 10)
                }
            }
        }
        .padding()
    }

    @available(iOS 14.0, *)
    @ViewBuilder
    private var artistPurchaseButton: some View {
        if #available(iOS 15.0, *) {
            if PublicUtils.isIPad, PublicUtils.isIAPAddonAvailable {
                Button(LocalizationHelper.localizedString(forKey: "I'm an artist")) {
                    IAPManager.checkPurchaseInfo(.PencilProPack) { info in
                        if !info.valid {
                            IAPManager.inAppPurchaseAction(viewController: self.aboutVC, product: .PencilProPack)
                        }
                        else {
                            AlertControllerUtil.showAlert(
                                in: self.aboutVC,
                                title: "",
                                message: LocalizationHelper.localizedString(forKey:"Drawing Toolkit already purchased"),
                                withCancel: false,
                                buttonTitle: LocalizationHelper.localizedString(forKey: "OK"),
                                countdown: 0)
                        }
                    }
                }
                .padding()
                .background(Color.blue.opacity(1))
                .foregroundColor(.white)
                .frame(height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.top, 10)
            }
        }
    }

    @available(iOS 14.0, *)
    private var dismissButton: some View {
        Button(LocalizationHelper.localizedString(forKey: "OK")) {
            aboutVC.dismiss(animated:true)
        }
        .padding()
        .background(Color.blue)
        .foregroundColor(.white)
        .frame(height: 46)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.top, 10)
    }

    private var legacyJoinButton: some View {
        Button(LocalizationHelper.localizedString(forKey: "Join us")) {
            // 打开链接
            if let url = URL(string: LocalizationHelper.localizedString(forKey: "supportLink")) {
                UIApplication.shared.open(url)
            }
        }
        .padding()
        .background(Color.blue)
        .foregroundColor(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .frame(height: 33)
        .frame(minWidth: 100)
    }

    private var legacyDismissButton: some View {
        Button(LocalizationHelper.localizedString(forKey: "OK")) {
            aboutVC.dismiss(animated:true)
        }
        .padding()
        .background(Color.blue)
        .foregroundColor(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .frame(height: 33)
    }
}
