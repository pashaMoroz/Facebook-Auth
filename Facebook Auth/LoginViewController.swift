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

class LoginViewController: UIViewController {

    let loginButton = UIButton()
    let hellowLabel = UILabel()
    let purchaseButton = UIButton()
    let restoredButton = UIButton()

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
           // print("FB Access Token: \(String(describing: AccessToken.current?.tokenString))")
        }

        refreshSubscriptionsStatus()
    }

    deinit {
       NotificationCenter.default.removeObserver(self)
    }


    // MARK:- SETUP UI
    private func setupConstraints() {

        hellowLabel.translatesAutoresizingMaskIntoConstraints = false
        loginButton.translatesAutoresizingMaskIntoConstraints = false
        purchaseButton.translatesAutoresizingMaskIntoConstraints = false
        restoredButton.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(loginButton)
        view.addSubview(hellowLabel)
        view.addSubview(purchaseButton)
        view.addSubview(restoredButton)

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

        NSLayoutConstraint.activate([
            restoredButton.topAnchor.constraint(equalTo: purchaseButton.bottomAnchor, constant: 10),
            restoredButton.leadingAnchor.constraint(equalTo: margineGuide.leadingAnchor, constant: 16),
            restoredButton.trailingAnchor.constraint(equalTo: margineGuide.trailingAnchor, constant: -16)
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

        restoredButton.setTitleColor(.orange, for: .normal)
        restoredButton.setTitle("ВОССТАНОВИТЬ ПОДПИСКУ", for: .normal)
        restoredButton.addTarget(self, action: #selector(restoredButtonPressed), for: .touchUpInside)

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

    // MARK:- Objc методы

    @objc func purchaseButtonPressed() {

        IAPService.shared.purchase(product: .mainYearly)
    }

    @objc func restoredButtonPressed() {

        IAPService.shared.restorePurchases()
    }

    private func showAlert(text: String, title: String) {
        let alert = UIAlertController(title: title, message: text, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
        let cancelAction = UIAlertAction(title: "Cancel", style: .destructive, handler: nil)
        alert.addAction(cancelAction)
        alert.addAction(okAction)
        self.present(alert, animated: true, completion: nil)
    }
}

// MARK:- IAPServiceDelegate
extension LoginViewController: IAPServiceDelegate {

    func successTransactions() {
        print(#function)

        refreshSubscriptionsStatus()
        //showAlert(text: "Спасибо за покупку!", title: "Подписка активна на 3 минуты!")
    }

    func failedTransactions() {
         print(#function)
        
        //refreshSubscriptionsStatus()
        showAlert(text: "Ошибка транзакции", title: "Ошибка")
    }

    func failedRestored() {
         print(#function)
        refreshSubscriptionsStatus()
        //showAlert(text: "Нечего восстанавливать", title: "Нет активной подписки")
    }

    func successRestored() {
         print(#function)

        refreshSubscriptionsStatus()
        //showAlert(text: "Покупка успешно восстановлена", title: "Подписка активирована!")
    }
}


// MARK:- Private functions UI
extension LoginViewController {

    private func updateButton(isLoggedIn: Bool) {
        let title = isLoggedIn ? "Log out 👋🏻" : "Log in 👍🏻"
        loginButton.setTitle(title, for: .normal)


        hiddenButtons(status: isLoggedIn)
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

// MARK:- Private functions FB

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

    // MARK:- Private functions Purcheses

    private func checkForSubscriptionActivity() {

        if subscriptionDate == nil {
            showAlert(text: "Ошибка!", title: "Подписка НЕ активна!")
        } else {

            let isActive = subscriptionDate! > Date()

            hiddenButtons(status: isActive)

            if isActive {
  //              showAlert(text: "Успех!", title: "Подписка активна!")
            } else {
                showAlert(text: "Ошибка!", title: "Подписка НЕ активна!")
            }
        }
    }

    private func refreshSubscriptionsStatus() {

        IAPService.shared.refreshSubscriptionsStatus(callback: {

            //print(#function)

            self.subscriptionDate = UserDefaults.standard.object(forKey: IAPProduct.mainYearly.rawValue) as? Date

            self.checkForSubscriptionActivity()

        }) { (error) in

            print(error)
        }
    }

    private func hiddenButtons( status: Bool ) {

        if status {
            purchaseButton.isHidden = true
            restoredButton.isHidden = true
        } else {
            purchaseButton.isHidden = false
            restoredButton.isHidden = false
        }
    }
}
