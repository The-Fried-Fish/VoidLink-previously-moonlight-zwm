//
//  AboutView.swift
//  VoidLink
//
//  Created by True砖家 on 5/18/25.
//  Copyright © 2025 True砖家 @ Bilibili. All rights reserved.
//


import SwiftUI

@available(iOS 13.0, *)

public struct AboutView: View {
    @Environment(\.presentationMode) var presentationMode
    public var aboutVC:UIViewController

    public var body: some View {
        VStack(spacing: 7) {
            // App 图标
            Image(uiImage: UIImage(named: "AppIconMedium") ?? UIImage())
                // .resizable()
                .resizable(capInsets:EdgeInsets(top: 3.5, leading: 3.5, bottom: 3.5, trailing: 3.5))
                .frame(width: 90, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 28))

            // App 名称
            Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "App Name")
                .font(.title)
                .bold()

            // 版本号
            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                Text("Version \(version)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            if Locale.preferredLanguages.first!.hasPrefix("zh-Hans") {
                if #available(iOS 14.0, *) {
                    Text("闽ICP备17012590号-3A   主办单位：福州创图信息技术有限公司").font(.caption2)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .frame(maxWidth: 570) // ✅ 避免 Text 被拉得太宽无法换行
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
                .frame(maxWidth: 570) // ✅ 避免 Text 被拉得太宽无法换行
                .padding()

            
            Text(LocalizationHelper.localizedString(forKey: "VoidLink delivers better performance now!"))
                .multilineTextAlignment(.center)
                .font(Font.callout.bold())
                .lineLimit(nil)
                .frame(maxWidth: 570) // ✅ 避免 Text 被拉得太宽无法换行
            

            // 链接按钮
            if #available(iOS 14.0, *) {
                
                HStack(spacing: 20) {
                    Link(LocalizationHelper.localizedString(forKey: "Learn more"), destination: URL(string: LocalizationHelper.localizedString(forKey: "supportLink"))!)

                    if #available(iOS 16, *) {
                        let languageCode = Locale.current.language.languageCode?.identifier
                        if languageCode == "zh" {
                            Link(LocalizationHelper.localizedString(forKey: "加入QQ群"), destination: URL(string: LocalizationHelper.localizedString(forKey: "https://qm.qq.com/q/uM51CYWLS2"))!)
                        }
                    }
                    if GenericUtils.isIPhone() {
                        Link(LocalizationHelper.localizedString(forKey: "joinCommunity"), destination: URL(string: LocalizationHelper.localizedString(forKey: "communityLink"))!)
                    }
                }
                .padding(.top, 10)
                
                if !GenericUtils.isIPhone() {
                    Link(LocalizationHelper.localizedString(forKey: "joinCommunity"), destination: URL(string: LocalizationHelper.localizedString(forKey: "communityLink"))!)
                }

                // OK 按钮
                Button(LocalizationHelper.localizedString(forKey: "OK")) {
                    aboutVC.dismiss(animated:true)
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .frame(height: 46)
                .cornerRadius(12)
                .padding(.top, 10)
            } else {
                HStack(spacing: 20) {
                    Button(LocalizationHelper.localizedString(forKey: "Join us")) {
                        // 打开链接
                        if let url = URL(string: LocalizationHelper.localizedString(forKey: "supportLink")) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .frame(height: 33)
                    .frame(minWidth: 100)
                    /*
                    Button(LocalizationHelper.localizedString(forKey: "OK")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .frame(height: 33)
                    .frame(minWidth: 100)*/
                    Button(LocalizationHelper.localizedString(forKey: "OK")) {
                        aboutVC.dismiss(animated:true)
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .frame(height: 33)
                }
                .padding(.top, 10)
            }
        }
        .padding()
    }
}

