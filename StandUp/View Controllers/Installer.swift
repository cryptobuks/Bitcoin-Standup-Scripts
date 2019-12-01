//
//  Installer.swift
//  StandUp
//
//  Created by Peter on 07/10/19.
//  Copyright © 2019 Peter. All rights reserved.
//

import Cocoa

class Installer: NSViewController {
    
    @IBOutlet var spinner: NSProgressIndicator!
    @IBOutlet var spinnerDescription: NSTextField!
    @IBOutlet var backButtonOutlet: NSButton!
    @IBOutlet var consoleOutput: NSTextView!
    let ud = UserDefaults.standard
    var seeLog = Bool()
    var standingUp = Bool()
    var args = [String]()
    var standingDown = Bool()
    var upgrading = Bool()
    var standUpConf = ""
    var refreshing = Bool()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setScene()
        filterAction()
        
    }
    
    func showSpinner(description: String) {
        
        DispatchQueue.main.async {
            self.spinner.alphaValue = 1
            self.spinnerDescription.stringValue = description
            self.spinner.startAnimation(self)
            self.spinnerDescription.alphaValue = 1
        }
        
    }
    
    func getURLs() {
        
        showSpinner(description: "Fetching latest Bitcoin Core version and URL's...")
        let request = FetchJSON()
        request.getRequest { (dict, error) in
            
            if error != "" {
                
                self.hideSpinner()
                setSimpleAlert(message: "Error", info: "There was an error fetching the latest Bitcoin Core version number and related URL's, please check your internet connection and try again", buttonLabel: "OK")
                
            } else {
                
                let binaryName = dict!["macosBinary"] as! String
                let macosURL = dict!["macosURL"] as! String
                let shaURL = dict!["shaURL"] as! String
                let version = dict!["version"] as! String
                let prefix = dict!["binaryPrefix"] as! String
                self.showSpinner(description: "Setting Up...")
                
                if self.upgrading {

                    self.upgradeBitcoinCore(binaryName: binaryName, macosURL: macosURL, shaURL: shaURL, version: version, prefix: prefix)

                } else {

                    self.standUp(binaryName: binaryName, macosURL: macosURL, shaURL: shaURL, version: version, prefix: prefix)

                }
                
            }
            
        }
        
    }
    
    func filterAction() {
        
        var desc = ""
        
        if seeLog {

            spinner.alphaValue = 0
            seeLog = false
            getLog { (log) in
                DispatchQueue.main.async {
                    self.consoleOutput.string = log
                }
            }
            
            DispatchQueue.main.async {
                self.backButtonOutlet.isEnabled = true
            }

        } else if standingUp {

            standingUp = false
            checkExistingConf()

        } else if standingDown {

            standingDown = false
            spinner.startAnimation(self)
            desc = "Standing Down..."
            standDown()

        } else if upgrading {
            
            getURLs()

        } else if refreshing {
            
            refreshing = false
            refreshHS()
            
        }
        
        DispatchQueue.main.async {
            
            self.spinnerDescription.stringValue = desc
            
        }
        
    }
    
    @IBAction func backAction(_ sender: Any) {
        
        goBack()
        
    }
    
    func goBack() {
        print("go back")
        
        DispatchQueue.main.async {
            
            self.hideSpinner()
            
            if let presenter = self.presentingViewController as? ViewController {
                
                presenter.standingUp = false
                presenter.isBitcoinOn()
                
            }
            
            DispatchQueue.main.async {
                
                self.dismiss(self)
                
            }
            
        }
        
    }
    
    func checkExistingConf() {
        
        let d = Defaults()
        var userExists = false
        var passwordExists = false
        var testnetExists = false
        var proxyExists = false
        var debugExists = false
        var bindExists = false
        var listenExists = false
        
        getBitcoinConf { (conf, error) in
            
            print("exisiting conf = \(conf)")
            
            if !error {
                
                if conf.count > 0 {
                    
                    for setting in conf {
                        
                        if setting.contains("=") {
                            
                            let arr = setting.components(separatedBy: "=")
                            let k = arr[0]
                            let existingValue = arr[1]
                            
                            switch k {
                            case "rpcuser":
                                
                                if existingValue != "" {
                                    
                                    userExists = true
                                }
                                
                            case "rpcpassword":
                                
                                if existingValue != "" {
                                    
                                    passwordExists = true
                                    
                                }
                                
                            case "testnet":
                                
                                if existingValue != "" {
                                    
                                    testnetExists = true
                                    
                                }
                                
                            case "proxy":
                                
                                proxyExists = true
                                
                            case "listen":
                                
                                listenExists = true
                                
                            case "bindaddress":
                                
                                bindExists = true
                                
                            case "debug":
                                
                                debugExists = true
                                
                            default:
                                break
                            }
                            
                        }
                        
                    }
                    
                    if userExists && passwordExists {
                        
                        // just use exisiting conf as is
                        self.standUpConf = conf.joined(separator: "\n")
                        
                    } else if userExists && !passwordExists {
                        
                        self.standUpConf = "rpcpassword=\(randomString(length: 32))\n" + conf.joined(separator: "\n")
                        
                    } else if passwordExists && !userExists {
                        
                        self.standUpConf = "rpcuser=\(randomString(length: 10))\n" + conf.joined(separator: "\n")
                        
                    } else {
                        
                        // add rpcuser and rpcpassword
                        self.standUpConf = "rpcuser=\(randomString(length: 10))\nrpcpassword=\(randomString(length: 32))\n" + conf.joined(separator: "\n")
                        
                    }
                    
                    if !testnetExists {
                        
                        self.standUpConf = "testnet=\(d.testnet())\n" + self.standUpConf + "\n"
                        
                    }
                    
                    if !debugExists {
                        
                        self.standUpConf = "#debug=tor\n" + self.standUpConf + "\n"
                    }
                    
                    if !proxyExists {
                        
                        self.standUpConf = "#proxy=127.0.0.1:9050\n" + self.standUpConf + "\n"
                        
                    }
                    
                    if !listenExists {
                        
                        self.standUpConf = "#listen=1\n" + self.standUpConf + "\n"
                        
                    }
                    
                    if !bindExists {
                        
                        self.standUpConf = "#bindaddress=127.0.0.1\n" + self.standUpConf + "\n"
                        
                    }
                    
                    self.getURLs()
                    
                } else {
                    
                    //no exisiting settings - use default
                    
                    let prune = self.ud.object(forKey: "pruned") as? Int ?? 0
                    let txindex = self.ud.object(forKey: "txindex") as? Int ?? 1
                    let walletDisabled = self.ud.object(forKey: "walletDisabled") as? Int ?? 0
                    
                    self.standUpConf = "testnet=\(d.testnet())\ndisablewallet=\(walletDisabled)\nrpcuser=\(randomString(length: 10))\nrpcpassword=\(randomString(length: 32))\nserver=1\nprune=\(prune)\ntxindex=\(txindex)\nrpcallowip=127.0.0.1\nbindaddress=127.0.0.1\nproxy=127.0.0.1:9050\nlisten=1\ndebug=tor\n[main]\nrpcport=8332\n[test]\nrpcport=18332\n[regtest]\nrpcport=18443"
                    
                    self.getURLs()
                    
                }
                
            }
            
        }
        
    }
    
    func standDown() {
        
        let runBuildTask = RunBuildTask()
        runBuildTask.showLog = true
        runBuildTask.args = []
        runBuildTask.textView = consoleOutput
        runBuildTask.exitStrings = ["Finished"]
        runBuildTask.runScript(script: .standDown) {
            
            if !runBuildTask.errorBool {
                
                DispatchQueue.main.async {
                    
                    self.hideSpinner()
                    self.setLog(content: self.consoleOutput.string)
                    setSimpleAlert(message: "Success", info: "You have StoodDown", buttonLabel: "OK")
                    self.goBack()
                    
                }
                
            } else {
                
                setSimpleAlert(message: "Error", info: runBuildTask.errorDescription, buttonLabel: "OK")
                
            }
            
        }
        
    }
    
    func standUp(binaryName: String, macosURL: String, shaURL: String, version: String, prefix: String) {
        
        DispatchQueue.main.async {
            
            let d = Defaults()
            let runBuildTask = RunBuildTask()
            runBuildTask.args = []
            runBuildTask.env = ["BINARY_NAME":binaryName, "MACOS_URL":macosURL, "SHA_URL":shaURL, "VERSION":version, "CONF":self.standUpConf, "DATADIR":d.dataDir()]
            runBuildTask.textView = self.consoleOutput
            runBuildTask.showLog = true
            runBuildTask.exitStrings = ["Successfully started `tor`", "Service `tor` already started", "Signatures do not match! Terminating..."]
            runBuildTask.runScript(script: .standUp) {
                
                if !runBuildTask.errorBool {
                    
                    DispatchQueue.main.async {
                        let ud = UserDefaults.standard
                        ud.set(prefix, forKey: "binaryPrefix")
                        ud.set(version, forKey: "version")
                        self.setLog(content: self.consoleOutput.string)
                        self.goBack()
                    }
                    
                } else {
                    
                   setSimpleAlert(message: "Error", info: runBuildTask.errorDescription, buttonLabel: "OK")
                    
                }
                
            }
            
        }
        
    }
    
    func refreshHS() {
        
        let runBuildTask = RunBuildTask()
        runBuildTask.args = []
        runBuildTask.showLog = true
        runBuildTask.textView = consoleOutput
        runBuildTask.env = ["":""]
        runBuildTask.exitStrings = ["Done"]
        runBuildTask.runScript(script: .refreshHS) {
            
            if !runBuildTask.errorBool {
                
                self.setLog(content: runBuildTask.stringToReturn)
                setSimpleAlert(message: "Success", info: "Tor hidden service was refreshed, go back and scan the new QR Code to connect", buttonLabel: "OK")
                
                self.goBack()
                
            } else {
                
                setSimpleAlert(message: "Error", info: runBuildTask.errorDescription, buttonLabel: "OK")
                
            }
            
        }
        
    }
    
    func upgradeBitcoinCore(binaryName: String, macosURL: String, shaURL: String, version: String, prefix: String) {
        
        upgrading = false
        
        DispatchQueue.main.async {
            
            let runBuildTask = RunBuildTask()
            runBuildTask.args = []
            runBuildTask.env = ["BINARY_NAME":binaryName, "MACOS_URL":macosURL, "SHA_URL":shaURL, "VERSION":version]
            runBuildTask.textView = self.consoleOutput
            runBuildTask.showLog = true
            runBuildTask.exitStrings = ["You have upgraded to Bitcoin Core", "Signatures do not match! Terminating..."]
            runBuildTask.runScript(script: .upgradeBitcoin) {
                
                if !runBuildTask.errorBool {
                    
                    DispatchQueue.main.async {
                        let ud = UserDefaults.standard
                        ud.set(prefix, forKey: "binaryPrefix")
                        ud.set(version, forKey: "version")
                        self.setLog(content: self.consoleOutput.string)
                        self.goBack()
                    }
                    
                } else {
                    
                   setSimpleAlert(message: "Error", info: runBuildTask.errorDescription, buttonLabel: "OK")
                    
                }
                
            }
            
        }
        
    }
    
    func hideSpinner() {
        
        DispatchQueue.main.async {
            
            self.spinner.alphaValue = 0
            self.backButtonOutlet.isEnabled = true
            self.spinnerDescription.stringValue = ""
            self.spinner.stopAnimation(self)
            
        }
        
    }
    
    func setScene() {
        
        backButtonOutlet.isEnabled = false
        consoleOutput.textColor = NSColor.green
        consoleOutput.isEditable = false
        consoleOutput.isSelectable = false
        spinnerDescription.stringValue = ""
        
    }
    
    func setLog(content: String) {
        
        let lg = Log()
        lg.writeToLog(content: content)
        
    }
    
    func getLog(completion: @escaping (String) -> Void) {
        
        let lg = Log()
        lg.getLog {
            completion((lg.logText))
        }
    }
    
    func getExisistingRPCCreds(completion: @escaping ((user: String, password: String)) -> Void) {
        print("getExisistingRPCCreds")
        
        var user = ""
        var password = ""
        let d = Defaults()
        let runBuildTask = RunBuildTask()
        runBuildTask.args = []
        runBuildTask.env = ["DATADIR":d.dataDir()]
        runBuildTask.exitStrings = ["Done"]
        runBuildTask.runScript(script: .getRPCCredentials) {
            
            if !runBuildTask.errorBool {
                
                let conf = (runBuildTask.stringToReturn).components(separatedBy: "\n")
                
                for item in conf {
                    
                    if item.contains("rpcuser") {
                        
                        let arr = item.components(separatedBy: "rpcuser=")
                        user = arr[1]
                        
                    }
                    
                    if item.contains("rpcpassword") {
                        
                        let arr = item.components(separatedBy: "rpcpassword=")
                        password = arr[1]
                        
                    }
                    
                    completion((user: user, password: password))
                    
                }
                
            } else {
                
                completion((user: "", password: ""))
                
            }
            
        }
        
    }
    
    func getBitcoinConf(completion: @escaping ((conf: [String], error: Bool)) -> Void) {
        
        let d = Defaults()
        let runBuildTask = RunBuildTask()
        runBuildTask.args = []
        runBuildTask.env = ["DATADIR":d.dataDir()]
        runBuildTask.showLog = false
        runBuildTask.exitStrings = ["Done"]
        runBuildTask.runScript(script: .getRPCCredentials) {
            
            if !runBuildTask.errorBool {
                
                var conf = (runBuildTask.stringToReturn).components(separatedBy: "\n")
                
                for c in conf {
                    
                    if c.contains("No such file or directory") {
                        
                        conf = []
                        
                    }
                    
                }
                
                completion((conf, false))
                
            } else {
                
                completion(([""], true))
                setSimpleAlert(message: "Error", info: runBuildTask.errorDescription, buttonLabel: "OK")
                
            }
            
        }
        
    }
    
}
