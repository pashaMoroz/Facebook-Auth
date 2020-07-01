//
//  ViewController.swift
//  Facebook Auth
//
//  Created by Pavel Moroz on 29.06.2020.
//  Copyright © 2020 Pavel Moroz. All rights reserved.
//

import UIKit
import FBSDKLoginKit
import FacebookCore
import StoreKit

class LoginViewController: UIViewController, IAPServiceDelegate {

    let loginButton = UIButton()
    let hellowLabel = UILabel()
    let purchaseButton = UIButton()

    var subscriptionDate: Date?

    let loginManager = LoginManager()

    override func viewDidLoad() {
        super.viewDidLoad()

        IAPService.shared.getProducts()
        IAPService.shared.iapServiceDelegate = self

        updateButton(isLoggedIn: (AccessToken.current != nil))
        updateMessage(with: Profile.current?.name)

        setupConstraints()
        setupElements()

        NotificationCenter.default.addObserver(forName: .AccessTokenDidChange, object: nil, queue: OperationQueue.main) { (notification) in

            // Print out access token
            print("FB Access Token: \(String(describing: AccessToken.current?.tokenString))")
        }

        IAPService.shared.refreshSubscriptionsStatus(callback: {

            print("ТРА ЛЯ ЛЯ")
           // let timeDate = UserDefaults.standard.object(forKey: IAPProduct.mainYearly.rawValue) as? Date
            
            self.subscriptionDate = IAPService.shared.expirationDateFor(IAPProduct.mainYearly.rawValue) ?? Date()
            self.checkForSubscriptionActivity()
            
        }) { (error) in
            
            print(error)
        }
    }


    private func setupConstraints() {

        hellowLabel.translatesAutoresizingMaskIntoConstraints = false
        loginButton.translatesAutoresizingMaskIntoConstraints = false
        purchaseButton.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(loginButton)
        view.addSubview(hellowLabel)
        view.addSubview(purchaseButton)

        let margineGuide = view.layoutMarginsGuide

        NSLayoutConstraint.activate([
            loginButton.centerYAnchor.constraint(equalTo: margineGuide.centerYAnchor),
            loginButton.centerXAnchor.constraint(equalTo: margineGuide.centerXAnchor),
        ])

        NSLayoutConstraint.activate([
            hellowLabel.bottomAnchor.constraint(equalTo: loginButton.topAnchor, constant: -50),
            hellowLabel.leadingAnchor.constraint(equalTo: margineGuide.leadingAnchor, constant: 16),
            hellowLabel.trailingAnchor.constraint(equalTo: margineGuide.trailingAnchor, constant: -16)
        ])

        NSLayoutConstraint.activate([
            purchaseButton.topAnchor.constraint(equalTo: loginButton.bottomAnchor, constant: 50),
            purchaseButton.leadingAnchor.constraint(equalTo: margineGuide.leadingAnchor, constant: 16),
            purchaseButton.trailingAnchor.constraint(equalTo: margineGuide.trailingAnchor, constant: -16)
        ])


    }


    private func setupElements() {

        hellowLabel.textColor = .black
        hellowLabel.textAlignment = .center
        hellowLabel.numberOfLines = 0

        loginButton.addTarget(self, action: #selector(loginButtonPressed), for: .touchUpInside)
        loginButton.setTitleColor(.black, for: .normal)

        purchaseButton.setTitleColor(.orange, for: .normal)
        purchaseButton.setTitle("КУПИТЬ ПОДПИСКУ", for: .normal)
        purchaseButton.addTarget(self, action: #selector(purchaseButtonPressed), for: .touchUpInside)

        self.view.backgroundColor = .systemBackground

    }

    @objc func loginButtonPressed() {

        if let _ = AccessToken.current {
            // Access token available -- user already logged in
            // Perform log out

            loginManager.logOut()
            updateButton(isLoggedIn: false)
            updateMessage(with: nil)
            loginManagerLogIn()

        } else {
            // Access token not available -- user already logged out
            // Perform log in
            loginManagerLogIn()

        }
    }

    @objc func purchaseButtonPressed() {
        IAPService.shared.purchase(product: .mainYearly)
    }
}

// MARK:- IAPServiceDelegate
extension LoginViewController {

    func successTransactions() {
        print(#function)
        checkForSubscriptionActivity()
    }

    func failedTransactions() {
         print(#function)
    }

    func failedRestored() {
         print(#function)
    }

    func successRestored() {
         print(#function)
    }
}

// MARK:- Private functions
extension LoginViewController {

    private func updateButton(isLoggedIn: Bool) {
        let title = isLoggedIn ? "Log out 👋🏻" : "Log in 👍🏻"
        loginButton.setTitle(title, for: .normal)
        if isLoggedIn {
            purchaseButton.isHidden = false
        } else {
            purchaseButton.isHidden = true
        }
    }

    private func updateMessage(with name: String?) {

        guard let name = name else {
            // User already logged out
            hellowLabel.text = "Please log in with Facebook."
            return
        }

        // User already logged in
        hellowLabel.text = "Hello, \(name)!"
    }
}

extension LoginViewController {

    private func loginManagerLogIn() {

        loginManager.logIn(permissions: [], from: self) { [weak self] (result, error) in

            // Check for error
            guard error == nil else {
                // Error occurred
                print(error!.localizedDescription)
                return
            }

            // Check for cancel
            guard let result = result, !result.isCancelled else {
                print("User cancelled login")
                return
            }

            // Successfully logged in
            self?.updateButton(isLoggedIn: true)

            Profile.loadCurrentProfile { (profile, error) in
                self?.updateMessage(with: Profile.current?.name)
            }
        }
    }

    private func checkForSubscriptionActivity() {

        guard let subscriptionDate = subscriptionDate else { return }
        
        let isActive = subscriptionDate > Date()

        if isActive {
            hellowLabel.text!  += "с активной подпиской"
        }
    }
}
