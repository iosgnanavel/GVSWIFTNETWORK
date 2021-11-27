//
//  ViewController.swift
//  GVSwiftNetwork
//
//  Created by santhosh on 11/27/2021.
//  Copyright (c) 2021 santhosh. All rights reserved.
//

import UIKit
import GVSwiftNetwork

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        GVSwiftNetwork.SwiftNetworkClientAPI.basePath = ""
        // Loader Start
        UserAPI.loginUser(username: "userName", password: "password", deviceID: "deviceID") { (response, error) in
            guard let userDetails = response else {
                guard let errorMessage = error?.localizedDescription else {
                    print("Something went wrong, Please try again.")
                    // Loader Stop
                    return
                }
                // Display the Error Alert message
                print("error: \(errorMessage)")
                // Loader Stop
                return
            }
            print("response: \(userDetails)")
            // Loader Stop
        }
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

