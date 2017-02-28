//  DeletedMeetingsViewController.swift
//  NA Meeting List Administrator
//
//  Created by MAGSHARE.
//
//  Copyright 2017 MAGSHARE
//
//  This is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  NA Meeting List Administrator is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this code.  If not, see <http://www.gnu.org/licenses/>.

import UIKit
import BMLTiOSLib

/* ###################################################################################################################################### */
// MARK: - List Deleted Meetings View Controller Class -
/* ###################################################################################################################################### */
/**
 This class controls the list of deleted meetings that can be restored.
 */
class DeletedMeetingsViewController : EditorViewControllerBaseClass {
    private var _deletedMeetingChanges: [BMLTiOSLibChangeNode] = []
    /** This is the navbar button that acts as a back button. */
    @IBOutlet weak var backButton: UIBarButtonItem!
    /** This is our animated "busy cover." */
    @IBOutlet weak var animationMaskView: UIView!
    /** This is a semaphore that we use to prevent too many searches. */
    var searchDone: Bool = false
    
    /* ################################################################## */
    // MARK: IB Methods
    /* ################################################################## */
    /**
     - parameter sender: The bar button item that called this.
     */
    @IBAction func backButtonHit(_ sender: UIBarButtonItem) {
        let _ = self.navigationController?.popViewController(animated: true)
    }

    /* ################################################################## */
    // MARK:
    /* ################################################################## */
    /**
     Called just after the view set up its subviews.
     We take this opportunity to create or update the weekday switches.
     */
    override func viewDidLoad() {
        super.viewDidLoad()
        self.backButton.title = NSLocalizedString(self.backButton.title!, comment: "")
    }
    
    /* ################################################################## */
    /**
     - parameter animated: True, if the appearance is animated (ignored).
     */
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let navController = self.navigationController {
            navController.isNavigationBarHidden = true
        }
        
        if !self.searchDone {
            self.animationMaskView.isHidden = false
            MainAppDelegate.connectionObject.getDeletedMeetingChanges()
        }
    }
    
    /* ################################################################## */
    /**
     This is called when the search updates.
     The way the BMLTiOSLib works, is that only deleted meetings that we are allowed to restore are returned.
     
     - parameter changeListResults: An array of change objects.
     */
    func updateDeletedResponse(changeListResults: [BMLTiOSLibChangeNode]) {
        self.animationMaskView.isHidden = false
        self.searchDone = true
        self._deletedMeetingChanges = changeListResults
    }
}
