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

    public var body: some View {
        VStack(spacing: 10) {
            // App 图标
            Image(uiImage: UIImage(named: "AppIconMedium") ?? UIImage())
                // .resizable()
                .resizable(capInsets:EdgeInsets(top: 3.5, leading: 3.5, bottom: 3.5, trailing: 3.5))
                .frame(width: 100, height: 100)
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

            // 说明文字
            Text(SwiftLocalizationHelper.localizedString(forKey: "From the player community, to the player community."))
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .frame(maxWidth: 570) // ✅ 避免 Text 被拉得太宽无法换行
            
            if Locale.preferredLanguages.first!.hasPrefix("zh-Hans") {
                if #available(iOS 14.0, *) {
                    Text("闽ICP备17012590号-3A\n主办单位：福州创图信息技术有限公司").font(.caption2)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .frame(maxWidth: 570) // ✅ 避免 Text 被拉得太宽无法换行
                        .padding()
                } else {
                    Text("闽ICP备17012590号-3A\n主办单位：福州创图信息技术有限公司").font(.caption)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .frame(maxWidth: 570) // ✅ 避免 Text 被拉得太宽无法换行
                        .padding()
                }
            }
            // 链接按钮
            if #available(iOS 14.0, *) {
                Link(SwiftLocalizationHelper.localizedString(forKey: "Join us"), destination: URL(string: SwiftLocalizationHelper.localizedString(forKey: "supportLink"))!)
                    .padding(.top, 10)
                Spacer()
                // OK 按钮
                Button(SwiftLocalizationHelper.localizedString(forKey: "OK")) {
                    presentationMode.wrappedValue.dismiss()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .frame(height: 46)
                //.frame(width: 100)
                .cornerRadius(12)
            } else {
                HStack(spacing: 20) {
                    Button(SwiftLocalizationHelper.localizedString(forKey: "Join us")) {
                        // 打开链接
                        if let url = URL(string: SwiftLocalizationHelper.localizedString(forKey: "supportLink")) {
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
                    Button(SwiftLocalizationHelper.localizedString(forKey: "OK")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .frame(height: 33)
                    .frame(minWidth: 100)*/
                }
                .padding(.top, 10)
            }
        }
        .padding()
    }
}
