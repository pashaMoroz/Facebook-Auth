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

class LoginViewController: UIViewController {

    let loginButton = UIButton()
    let hellowLabel = UILabel()

    let loginManager = LoginManager()

    override func viewDidLoad() {
        super.viewDidLoad()

        updateButton(isLoggedIn: (AccessToken.current != nil))
        updateMessage(with: Profile.current?.name)

        setupConstraints()
        setupElements()

        NotificationCenter.default.addObserver(forName: .AccessTokenDidChange, object: nil, queue: OperationQueue.main) { (notification) in

            // Print out access token
            print("FB Access Token: \(String(describing: AccessToken.current?.tokenString))")
        }
    }


    private func setupConstraints() {

        hellowLabel.translatesAutoresizingMaskIntoConstraints = false
        loginButton.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(loginButton)
        view.addSubview(hellowLabel)

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
    }


    private func setupElements() {

        hellowLabel.textColor = .black
        hellowLabel.textAlignment = .center

        loginButton.addTarget(self, action: #selector(loginButtonPressed), for: .touchUpInside)
        loginButton.setTitleColor(.black, for: .normal)

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
}

// MARK:- Private functions
extension LoginViewController {

    private func updateButton(isLoggedIn: Bool) {
        let title = isLoggedIn ? "Log out 👋🏻" : "Log in 👍🏻"
        loginButton.setTitle(title, for: .normal)
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
}
