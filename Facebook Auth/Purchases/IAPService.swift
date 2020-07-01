import StoreKit

protocol IAPServiceDelegate: class {
    func successTransactions()
    func failedTransactions()
    func failedRestored()
    func successRestored()
}

extension SKProduct {
    fileprivate static var formatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter
    }

    var localizedPrice: String {
        if self.price == 0.00 {
            return "Get"
        } else {
            let formatter = SKProduct.formatter
            formatter.locale = self.priceLocale

            guard let formattedPrice = formatter.string(from: self.price) else {
                return "Unknown Price"
            }

            return formattedPrice
        }
    }
}

class IAPService: NSObject {

    public typealias SuccessBlock = () -> Void
    public typealias FailureBlock = (Error?) -> Void

    private override init() {}
    static let shared = IAPService()

    let paymentQueue = SKPaymentQueue.default()

    let productId = "1521619145"

    private var sharedSecret = "4520e92f375e43419a8eb6bcbd9f0026"

    var productPrice: String?
    var products: [SKProduct] = []

    private var refreshSubscriptionSuccessBlock : SuccessBlock?
    private var refreshSubscriptionFailureBlock : FailureBlock?

    private var successBlock : SuccessBlock?
    private var failureBlock : FailureBlock?

    weak var iapServiceDelegate: IAPServiceDelegate?

    func getProducts() {

        let products: Set = [IAPProduct.mainYearly.rawValue]
        let request = SKProductsRequest(productIdentifiers: products)
        request.delegate = self
        request.start()
        paymentQueue.add(self)
    }

    func purchase(product:  IAPProduct) {

        guard let productToPurchase = products.filter({$0.productIdentifier == product.rawValue}).first else { return }

        if SKPaymentQueue.canMakePayments() {
            let paymentRequest = SKMutablePayment()
            paymentRequest.productIdentifier = productToPurchase.productIdentifier

            SKPaymentQueue.default().add(paymentRequest)
        }
    }

    func restorePurchases() {
        print("restoring purchases")
        if SKPaymentQueue.canMakePayments() {
            paymentQueue.restoreCompletedTransactions()
        }
    }
}


extension IAPService: SKProductsRequestDelegate {

    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        self.products = response.products
        for product in response.products {
            print(product.localizedTitle)
            //for nonConsumable
            productPrice = product.localizedPrice
        }
    }
}

extension IAPService: SKPaymentTransactionObserver {

    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {

        for transaction in transactions {
            print(transaction.transactionState.status(), transaction.payment.productIdentifier)

            switch transaction.transactionState {
            case .purchasing: break
            case .purchased:
                UserDefaults.standard.set(true, forKey: IAPProduct.mainYearly.rawValue)

                iapServiceDelegate?.successTransactions()
                queue.finishTransaction(transaction)

            case .restored:
                iapServiceDelegate?.successRestored()
                queue.finishTransaction(transaction)


            default: queue.finishTransaction(transaction)

            }

            if transaction.transactionState == .failed {
                guard let error = transaction.error else { return }
                iapServiceDelegate?.failedTransactions()
                queue.finishTransaction(transaction)
                print(error.localizedDescription)
            }
        }
    }

    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {

        iapServiceDelegate?.failedRestored()
    }

    func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        iapServiceDelegate?.failedTransactions()
    }

}

extension SKPaymentTransactionState {

    func status() -> String {
        switch self {
        case .deferred: return "deferred"
        case .failed: return "failed"
        case .purchased: return "purchased"
        case .purchasing: return "purchasing"
        case .restored: return "restored"
        @unknown default:
            fatalError()
        }
    }
}

extension IAPService {
    func refreshSubscriptionsStatus(callback : @escaping SuccessBlock, failure : @escaping FailureBlock){
        // save blocks for further use
        self.refreshSubscriptionSuccessBlock = callback
        self.refreshSubscriptionFailureBlock = failure
        guard let receiptUrl = Bundle.main.appStoreReceiptURL else {
            refreshReceipt()
            // do not call block yet
            return
        }
        #if DEBUG
        let urlString = "https://sandbox.itunes.apple.com/verifyReceipt"
        #else
        let urlString = "https://buy.itunes.apple.com/verifyReceipt"
        #endif
        let receiptData = try? Data(contentsOf: receiptUrl).base64EncodedString()
        let requestData = ["receipt-data" : receiptData ?? "", "password" : self.sharedSecret, "exclude-old-transactions" : true] as [String : Any]
        var request = URLRequest(url: URL(string: urlString)!)
        request.httpMethod = "POST"
        request.setValue("Application/json", forHTTPHeaderField: "Content-Type")
        let httpBody = try? JSONSerialization.data(withJSONObject: requestData, options: [])
        request.httpBody = httpBody
        URLSession.shared.dataTask(with: request)  { (data, response, error) in
            DispatchQueue.main.async {
                if data != nil {
                    if let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments){
                        self.parseReceipt(json as! Dictionary<String, Any>)
                        return
                    }
                } else {
                    print("error validating receipt: \(error?.localizedDescription ?? "")")
                }
                self.refreshSubscriptionFailureBlock?(error)
                self.cleanUpRefeshReceiptBlocks()
            }
        }.resume()
    }

    private func refreshReceipt(){
        let request = SKReceiptRefreshRequest(receiptProperties: nil)
        request.delegate = self
        request.start()
    }

    func requestDidFinish(_ request: SKRequest) {
        // call refresh subscriptions method again with same blocks
        if request is SKReceiptRefreshRequest {
            refreshSubscriptionsStatus(callback: self.successBlock ?? {}, failure: self.failureBlock ?? {_ in})
        }
    }

    func request(_ request: SKRequest, didFailWithError error: Error){
        if request is SKReceiptRefreshRequest {
            self.refreshSubscriptionFailureBlock?(error)
            self.cleanUpRefeshReceiptBlocks()
        }
        print("error: \(error.localizedDescription)")
    }

    private func parseReceipt(_ json : Dictionary<String, Any>) {
        // It's the most simple way to get latest expiration date. Consider this code as for learning purposes. Do not use current code in production apps.

        guard let receipts_array = json["latest_receipt_info"] as? [Dictionary<String, Any>] else {
            self.refreshSubscriptionFailureBlock?(nil)
            self.cleanUpRefeshReceiptBlocks()
            return
        }
        
        for receipt in receipts_array {
            let productID = receipt["product_id"] as! String
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss VV"
            if let date = formatter.date(from: receipt["expires_date"] as! String) {

                if date > Date() {
                    // do not save expired date to user defaults to avoid overwriting with expired date
                    
                    UserDefaults.standard.set(date, forKey: productID)
                }
            }
        }
        self.refreshSubscriptionSuccessBlock?()
        self.cleanUpRefeshReceiptBlocks()
    }

    private func cleanUpRefeshReceiptBlocks(){
        self.refreshSubscriptionSuccessBlock = nil
        self.refreshSubscriptionFailureBlock = nil
    }
}


extension IAPService {

    func expirationDateFor(_ identifier : String) -> Date?{
        
            return UserDefaults.standard.object(forKey: identifier) as? Date
        }

}
