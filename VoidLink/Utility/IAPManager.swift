//
//  IAPManager.swift
//  VoidLink
//
//  Created by True砖家 on 2026/1/9.
//  Copyright © 2026 True砖家@Bilibili. All rights reserved.
//

import Foundation
import StoreKit
import UIKit

@objc public enum PurchaseStatus: Int {
    case notPurchased
    case purchased
    case revoked
}

@objc public enum PurchaseInterruption: Int {
    case unlockNow
    case restore
    case learnMore
    case lowOSVersion
}

@objc public class PurchaseInfo: NSObject {
    @objc public let valid: Bool
    @objc public let status: PurchaseStatus
    @objc public let expirationDate: NSDate?

    @objc public init(status: PurchaseStatus, expirationDate: NSDate?) {
        self.status = status
        self.expirationDate = expirationDate
        self.valid = (status == .purchased)
                      && (expirationDate?.timeIntervalSinceNow ?? .infinity > 0)
    }
}

@objc public enum AddOnProduct: UInt8, CaseIterable {
    case PencilProPack

    func productId() -> String {
        let bundleId = Bundle.main.bundleIdentifier ?? ""
        switch (self, bundleId) {
        case (.PencilProPack, "com.voidlink.iOS"):
            return "com.pencilpro.voidlink.iOS"
        case (.PencilProPack, "com.voidlinkextreme.iOS"):
            return "com.pencilpro.voidlinkextreme.iOS"
        case (.PencilProPack, "com.voidlink.tf.debug10.iOS"):
            return "com.pencilpro.voidlink.debug.iOS"
        case (.PencilProPack, "com.voidlink.tf.iOS"):
            return ""
        default:
            return ""
        }
    }
    
    func productName() -> String {
        switch self {
        case .PencilProPack:
            return LocalizationHelper.localizedString(forKey: "Drawing Toolkit")
        default:
            return ""
        }
    }
    
    func productURL() -> String {
        switch self {
        case .PencilProPack:
            return LocalizationHelper.localizedString(forKey: "PencilProPackURL")
        default:
            return ""
        }
    }
    
    func productDescription() -> String {
        switch self {
        case .PencilProPack:
            return LocalizationHelper.localizedString(forKey: "PencilProPackDescription")
        default:
            return ""
        }
    }
    
    func purchaseAbortedNotification() -> Notification.Name {
        switch self {
        case .PencilProPack:
            return Notification.Name("PencilProPurchaseAbortedNotification")
        default:
            return Notification.Name("")
        }
    }

    func purchaseSucceededNotification() -> Notification.Name {
        switch self {
        case .PencilProPack:
            return Notification.Name("PencilProPurchaseSucceededNotification")
        default:
            return Notification.Name("")
        }
    }
    
    static func from(productId: String) -> AddOnProduct? {
        switch productId {
        case "com.pencilpro.voidlink.iOS",
             "com.pencilpro.voidlinkextreme.iOS",
             "com.pencilpro.voidlink.debug.iOS",
             "com.pencilpro.voidlink.tf.iOS":
            return .PencilProPack
        default:
            return nil
        }
    }
}

@objc public protocol IAPManagerDelegate: NSObjectProtocol {
    @objc func iapManagerDidFetchProducts(_ products: [String])
    
    @objc func iapManagerDidFailWithError(_ error: Error)
    
    @objc func iapManagerDidPurchase(_ product: AddOnProduct)
    
    @objc func iapManagerDidRestore(_ product: AddOnProduct)
}

@objc public class IAPManager: NSObject {

    @objc public static let shared = IAPManager()
    @objc public weak var delegate: IAPManagerDelegate?
    @objc public private(set) var fetchedProductIds: [String] = []

    private override init() {
        super.init()
        if #available(iOS 15.0, *, *) {
            Task {
                await listenForTransactions()
            }
        }
        if #available(iOS 16.4, *) {
            Task {
                await listenForPurchaseIntents()
            }
        }
    }

    // MARK: - Fetch Products (StoreKit 2)

    @objc public func fetchProducts() {
        if #available(iOS 15.0, *, *) {
            Task {
                await fetchProductsStoreKit2()
            }
        } else {
            fetchProductsLegacy()
        }
    }

    @available(iOS 15.0, *, *)
    private func fetchProductsStoreKit2() async {
        let ids = Set(AddOnProduct.allCases.map { $0.productId() })
        do {
            let sk2Products = try await Product.products(for: ids)
            let idsFetched = sk2Products.map { $0.id }
            await MainActor.run {
                self.delegate?.iapManagerDidFetchProducts(idsFetched)
                self.fetchedProductIds = idsFetched
            }
        } catch {
            await MainActor.run {
                self.delegate?.iapManagerDidFailWithError(error)
            }
        }
    }
    
    @objc public var skProducts: [SKProduct] = []
    private var productsRequest: SKProductsRequest?
    private func fetchProductsLegacy() {
        let productIds = Set(AddOnProduct.allCases.map { $0.productId() })
        
        
        guard productsRequest == nil else { return }

        guard productIds.count>0 else { return }

        fetchedProductIds = Array(productIds)
        productsRequest = SKProductsRequest(
            productIdentifiers: productIds
        )
        productsRequest?.delegate = self
        productsRequest?.start()
    }


    // MARK: - Purchase (StoreKit 2)

    @objc public func purchase(_ product: AddOnProduct) {
        if #available(iOS 15.0, *, *) {
            Task {
                await purchaseStoreKit2(product)
            }
        } else {
            purchaseLegacy(product)
        }
    }

    @available(iOS 15.0, *, *)
    private func purchaseStoreKit2(_ product: AddOnProduct) async {
        guard IAPManager.canPurchase(product) else {
            AlertControllerUtil.showAlert(
                in: GenericUtils.topViewController(),
                title: "In-app-purchase not available".localized,
                message: "In-app-purchase not available on this device.".localized,
                withCancel: false,
                buttonTitle: "OK".localized,
                countdown: 6
                )
            return
        }

        let pid = product.productId()
        do {
            let products = try await Product.products(for: [pid])
            guard let sk2p = products.first else {
                throw NSError(
                    domain: "IAPManager",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Product not found"]
                )
            }

            let result = try await sk2p.purchase()
            await handleStoreKit2PurchaseResult(result, product: product)
        } catch {
            await MainActor.run {
                NotificationCenter.default.post(name: product.purchaseAbortedNotification(), object: PurchaseInterruption.unlockNow, userInfo:["interruption": PurchaseInterruption.unlockNow.rawValue])
                self.delegate?.iapManagerDidFailWithError(error)
            }
        }
    }

    private static func canPurchase(_ product: AddOnProduct) -> Bool {
        switch product {
        case .PencilProPack:
            return GenericUtils.isIPad()
        default:
            return true
        }
    }

    @available(iOS 15.0, *)
    private func handleStoreKit2PurchaseResult(_ result: Product.PurchaseResult,
                                               product: AddOnProduct) async {
        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                await MainActor.run {
                    self.delegate?.iapManagerDidPurchase(product)
                }
                await transaction.finish()
                IAPManager.handlePurchaseSuccess(product)
            case .unverified(_, let err):
                NotificationCenter.default.post(name: product.purchaseAbortedNotification(), object: PurchaseInterruption.unlockNow, userInfo:["interruption": PurchaseInterruption.unlockNow.rawValue])
                await MainActor.run {
                    self.delegate?.iapManagerDidFailWithError(err)
                }
            }
        case .userCancelled:
            NotificationCenter.default.post(name: product.purchaseAbortedNotification(), object: PurchaseInterruption.unlockNow, userInfo:["interruption": PurchaseInterruption.unlockNow.rawValue])
        default:
            NotificationCenter.default.post(name: product.purchaseAbortedNotification(), object: PurchaseInterruption.unlockNow, userInfo:["interruption": PurchaseInterruption.unlockNow.rawValue])
        }
    }

    @objc static func handlePurchaseSuccess(_ product: AddOnProduct) {
        switch product {
        case .PencilProPack:
            let dataMan = DataManager()
            let settings = dataMan.retrieveSettings()
            settings?.onscreenControls = 1
            settings?.pencilTickMode = NSNumber(value: PencilTickMode.ManualTick.rawValue)
            dataMan.saveData()
            let profileMan = OSCProfilesManager.sharedManager(.zero)
            var toolkitProfileIndex = profileMan.getIndex(byName: "Pencil Pro")
            if toolkitProfileIndex == nil {profileMan.importDefaultTemplates()}
            toolkitProfileIndex = profileMan.getIndex(byName: "Pencil Pro")
            profileMan.setProfileToSelected(toolkitProfileIndex ?? 1)
        default:
            break
        }
        NotificationCenter.default.post(name: product.purchaseSucceededNotification(), object: nil)
    }
    
    private func purchaseLegacy(_ product: AddOnProduct) {
        let productId = product.productId()
        print("products \(skProducts.count)")
        guard let skProduct = skProducts.first(
            where: {
                print("$0.productIdentifier \($0.productIdentifier), productId \(productId)")
                return $0.productIdentifier == productId
            }
        ) else { return }
        let payment = SKPayment(product: skProduct)
        SKPaymentQueue.default().add(payment)
    }
    
    // MARK: - Restore (StoreKit 2)

    @objc public func restorePurchasesStoreKit2() {
        if #available(iOS 15.0, *, *) {
            Task {
                await restoreStoreKit2()
            }
        }
        else{
            restorePurchasesLegacy()
        }
    }

    @available(iOS 15.0, *, *)
    private func restoreStoreKit2() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               let adp = AddOnProduct.from(productId: transaction.productID) {
                await MainActor.run {
                    self.delegate?.iapManagerDidRestore(adp)
                }
            }
        }
    }
    
    private func restorePurchasesLegacy() {
        SKPaymentQueue.default().restoreCompletedTransactions()
    }


    // MARK: - Listen update

    @available(iOS 15.0, *, *)
    private func listenForTransactions() async {
        for await verificationResult in Transaction.updates {
            if case .verified(let transaction) = verificationResult,
               let adp = AddOnProduct.from(productId: transaction.productID) {
                await MainActor.run {
                    // 这里把支付成功回调出来
                    self.delegate?.iapManagerDidPurchase(adp)
                }
                await transaction.finish()
            }
        }
    }

    @available(iOS 16.4, *)
    private func listenForPurchaseIntents() async {
        for await intent in PurchaseIntent.intents {
            guard let product = AddOnProduct.from(productId: intent.product.id) else {
                continue
            }
            guard IAPManager.canPurchase(product) else {
                continue
            }

            do {
                let result = try await intent.product.purchase()
                await handleStoreKit2PurchaseResult(result, product: product)
            } catch {
                await MainActor.run {
                    NotificationCenter.default.post(name: product.purchaseAbortedNotification(), object: PurchaseInterruption.unlockNow, userInfo:["interruption": PurchaseInterruption.unlockNow.rawValue])
                    self.delegate?.iapManagerDidFailWithError(error)
                }
            }
        }
    }
    
    // MARK: Utils
    @objc static public func checkPurchaseInfo(
        _ product: AddOnProduct,
        completion: @escaping (PurchaseInfo) -> Void
    ) {
        let productID = product.productId()
        if #available(iOS 15.0, *) {
            Task {
                var status: PurchaseStatus = .notPurchased
                var expiration: Date? = nil
                for await verificationResult in Transaction.currentEntitlements {
                    if case .verified(let transaction) = verificationResult,
                       transaction.productID == productID {
                        
                        // 有退款 / 撤销
                        if transaction.revocationDate != nil {
                            status = .revoked
                        } else {
                            status = .purchased
                            expiration = transaction.expirationDate
                        }
                        break
                    }
                }
                let info = PurchaseInfo(status: status, expirationDate: expiration as NSDate?)
                
                await MainActor.run {
                    completion(info)
                }
            }
        }
        else {
            NotificationCenter.default.post(name: product.purchaseAbortedNotification(), object: PurchaseInterruption.lowOSVersion, userInfo:["interruption": PurchaseInterruption.lowOSVersion.rawValue])
        }
    }
    
    @available(iOS 15.0, *)
    static public func checkPurchaseInfo(
        _ product: AddOnProduct
    ) async -> PurchaseInfo {
        await withCheckedContinuation { continuation in
            checkPurchaseInfo(product) { info in
                continuation.resume(returning: info)
            }
        }
    }
    
    @objc static public func inAppPurchaseAction(viewController: UIViewController, product: AddOnProduct){
        
        let alert = UIAlertController(title: product.productName(),
                                      message: LocalizationHelper.localizedString(forKey: "No purchase found", product.productName()),
                                      preferredStyle: .alert)

        let unlockAction = UIAlertAction(title: LocalizationHelper.localizedString(forKey: "Purchase Now"), style: .default) { _ in
            IAPManager.shared.purchase(product)
        }
        
        let restoreAction = UIAlertAction(title: LocalizationHelper.localizedString(forKey: "Restore Purchase"), style: .default) { _ in
            if #available(iOS 13.0, *) {
                Task{
                    do {
                        if #available(iOS 15.0, *) {
                            try await AppStore.sync()
                            IAPManager.checkPurchaseInfo(product) { info in
                                if info.valid {
                                    IAPManager.handlePurchaseSuccess(product)
                                    AlertControllerUtil.showAlert(
                                        in: viewController,
                                        title: "",
                                        message: LocalizationHelper.localizedString(forKey:"[%@] has been restored", product.productName()),
                                        withCancel: false,
                                        buttonTitle: "OK".localized,
                                        countdown: 0
                                        )
                                }
                                else {
                                    NotificationCenter.default.post(name: product.purchaseAbortedNotification(), object: PurchaseInterruption.restore, userInfo:["interruption": PurchaseInterruption.restore.rawValue])
                                    AlertControllerUtil.showAlert(
                                        in: viewController,
                                        title: "",
                                        message: LocalizationHelper.localizedString(forKey:"Unable to detect purchased product: %@", product.productName()),
                                        withCancel: false,
                                        buttonTitle: "OK".localized,
                                        countdown: 0
                                        )
                                }
                            }
                        }
                    } catch {
                        NotificationCenter.default.post(name: product.purchaseAbortedNotification(), object: PurchaseInterruption.restore, userInfo:["interruption": PurchaseInterruption.restore.rawValue])
                        print("Restore failed: \(error)")
                    }
                }
            } else {
                // Fallback on earlier versions
            }
        }
        
        let learnMoreAction = UIAlertAction(title: LocalizationHelper.localizedString(forKey: "Learn More"), style: .default) { _ in
            NotificationCenter.default.post(name: product.purchaseAbortedNotification(), object: PurchaseInterruption.learnMore, userInfo:["interruption": PurchaseInterruption.learnMore.rawValue])
            GenericUtils.openUrl(product.productURL())
            return
        }

        alert.addAction(unlockAction)
        alert.addAction(restoreAction)
        alert.addAction(learnMoreAction)

        viewController.present(alert, animated: true, completion: {
        })

    }
    
    @objc static public func inAppPurchaseURLMessage(viewController: UIViewController, product: AddOnProduct){
        return
    }
    
}


extension IAPManager: SKProductsRequestDelegate {
    public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        skProducts = response.products
        let productIds = Array(skProducts.map { $0.productIdentifier })
        delegate?.iapManagerDidFetchProducts(productIds)
    }
    
    public func request(_ request: SKRequest, didFailWithError error: Error) {
        delegate?.iapManagerDidFailWithError(error)
    }
}

extension IAPManager: SKPaymentTransactionObserver {

    public func paymentQueue(_ queue: SKPaymentQueue,
                             updatedTransactions transactions: [SKPaymentTransaction]) {

        print("paymentQueue \(CACurrentMediaTime())")

        for transaction in transactions {
            let productId = transaction.payment.productIdentifier
            guard let product = AddOnProduct.from(productId: productId) else {
                SKPaymentQueue.default().finishTransaction(transaction)
                continue
            }
            
            print("transaction.transactionState \(transaction.transactionState)")

            switch transaction.transactionState {

            case .purchased:
                delegate?.iapManagerDidPurchase(product)
                SKPaymentQueue.default().finishTransaction(transaction)

            case .restored:
                delegate?.iapManagerDidRestore(product)
                SKPaymentQueue.default().finishTransaction(transaction)

            case .failed:
                if let error = transaction.error {
                    delegate?.iapManagerDidFailWithError(error)
                }
                SKPaymentQueue.default().finishTransaction(transaction)

            default:
                break
            }
        }
    }
}
