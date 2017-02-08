//
//  ListEditableMeetingsViewController.swift
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
// MARK: - List Editable Meetings View Controller Class -
/* ###################################################################################################################################### */
/**
 */
class ListEditableMeetingsViewController : EditorViewControllerBaseClass, UITableViewDataSource, UITableViewDelegate, UIPickerViewDelegate, UIPickerViewDataSource {
    /* ################################################################## */
    // MARK: Private Constant Instance Properties
    /* ################################################################## */
    /** This is the table prototype ID for the standard meeting display */
    private let _meetingPrototypeReuseID = "Meeting-Table-View-Prototype"
    /** This is the segue ID for bringing in a meeting to edit. */
    private let _editSingleMeetingSegueID = "show-single-meeting-to-edit"
    
    /* ################################################################## */
    // MARK: Private Instance Properties
    /* ################################################################## */
    /** This contains all the meetings currently displayed */
    private var _currentMeetingList: [BMLTiOSLibMeetingNode] = []
    /** This is a semaphore, indicating that we have performed a search, and don't need to do another one. */
    private var _searchDone: Bool = false
    /** This contains the towns extracted from the meetings. */
    private var _townsAndBoroughs: [String] = []
    
    /* ################################################################## */
    // MARK: Internal IB Instance Properties
    /* ################################################################## */
    /** This covers the screen with a busy throbber when we are searching */
    @IBOutlet weak var busyAnimationView: UIView!
    /** This has 8 checkboxes, which allows the user to select certain weekdays. */
    @IBOutlet weak var weekdaySwitchesContainerView: UIView!
    /** This displays the meetings */
    @IBOutlet weak var meetingListTableView: UITableView!
    @IBOutlet weak var townBoroughPickerView: UIPickerView!
    
    /* ################################################################## */
    // MARK: Internal Instance Properties
    /* ################################################################## */
    /** This carries the state of the selected/unselected weekday checkboxes. */
    var selectedWeekdays: BMLTiOSLibSearchCriteria.SelectableWeekdayDictionary = [.Sunday:.Selected,.Monday:.Selected,.Tuesday:.Selected,.Wednesday:.Selected,.Thursday:.Selected,.Friday:.Selected,.Saturday:.Selected]

    /* ################################################################## */
    // MARK: Overridden Base Class Methods
    /* ################################################################## */
    /**
     Called just after the view set up its subviews.
     We take this opportunity to create or update the weekday switches.
     */
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setUpWeekdayViews()
    }
    
    /* ################################################################## */
    /**
     We take this opportunity to deselect any selected rows.
     
     - parameter animated: True, if the appearance is animated (ignored).
     */
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if nil != self.meetingListTableView {
            for row in 0..<self.meetingListTableView.numberOfRows(inSection: 0) {
                self.meetingListTableView.deselectRow(at: IndexPath(row: row, section: 0), animated: true)
            }
        }
    }
    
    /* ################################################################## */
    /**
     Trigger a search upon appearance.
     
     - parameter animated: True, if the appearance is animated (ignored).
     */
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !self._searchDone {
            self.doSearch()
        }
    }
    
    /* ################################################################## */
    /**
     Reference the selected meeting before bringing in the editor.
     
     - parameter for: The segue object
     - parameter sender: Attached data (We attached the meeting object).
     */
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let meetingObject = sender as? BMLTiOSLibEditableMeetingNode {
            if let destinationController = segue.destination as? EditSingleMeetingViewController {
                destinationController.meetingObject = meetingObject
            }
        }
    }
    
    /* ################################################################## */
    // MARK: Instance Methods
    /* ################################################################## */
    /**
     Trigger a search.
     */
    func doSearch() {
        self._searchDone = true
        // First, get the IDs of the Service bodies we'll be checking.
        let sbArray = AppStaticPrefs.prefs.selectedServiceBodies
        
        let count = MainAppDelegate.connectionObject.searchCriteria.serviceBodies.count
        
        for i in 0..<count {
            let sb = MainAppDelegate.connectionObject.searchCriteria.serviceBodies[i].item
            if sbArray.contains(sb) {
                MainAppDelegate.connectionObject.searchCriteria.serviceBodies[i].selection = .Selected
            }
        }
        self._currentMeetingList = []
        self._townsAndBoroughs = []
        self.meetingListTableView.reloadData()
        self.townBoroughPickerView.reloadAllComponents()
        MainAppDelegate.appDelegateObject.meetingObjects = []
        MainAppDelegate.connectionObject.searchCriteria.publishedStatus = .Both
        self.busyAnimationView.isHidden = false
        self.allChangedTo(inState: .Selected)
        MainAppDelegate.connectionObject.searchCriteria.performMeetingSearch(.MeetingsOnly)
    }
    
    /* ################################################################## */
    /**
     This is called when the search updates.
     
     - parameter inMeetingObjects: An array of meeting objects.
     */
    func updateSearch(inMeetingObjects:[BMLTiOSLibMeetingNode]) {
        self.busyAnimationView.isHidden = true
        self._currentMeetingList = MainAppDelegate.appDelegateObject.meetingObjects // We start by grabbing all the meetings.
        self.allChangedTo(inState: .Selected)   // We select all weekdays.
        
        // Extract all the towns and boroughs from the entire list.
        self._townsAndBoroughs = []
        var tempTowns: [String] = []
        
        for meeting in MainAppDelegate.appDelegateObject.meetingObjects {
            // We give boroughs precedence over towns.
            let town = meeting.locationBorough.isEmpty ? meeting.locationTown : meeting.locationBorough

            if !town.isEmpty && !tempTowns.contains(town) {
                tempTowns.append(town)
            }
        }
        
        self._townsAndBoroughs = tempTowns.sorted()
        
        // Select every town and borough
        self.townBoroughPickerView.selectRow(0, inComponent: 0, animated: false)
        self.updateDisplayedMeetings()
    }
    
    /* ################################################################## */
    /**
     This sorts through the available meetings, and filters out the ones we want, according to the weekday checkboxes.
     */
    func updateDisplayedMeetings() {
        self._currentMeetingList = []
        
        for meeting in MainAppDelegate.appDelegateObject.meetingObjects {
            for weekdaySelection in self.selectedWeekdays {
                if (weekdaySelection.value == .Selected) && (weekdaySelection.key.rawValue == meeting.weekdayIndex) {
                    if 1 < self.townBoroughPickerView.selectedRow(inComponent: 0) {
                        let row = self.townBoroughPickerView.selectedRow(inComponent: 0) - 2
                        let townString = self._townsAndBoroughs[row]
                        if (meeting.locationBorough == townString) || (meeting.locationTown == townString) {
                            self._currentMeetingList.append(meeting)
                            break
                        }
                    } else {
                        self._currentMeetingList.append(meeting)
                        break
                    }
                }
            }
        }
        
        self.meetingListTableView.reloadData()
        self.townBoroughPickerView.reloadAllComponents()
    }
    
    /* ################################################################## */
    /**
     We call this to set up our weekday selectors.
     */
    func setUpWeekdayViews() {
        for subView in self.weekdaySwitchesContainerView.subviews {
            subView.removeFromSuperview()
        }
        
        let containerFrame = self.weekdaySwitchesContainerView.bounds
        
        let individualFrameWidth: CGFloat = containerFrame.size.width / 8
        
        var xOrigin: CGFloat = 0
        for index in 0..<8 {
            let newFrame = CGRect(x: xOrigin, y: 0, width: individualFrameWidth, height: containerFrame.height)
            let newView = WeekdaySwitchContainerView(frame: newFrame, weekdayIndex: index, inOwner: self)
            self.weekdaySwitchesContainerView.addSubview(newView)
            xOrigin += individualFrameWidth
        }
    }
    
    /* ################################################################## */
    /**
     This changes all of the checkboxes to match the "All" checkbox state.
     */
    func allChangedTo(inState : BMLTiOSLibSearchCriteria.SelectionState) {
        for subView in self.weekdaySwitchesContainerView.subviews {
            if let castView = subView as? WeekdaySwitchContainerView {
                if 0 != castView.weekdayIndex {
                    castView.selectionSwitchControl.selectionState = inState
                }
            }
        }
        
        self.updateDisplayedMeetings()
    }
    
    /* ################################################################## */
    /**
     Called to initiate editing of a meeting.
     
     - parameter inMeetingObject: The meeting to be edited.
     */
    func editSingleMeeting(_ inMeetingObject: BMLTiOSLibMeetingNode!) {
        if nil != inMeetingObject {
            self.performSegue(withIdentifier: self._editSingleMeetingSegueID, sender: inMeetingObject)
        }
    }
    
    /* ################################################################## */
    /**
     This is called when one of the weekday checkboxes is changed.
     
     - parameter inWeekdayIndex: 1-based index of the weekday represented by the checkbox.
     - parameter newSelectionState: The new state for selection.
     */
    func weekdaySelectionChanged(inWeekdayIndex: Int, newSelectionState: BMLTiOSLibSearchCriteria.SelectionState) {
        if 0 == inWeekdayIndex {
            self.allChangedTo(inState: newSelectionState)
        } else {
            if let indexAsEnum = BMLTiOSLibSearchCriteria.WeekdayIndex(rawValue: inWeekdayIndex) {
                self.selectedWeekdays[indexAsEnum] = newSelectionState
                self.updateDisplayedMeetings()
            }
        }
    }
    
    /* ################################################################## */
    // MARK: UITableViewDataSource Methods
    /* ################################################################## */
    /**
     - parameter tableView: The UITableView object requesting the view
     - parameter numberOfRowsInSection: The section index (0-based).
     
     - returns the number of rows to display.
     */
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self._currentMeetingList.count
    }
    
    /* ################################################################## */
    /**
     This is the routine that creates a new table row for the Meeting indicated by the index.
     
     - parameter tableView: The UITableView object requesting the view
     - parameter cellForRowAt: The IndexPath of the requested cell.
     
     - returns a nice, shiny cell (or sets the state of a reused one).
     */
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let ret = tableView.dequeueReusableCell(withIdentifier: self._meetingPrototypeReuseID) as? MeetingTableViewCell {
            // We alternate with slightly darker cells. */
            ret.backgroundColor = (0 == (indexPath.row % 2)) ? UIColor.clear : UIColor.init(white: 0, alpha: 0.1)
            if let meetingObject = self._currentMeetingList[indexPath.row] as? BMLTiOSLibEditableMeetingNode {
                ret.meetingInfoLabel.text = meetingObject.name
                ret.addressLabel.text = meetingObject.basicAddress
                if var hour = meetingObject.startTimeAndDay.hour {
                    if let minute = meetingObject.startTimeAndDay.minute {
                        var time = ""
                        
                        if ((23 == hour) && (55 <= minute)) || ((0 == hour) && (0 == minute)) || (24 == hour) {
                            time = NSLocalizedString("MIDNIGHT", comment: "")
                        } else {
                            if (12 == hour) && (0 == minute) {
                                time = NSLocalizedString("NOON", comment: "")
                            } else {
                                let formatter = DateFormatter()
                                formatter.locale = Locale.current
                                formatter.dateStyle = .none
                                formatter.timeStyle = .short
                                
                                let dateString = formatter.string(from: Date())
                                let amRange = dateString.range(of: formatter.amSymbol)
                                let pmRange = dateString.range(of: formatter.pmSymbol)
                                
                                if !(pmRange == nil && amRange == nil) {
                                    var amPm = formatter.amSymbol
                                    
                                    if 12 < hour {
                                        hour -= 12
                                        amPm = formatter.pmSymbol
                                    } else {
                                        if 12 == hour {
                                            amPm = formatter.pmSymbol
                                        }
                                    }
                                    time = String(format: "%d:%02d %@", hour, minute, amPm!)
                                } else {
                                    time = String(format: "%d:%02d", hour, minute)
                                }
                            }
                        }
                        
                        let weekday = AppStaticPrefs.weekdayNameFromWeekdayNumber(meetingObject.weekdayIndex)
                        let localizedFormat = NSLocalizedString("MEETING-TIME-FORMAT", comment: "")
                        let formats = meetingObject.formatsAsCSVList.isEmpty ? "" : " (" + meetingObject.formatsAsCSVList + ")"
                        ret.meetingTimeAndPlaceLabel.text = String(format: localizedFormat, weekday, time) + formats
                    }
                }
            }
            
            return ret
        } else {
            return UITableViewCell()
        }
    }
    
    /* ################################################################## */
    // MARK: - UITableViewDelegate Methods -
    /* ################################################################## */
    /**
     Called before a row is selected.
     
     - parameter tableView: The table view being checked
     - parameter willSelectRowAt: The indexpath of the row being selected.
     
     - returns: the indexpath.
     */
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        self.editSingleMeeting(self._currentMeetingList[indexPath.row])
        
        return indexPath
    }
    
    /* ################################################################## */
    // MARK: - UIPickerViewDataSource Methods -
    /* ################################################################## */
    /**
     We only have 1 component.
     
     - parameter pickerView:The UIPickerView being checked
     
     - returns: 1
     */
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    /* ################################################################## */
    /**
     We will always have 2 more than the number of towns, as we have the first and second rows.
     
     - parameter pickerView:The UIPickerView being checked
     
     - returns: Either 0, or the number of towns to be displayed, plus 2.
     */
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if self._townsAndBoroughs.isEmpty {
            return 1
        } else {
            return self._townsAndBoroughs.count + 1
        }
    }
    
    /* ################################################################## */
    // MARK: - UIPickerViewDelegate Methods -
    /* ################################################################## */
    /**
     This returns the name for the given row.
     
     - parameter pickerView: The UIPickerView being checked
     - parameter row: The row being checked
     - parameter forComponent: The component (always 0)
     - parameter reusing: If the view is being reused, it is passed in here.
     
     - returns: a view, containing a label with the string for the row.
     */
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        let size = pickerView.rowSize(forComponent: 0)
        var frame = pickerView.bounds
        frame.size.height = size.height
        frame.origin = CGPoint.zero
        
        var pickerValue: String = ""
        
        if 0 == row {
            pickerValue = NSLocalizedString("LOCAL-SEARCH-PICKER-NONE", comment: "")
        } else {
            if 1 < row {
                pickerValue = self._townsAndBoroughs[row - 2]
            }
        }
        
        let ret:UIView = UIView(frame: frame)
        
        ret.backgroundColor = UIColor.clear
        
        let label = UILabel(frame: frame)
        
        if !pickerValue.isEmpty {
            label.backgroundColor = self.view.tintColor.withAlphaComponent(0.5)
            label.textColor = UIColor.white
            label.text = pickerValue
            label.textAlignment = NSTextAlignment.center
        } else {
            label.backgroundColor = UIColor.clear
        }
        
        ret.addSubview(label)
        
        return ret
    }
    
    /* ################################################################## */
    /**
     This is called when the user finishes selecting a row.
     We use this to add the selected town to the filter.
     
     If it is one of the top 2 rows, we select the first row, and ignore it.
     
     - parameter pickerView:The UIPickerView being checked
     - parameter row:The row being checked
     - parameter component:The component (always 0)
     */
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if 1 == row {
            pickerView.selectRow(0, inComponent: 0, animated: true)
        }
        
        self.updateDisplayedMeetings()
    }
}

/* ###################################################################################################################################### */
// MARK: - Custom Meeting Table View Class -
/* ###################################################################################################################################### */
/**
 This is a simple class that allows us to access the template items.
 */
class MeetingTableViewCell : UITableViewCell {
    /** The top label */
    @IBOutlet weak var meetingTimeAndPlaceLabel: UILabel!
    /** The middle (italic) label */
    @IBOutlet weak var addressLabel: UILabel!
    /** The bottom label */
    @IBOutlet weak var meetingInfoLabel: UILabel!
}

/* ###################################################################################################################################### */
// MARK: - Custom Weekday Switch View Class -
/* ###################################################################################################################################### */
/**
 */
class WeekdaySwitchContainerView : UIView {
    /** This is the weekday index (1-based) */
    var weekdayIndex: Int!
    /** This is the list selection view controller that "owns" this instance */
    var owner: ListEditableMeetingsViewController! = nil
    /** This is the checkbox control object */
    var selectionSwitchControl: ThreeStateCheckbox!
    /** This is the label containing the name being displayed */
    var weekdayNameLabel: UILabel!
    
    /* ################################################################## */
    /**
     The default initializer. It creates the embedded views, and sets the state.
     We set the ThreeStateCheckbox object to be a simple binary checkbox.
     
     - parameter frame: The frame within the superview this will be placed.
     - parameter weekdayIndex: The 1-based weekday index.
     - parameter inOwner: The list view controller that "owns" this view.
     */
    init(frame: CGRect, weekdayIndex: Int, inOwner: ListEditableMeetingsViewController) {
        super.init(frame: frame)
        self.owner = inOwner
        self.weekdayIndex = weekdayIndex
        self.backgroundColor = UIColor.clear
        self.isUserInteractionEnabled = true
        if let testImage = UIImage(named: "checkbox-clear") {
            var checkboxFrame: CGRect = CGRect.zero
            checkboxFrame.size = testImage.size
            
            if checkboxFrame.size.width > frame.size.width {
                checkboxFrame.size.width = frame.size.width
                checkboxFrame.size.height = frame.size.width
            }
            
            if checkboxFrame.size.height > frame.size.height {
                checkboxFrame.size.height = frame.size.height
                checkboxFrame.size.width = frame.size.height
            }
            
            checkboxFrame.origin.x = (frame.size.width - checkboxFrame.size.width) / 2  // Center the switch at the top of the view.
            
            self.selectionSwitchControl = ThreeStateCheckbox(frame: checkboxFrame)
            self.selectionSwitchControl.binaryState = true
            
            if 0 < self.weekdayIndex {
                if let indexAsEnum = BMLTiOSLibSearchCriteria.WeekdayIndex(rawValue: self.weekdayIndex) {
                    if let weekdaySelection = owner.selectedWeekdays[indexAsEnum] {
                        self.selectionSwitchControl.selectionState = weekdaySelection
                    }
                }
            } else {
                var selectionState: BMLTiOSLibSearchCriteria.SelectionState! = nil
                for weekday in owner.selectedWeekdays {
                    if nil == selectionState {
                        selectionState = weekday.value
                    } else {
                        if weekday.value != selectionState {
                            selectionState = .Clear
                            break
                        }
                    }
                }
                
                if nil == selectionState {
                    selectionState = .Clear
                }
                
                self.selectionSwitchControl.selectionState = selectionState!
            }
            
            self.selectionSwitchControl.addTarget(self, action: #selector(WeekdaySwitchContainerView.checkboxSelectionChanged(_:)), for: UIControlEvents.valueChanged)
            
            var labelFrame: CGRect = CGRect.zero
            labelFrame.size.width = frame.size.width
            labelFrame.size.height = frame.size.height - checkboxFrame.size.height
            labelFrame.origin.y = checkboxFrame.size.height
            
            self.weekdayNameLabel = UILabel(frame: labelFrame)
            self.weekdayNameLabel.textColor = inOwner.view.tintColor
            self.weekdayNameLabel.textAlignment = .center
            self.weekdayNameLabel.font = UIFont.boldSystemFont(ofSize: 14)
            self.weekdayNameLabel.text = (0 == weekdayIndex) ? NSLocalizedString("ALL-DAYS", comment: "") : AppStaticPrefs.weekdayNameFromWeekdayNumber(weekdayIndex, isShort: true)
            
            self.addSubview(self.selectionSwitchControl)
            self.addSubview(self.weekdayNameLabel)
        }
    }
    
    /* ################################################################## */
    /**
     This is required. Why? Not sure.
     
     - parameter coder: The decoder for this object.
     */
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    /* ################################################################## */
    /**
     We override this to make sure we put away all our toys.
     */
    override func removeFromSuperview() {
        self.selectionSwitchControl.removeFromSuperview()
        self.selectionSwitchControl = nil
        self.weekdayNameLabel.removeFromSuperview()
        self.weekdayNameLabel = nil
        super.removeFromSuperview()
    }
    
    /* ################################################################## */
    /**
     The callback for our checkbox changing. We basically reroute to the owner.
     
     - parameter inCheckbox: The ThreeStateCheckbox object that called this.
     */
    func checkboxSelectionChanged(_ inCheckbox: ThreeStateCheckbox) {
        self.owner.weekdaySelectionChanged(inWeekdayIndex: self.weekdayIndex, newSelectionState: inCheckbox.selectionState)
    }
}
