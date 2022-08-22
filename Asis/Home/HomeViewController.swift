//
//  ViewController.swift
//  Asis
//
//  Created by Can Duru on 1.08.2022.
//

//MARK: Import
import UIKit
import SideMenu
import MapKit
import CoreLocation
import FloatingPanel
import Alamofire

//MARK: Routes Array
struct Routes {
    var departureID: Int
    var departureName: String
    var departureTime: String
    var departureCoordinates: MKPlacemark
    var destinationID: Int
    var destinationName: String
    var destinationTime: String
    var destinationCoordinates: MKPlacemark
    var routetime: Int
    var walkingfromcurrent: Double
    var walkingtodestination: Double
    var services: String
}

class HomeViewController: UIViewController, UISearchBarDelegate, FloatingPanelControllerDelegate {

//MARK: Set Up
    
    
    
    //MARK: Service Setup
    var servicesArray:[Service] = []
    var selectedServiceRouteCoordinates: [CLLocationCoordinate2D] = []
    var selectedServiceRouteStopIDs: [Int] = []
    
    //MARK: Loading View Setup
    let loadingVC = LoadingViewController()

    
    //MARK: Map Setup
    private let map: MKMapView = {
        let map = MKMapView()
        return map
    }()
    
    //MARK: HowToGo Setup
    var timerForSelectedBus = Timer()
    lazy var searchController: UISearchController = {
        let search = UISearchController()
        search.obscuresBackgroundDuringPresentation = false
        search.searchBar.placeholder = String(localized: "howToGoSearchBar")
        search.searchBar.sizeToFit()
        search.searchBar.searchBarStyle = .prominent        
        search.searchBar.delegate = self
        return search
    }()
    let floatingpanelview = FloatingPanelTableViewController()
    var suitableStopsAroundDestinationArray: [Stop] = []
    var suitableStopsAroundCurentLocationArray: [Stop] = []
    var startingpoint: MKPlacemark!
    var finishingpoint: MKPlacemark!
    var finished = false
    var routeCoordinates: [CLLocationCoordinate2D] = [] {
        didSet{
            if finished == true{
                polyLines(currentLocationLatitude: user_latitude,
                          currentLocationLongitude: user_longitude,
                          startStopLatitude: routeCoordinates[0].latitude,
                          startStopLongitude: routeCoordinates[0].longitude,
                          finalStopLatitude: routeCoordinates[routeCoordinates.count-1].latitude,
                          finalStopLongitude: routeCoordinates[routeCoordinates.count-1].longitude,
                          busRouteCoordinates: routeCoordinates,
                          destinationLatitude: selectedItemCoordination.latitude,
                          destinationLongitude: selectedItemCoordination.longitude,
                          polymapView: map)
            }
        }
    }
    var start_number = 99999999
    var routesArray: [Routes] = [] {
        didSet{

            //MARK: Check All Elements Filled
            var check = false
            for times in (0..<routesArray.count) {
                if routesArray[times].walkingtodestination != 0 && routesArray[times].walkingfromcurrent != 0 {
                    check = true
                } else{
                    check = false
                }
            }
            
            //MARK: Floating Panel Cell Content
            var alert = true
            if check == true{
                //MARK: Dismiss Loading View
                dismiss(animated: true)
                
                for walkingtimecheck in routesArray{
                    
                    //MARK: Format Date
                    let dateFormatter = DateFormatter()
                    let currentDateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "HH:mm"
                    dateFormatter.timeZone = TimeZone(abbreviation: "GMT+00:00")
                    currentDateFormatter.dateFormat = "HH:mm"
                    currentDateFormatter.timeZone = TimeZone(abbreviation: "GMT+01:00")
                    let currentDate = Date()
                    let dateString = currentDateFormatter.string(from: currentDate)
                    let departuredate = dateFormatter.date(from: dateString)
                    let destinationdate = dateFormatter.date(from: walkingtimecheck.departureTime)
                    let diffSeconds = destinationdate!.timeIntervalSinceReferenceDate - departuredate!.timeIntervalSinceReferenceDate
                    let diffMinutes = diffSeconds / 60
                    
                    //MARK: Check Time for Walking
                    if (diffMinutes) < (walkingtimecheck.walkingfromcurrent) {
        
                    } else {
                        map.deselectAnnotation(selectedItemAnnotation, animated: true)
                        alert = false
                        
                        //MARK: Selected Bus Service Annotation
                        selectedBusLocation(selectedservice: walkingtimecheck.services)
                        for BusAnnotation in self.map.annotations {
                            if let BusAnnotation = BusAnnotation as? CustomPointAnnotation, BusAnnotation.customidentifier == "busAnnotation" {
                                self.map.removeAnnotation(BusAnnotation)
                            }
                        }
                        selectedBusDataRepeat(selectedservice: walkingtimecheck.services)
                        timer.invalidate()
                        
                        //MARK: Polylines
                        for services in servicesArray {
                            if services.name == walkingtimecheck.services {
                                if services.routes.count == 0 {
                                    let servicecoordinates = CLLocationCoordinate2DMake(walkingtimecheck.departureCoordinates.coordinate.latitude, walkingtimecheck.departureCoordinates.coordinate.longitude);
                                    routeCoordinates.append(servicecoordinates)
                                    let servicecoordinates2 = CLLocationCoordinate2DMake(walkingtimecheck.destinationCoordinates.coordinate.latitude, walkingtimecheck.destinationCoordinates.coordinate.longitude);
                                    finished = true
                                    routeCoordinates.append(servicecoordinates2)
                                } else{
                                    for serviceRoutes in services.routes{
                                        for serviceCoordinates in (0..<serviceRoutes.points.count) {
                                            if Int(serviceRoutes.points[serviceCoordinates].stopID ?? "") == walkingtimecheck.departureID {
                                                start_number = serviceCoordinates
                                            }
                                            if serviceCoordinates >= start_number {
                                                if Int(serviceRoutes.points[serviceCoordinates].stopID ?? "") == walkingtimecheck.destinationID {
                                                    finished = true
                                                    let servicecoordinates = CLLocationCoordinate2DMake(serviceRoutes.points[serviceCoordinates].latitude, serviceRoutes.points[serviceCoordinates].longitude);
                                                    routeCoordinates.append(servicecoordinates)
                                                    break
                                                } else{
                                                    let servicecoordinates = CLLocationCoordinate2DMake(serviceRoutes.points[serviceCoordinates].latitude, serviceRoutes.points[serviceCoordinates].longitude);
                                                    routeCoordinates.append(servicecoordinates)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        //MARK: Table Data
                        let totalduration = Int(walkingtimecheck.walkingtodestination + walkingtimecheck.walkingfromcurrent + Double(walkingtimecheck.routetime))
                        if totalduration > 60 {
                            let hour = Int(totalduration / 60)
                            let minute = totalduration - (hour*60)
                            floatingPanel.show()
                            floatingpanelview.walkingToDestinationTime = Int(walkingtimecheck.walkingtodestination)
                            floatingpanelview.walkingFromCurrentTime = Int(walkingtimecheck.walkingfromcurrent)
                            floatingpanelview.routeTime = Int(walkingtimecheck.routetime)
                            floatingpanelview.totaltime = ((String(hour)) + String(localized: "hours") + String((minute)) + String(localized: "minutes"))
                            floatingpanelview.departuretime = walkingtimecheck.departureTime
                            floatingpanelview.service = walkingtimecheck.services
                        } else{
                            floatingPanel.show()
                            floatingpanelview.walkingToDestinationTime = Int(walkingtimecheck.walkingtodestination)
                            floatingpanelview.walkingFromCurrentTime = Int(walkingtimecheck.walkingfromcurrent)
                            floatingpanelview.routeTime = Int(walkingtimecheck.routetime)
                            floatingpanelview.totaltime = String(totalduration) + String(localized: "minutes")
                            floatingpanelview.departuretime = walkingtimecheck.departureTime
                            floatingpanelview.service = walkingtimecheck.services
                        }
                        break
                    }
                }
                if alert == true {
                    dismiss(animated: true)
                    minutesFor15Button.isHidden = false
                    minutesFor30Button.isHidden = false
                    minutesFor45Button.isHidden = false
                    metersFor500Button.isHidden = false
                    metersFor1000Button.isHidden = false
                    metersFor1500Button.isHidden = false
                    print("hata3")
                    let alert = UIAlertController(title: String(localized: "routeTimeError"), message: "", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: String(localized: "okButton"), style: UIAlertAction.Style.default, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                }
            }
        }
    }

        //MARK: Get Route Details
    var times_alert = 0
    var total_repeat = 0
    var times:[Trip] = [] {
        didSet {
            print(total_repeat)
            total_repeat=total_repeat+1
            if times.count == 0{
                times_alert = times_alert+1
            }
            if times_alert == self.suitableStopsAroundCurentLocationArray.count*self.suitableStopsAroundDestinationArray.count{
                if times.count == 0 {
                    dismiss(animated: true)
                    minutesFor15Button.isHidden = false
                    minutesFor30Button.isHidden = false
                    minutesFor45Button.isHidden = false
                    metersFor500Button.isHidden = false
                    metersFor1000Button.isHidden = false
                    metersFor1500Button.isHidden = false
                    print("hata1")
                    let alert = UIAlertController(title: String(localized: "routeTimeError"), message: "", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: String(localized: "tryAgainAlertView"), style: UIAlertAction.Style.default, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                }
            }
            if total_repeat == self.suitableStopsAroundCurentLocationArray.count*self.suitableStopsAroundDestinationArray.count{
                print(times)
//                if times.count != 0 {
//                    getRouteDetails()
//                    getStartandFinishCoordinates()
//                    self.count = 0
//                    getWalkingTime()
//                }
            }
        }
    }
    
    //MARK: Table Setup
    lazy var howToGoSearchTable: UITableView = {
        let tb = UITableView()
        tb.translatesAutoresizingMaskIntoConstraints = false
        tb.delegate = self
        tb.dataSource = self
        tb.register(HowToGoSearchTableCellSetup.self, forCellReuseIdentifier: HowToGoSearchTableCellSetup.identifer)
        return tb
    }()
    var matchingItems: [MKMapItem] = [] {
        didSet{
            howToGoSearchTable.reloadData()
        }
    }
    
    //MARK: Bus Data Setup
    var timer = Timer()
    var busses:[Vehicle] = [] {
        didSet{
            //MARK: Annotate Bus Locations
            for BusAnnotation in self.map.annotations {
                if let BusAnnotation = BusAnnotation as? CustomPointAnnotation, BusAnnotation.customidentifier == "busAnnotation" {
                    self.map.removeAnnotation(BusAnnotation)
                }
            }
            busLocations()
        }
    }
    
    //MARK: Stops Data Setup
    var stops:[Stop] = []
    
    //MARK: Side Menu Setup
    var menu: SideMenuNavigationController?
    lazy var menuBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "sidebar.leading")?.withRenderingMode(.alwaysOriginal).withTintColor(.systemBlue), style: .done, target: self, action: #selector(menuBarButtonItemTapped))
    @objc
    func menuBarButtonItemTapped(){
         present(menu!, animated: true)
    }
    lazy var menuView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGray5
        return view
    }()
    lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        return view
    }()

    
    
//MARK: Load
    var floatingPanel :FloatingPanelController!
    override func viewDidLoad() {
        super.viewDidLoad() 
        view.backgroundColor = .systemBackground
        howToGoSearchTable.isHidden = true

        //MARK: Service Load
        serviceDataCall()
        
        //MARK: Map Load
        view.addSubview(map)
        setMapLayout()
        mapLocation()
        setButton()
        cancelServiceButton.isHidden = true
        map.delegate = self
        
        
        //MARK: Bus Locations to Map Load
        BusData()
        BusDataRepeat()
        
        //MARK: Bus Stops Data Load
        BusStopsData()
        
        //MARK: Side Menu Load
        navigationItem.setLeftBarButton(menuBarButtonItem, animated: false)
        menu = SideMenuNavigationController(rootViewController: MenuListController())
        menu?.leftSide = true
        
        //MARK: Search Bar Load
        navigationItem.searchController = searchController
        
        //MARK: HowToGo Search Table Load
        view.addSubview(howToGoSearchTable)
        setTableLayout()
        
        //MARK: Floating Panel Load
        floatingPanel = FloatingPanelController()
        floatingPanel.delegate = self
        floatingpanelview.parentvc = self
        floatingPanel.set(contentViewController: floatingpanelview)
        floatingPanel.track(scrollView: floatingpanelview.tableView)
        floatingPanel.addPanel(toParent: self)
        floatingPanel.hide()
    }

    
    
//MARK: Table Constraints
    func setTableLayout(){
        howToGoSearchTable.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([howToGoSearchTable.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: 1),
                                     howToGoSearchTable.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
                                     howToGoSearchTable.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
                                     howToGoSearchTable.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)])
    }
    
    
    
//MARK: Search Bar
    func isSearchBarEmpty() -> Bool{
        return searchController.searchBar.text?.isEmpty ?? true
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        
        if isSearchBarEmpty() {
            howToGoSearchTable.isHidden = true
            zoomInButton.isHidden = false
            zoomOutButton.isHidden = false
            currentlocationButton.isHidden = false
            map.isHidden = false
        } else{
            //MARK: HowToGo Search
            howToGoSearchTable.isHidden = false
            zoomInButton.isHidden = true
            zoomOutButton.isHidden = true
            currentlocationButton.isHidden = true
            map.isHidden = true
            findLocations(with: searchText)
            howToGoSearchTable.reloadData()
        }
    }
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = nil
        howToGoSearchTable.isHidden = true
        zoomInButton.isHidden = false
        zoomOutButton.isHidden = false
        currentlocationButton.isHidden = false
        map.isHidden = false
    }

    

//MARK: HowToGo
    
    
    
    //MARK: Address Seaarch
    func findLocations(with query: String) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        let search = MKLocalSearch(request: request)
    
        search.start { response, _ in
            guard response != nil else {
                return
            }
            self.matchingItems = response!.mapItems
        }
    }
    
    //MARK: Set Address
    func parseAddress(selectedItem:MKPlacemark) -> String {
        let firstSpace = (selectedItem.subThoroughfare != nil &&
                            selectedItem.thoroughfare != nil) ? " " : ""
        let comma = (selectedItem.subThoroughfare != nil || selectedItem.thoroughfare != nil) &&
                    (selectedItem.subAdministrativeArea != nil || selectedItem.administrativeArea != nil) ? ", " : ""
        let secondSpace = (selectedItem.subAdministrativeArea != nil &&
                            selectedItem.administrativeArea != nil) ? " " : ""
        let addressLine = String(
            format:"%@%@%@%@%@%@%@",
            selectedItem.subThoroughfare ?? "",
            firstSpace,
            selectedItem.thoroughfare ?? "",
            comma,
            selectedItem.locality ?? "",
            secondSpace,
            selectedItem.administrativeArea ?? ""
        )
        return addressLine
    }
    
    //MARK: Find Close Stops
    var selectedItemCoordination = CLLocationCoordinate2D()
    @objc func makeRoad(){
    
        
        loadingVC.modalPresentationStyle = .overCurrentContext
        loadingVC.modalTransitionStyle = .crossDissolve
        present(loadingVC, animated: true, completion: nil)
        let busstopsCount = stops.count
        var userlatitude: Double = 0
        var userlongitude: Double = 0
        minutesFor15Button.isHidden = true
        minutesFor30Button.isHidden = true
        minutesFor45Button.isHidden = true
        metersFor500Button.isHidden = true
        metersFor1000Button.isHidden = true
        metersFor1500Button.isHidden = true


        LocationManager.shared.getUserLocation { [weak self] location in
            guard let self = self else {
                return
            }
            userlatitude = location.coordinate.latitude
            userlongitude = location.coordinate.longitude
            let group = DispatchGroup()
            
            //MARK: 100 Meter and 15 Minute Search
            if self.minute15check == true && self.meter500check == true {
                for i in (0..<busstopsCount){
                    if (((self.selectedItemCoordination.latitude)-0.001) < (self.stops[i].latitude!) &&
                        (self.stops[i].latitude!) < ((self.selectedItemCoordination.latitude)+0.001) &&
                        ((self.selectedItemCoordination.longitude)-0.001) < (self.stops[i].longitude!) &&
                        (self.stops[i].longitude!) < ((self.selectedItemCoordination.longitude)+0.001)) {
                        self.suitableStopsAroundDestinationArray.append(self.stops[i])
                    }

                    if (((userlatitude)-0.001) < (self.stops[i].latitude!) &&
                        (self.stops[i].latitude!) < ((userlatitude)+0.001) &&
                        ((userlongitude)-0.001) < (self.stops[i].longitude!) &&
                        (self.stops[i].longitude!) < ((userlongitude)+0.001)){
                        self.suitableStopsAroundCurentLocationArray.append(self.stops[i])
                    }
                }
                self.apiDecoder(minute: 15)

            }
            
            //MARK: 100 Meter and 30 Minute Search
            if self.minute30check == true && self.meter500check == true {
                group.enter()
                for i in (0..<busstopsCount){
                    if (((self.selectedItemCoordination.latitude)-0.001) < (self.stops[i].latitude!) &&
                        (self.stops[i].latitude!) < ((self.selectedItemCoordination.latitude)+0.001) &&
                        ((self.selectedItemCoordination.longitude)-0.001) < (self.stops[i].longitude!) &&
                        (self.stops[i].longitude!) < ((self.selectedItemCoordination.longitude)+0.001)) {
                        self.suitableStopsAroundDestinationArray.append(self.stops[i])
                    }

                    if (((userlatitude)-0.001) < (self.stops[i].latitude!) &&
                        (self.stops[i].latitude!) < ((userlatitude)+0.001) &&
                        ((userlongitude)-0.001) < (self.stops[i].longitude!) &&
                        (self.stops[i].longitude!) < ((userlongitude)+0.001)){
                        self.suitableStopsAroundCurentLocationArray.append(self.stops[i])
                        group.leave()
                    }
                }
                group.notify(queue: .main) {
                    self.apiDecoder(minute: 30)
                }
            }
            
            //MARK: 100 Meter and 45 Minute Search
            if self.minute45check == true && self.meter500check == true {
                group.enter()
                for i in (0..<busstopsCount){
                    if (((self.selectedItemCoordination.latitude)-0.001) < (self.stops[i].latitude!) &&
                        (self.stops[i].latitude!) < ((self.selectedItemCoordination.latitude)+0.001) &&
                        ((self.selectedItemCoordination.longitude)-0.001) < (self.stops[i].longitude!) &&
                        (self.stops[i].longitude!) < ((self.selectedItemCoordination.longitude)+0.001)) {
                        self.suitableStopsAroundDestinationArray.append(self.stops[i])
                    }

                    if (((userlatitude)-0.001) < (self.stops[i].latitude!) &&
                        (self.stops[i].latitude!) < ((userlatitude)+0.001) &&
                        ((userlongitude)-0.001) < (self.stops[i].longitude!) &&
                        (self.stops[i].longitude!) < ((userlongitude)+0.001)){
                        self.suitableStopsAroundCurentLocationArray.append(self.stops[i])
                        group.leave()
                    }
                }
                group.notify(queue: .main) {
                    self.apiDecoder(minute: 45)
                }
            }
            
            //MARK: 250 Meter and 15 Minute Search
            if self.minute15check == true && self.meter1000check == true {
                group.enter()
                for i in (0..<busstopsCount){
                    if (((self.selectedItemCoordination.latitude)-0.0025) < (self.stops[i].latitude!) &&
                        (self.stops[i].latitude!) < ((self.selectedItemCoordination.latitude)+0.0025) &&
                        ((self.selectedItemCoordination.longitude)-0.0025) < (self.stops[i].longitude!) &&
                        (self.stops[i].longitude!) < ((self.selectedItemCoordination.longitude)+0.0025)) {
                        self.suitableStopsAroundDestinationArray.append(self.stops[i])
                    }

                    if (((userlatitude)-0.0025) < (self.stops[i].latitude!) &&
                        (self.stops[i].latitude!) < ((userlatitude)+0.0025) &&
                        ((userlongitude)-0.0025) < (self.stops[i].longitude!) &&
                        (self.stops[i].longitude!) < ((userlongitude)+0.0025)){
                        self.suitableStopsAroundCurentLocationArray.append(self.stops[i])
                    }
                }
                group.notify(queue: .main) {
                    self.apiDecoder(minute: 15)
                }
            }
            
            //MARK: 250 Meter and 30 Minute Search
            if self.minute30check == true && self.meter1000check == true {
                group.enter()
                for i in (0..<busstopsCount){
                    if (((self.selectedItemCoordination.latitude)-0.0025) < (self.stops[i].latitude!) &&
                        (self.stops[i].latitude!) < ((self.selectedItemCoordination.latitude)+0.0025) &&
                        ((self.selectedItemCoordination.longitude)-0.0025) < (self.stops[i].longitude!) &&
                        (self.stops[i].longitude!) < ((self.selectedItemCoordination.longitude)+0.0025)) {
                        self.suitableStopsAroundDestinationArray.append(self.stops[i])
                    }

                    if (((userlatitude)-0.0025) < (self.stops[i].latitude!) &&
                        (self.stops[i].latitude!) < ((userlatitude)+0.0025) &&
                        ((userlongitude)-0.0025) < (self.stops[i].longitude!) &&
                        (self.stops[i].longitude!) < ((userlongitude)+0.0025)){
                        self.suitableStopsAroundCurentLocationArray.append(self.stops[i])
                    }
                }
                group.notify(queue: .main) {
                    self.apiDecoder(minute: 30)
                }
            }

            
            //MARK: 250 Meter and 45 Minute Search
            group.enter()
            if self.minute45check == true && self.meter1000check == true {
                for i in (0..<busstopsCount){
                    if (((self.selectedItemCoordination.latitude)-0.0025) < (self.stops[i].latitude!) &&
                        (self.stops[i].latitude!) < ((self.selectedItemCoordination.latitude)+0.0025) &&
                        ((self.selectedItemCoordination.longitude)-0.0025) < (self.stops[i].longitude!) &&
                        (self.stops[i].longitude!) < ((self.selectedItemCoordination.longitude)+0.0025)) {
                        self.suitableStopsAroundDestinationArray.append(self.stops[i])
                    }

                    if (((userlatitude)-0.0025) < (self.stops[i].latitude!) &&
                        (self.stops[i].latitude!) < ((userlatitude)+0.0025) &&
                        ((userlongitude)-0.0025) < (self.stops[i].longitude!) &&
                        (self.stops[i].longitude!) < ((userlongitude)+0.0025)){
                        self.suitableStopsAroundCurentLocationArray.append(self.stops[i])
                    }
                }
                group.notify(queue: .main) {
                    self.apiDecoder(minute: 45)
                }
            }

            //MARK: 400 Meter and 15 Minute Search
            if self.minute15check == true && self.meter1500check == true {
                group.enter()
                for i in (0..<busstopsCount){
                    if (((self.selectedItemCoordination.latitude)-0.004) < (self.stops[i].latitude!) &&
                        (self.stops[i].latitude!) < ((self.selectedItemCoordination.latitude)+0.004) &&
                        ((self.selectedItemCoordination.longitude)-0.004) < (self.stops[i].longitude!) &&
                        (self.stops[i].longitude!) < ((self.selectedItemCoordination.longitude)+0.004)) {
                        self.suitableStopsAroundDestinationArray.append(self.stops[i])
                    }

                    if (((userlatitude)-0.004) < (self.stops[i].latitude!) &&
                        (self.stops[i].latitude!) < ((userlatitude)+0.004) &&
                        ((userlongitude)-0.004) < (self.stops[i].longitude!) &&
                        (self.stops[i].longitude!) < ((userlongitude)+0.004)){
                        self.suitableStopsAroundCurentLocationArray.append(self.stops[i])
                    }
                }
                group.notify(queue: .main) {
                    self.apiDecoder(minute: 15)
                }
            }

            //MARK: 400 Meter and 30 Minute Search
            if self.minute30check == true && self.meter1500check == true {
                group.enter()
                for i in (0..<busstopsCount){
                    if (((self.selectedItemCoordination.latitude)-0.004) < (self.stops[i].latitude!) &&
                        (self.stops[i].latitude!) < ((self.selectedItemCoordination.latitude)+0.004) &&
                        ((self.selectedItemCoordination.longitude)-0.004) < (self.stops[i].longitude!) &&
                        (self.stops[i].longitude!) < ((self.selectedItemCoordination.longitude)+0.004)) {
                        self.suitableStopsAroundDestinationArray.append(self.stops[i])
                    }

                    if (((userlatitude)-0.004) < (self.stops[i].latitude!) &&
                        (self.stops[i].latitude!) < ((userlatitude)+0.004) &&
                        ((userlongitude)-0.004) < (self.stops[i].longitude!) &&
                        (self.stops[i].longitude!) < ((userlongitude)+0.004)){
                        self.suitableStopsAroundCurentLocationArray.append(self.stops[i])
                    }
                }
                group.notify(queue: .main) {
                    self.apiDecoder(minute: 30)
                }
            }
            
            //MARK: 400 Meter and 45 Minute Search
            if self.minute45check == true && self.meter1500check == true {
                group.enter()
                for i in (0..<busstopsCount){
                    if (((self.selectedItemCoordination.latitude)-0.004) < (self.stops[i].latitude!) &&
                        (self.stops[i].latitude!) < ((self.selectedItemCoordination.latitude)+0.004) &&
                        ((self.selectedItemCoordination.longitude)-0.004) < (self.stops[i].longitude!) &&
                        (self.stops[i].longitude!) < ((self.selectedItemCoordination.longitude)+0.004)) {
                        self.suitableStopsAroundDestinationArray.append(self.stops[i])
                    }

                    if (((userlatitude)-0.004) < (self.stops[i].latitude!) &&
                        (self.stops[i].latitude!) < ((userlatitude)+0.004) &&
                        ((userlongitude)-0.004) < (self.stops[i].longitude!) &&
                        (self.stops[i].longitude!) < ((userlongitude)+0.004)){
                        self.suitableStopsAroundCurentLocationArray.append(self.stops[i])
                    }
                }
                group.notify(queue: .main) {
                    self.apiDecoder(minute: 45)
                }
            }
        }
    }
    
    //MARK: API Decoder
    func apiDecoder(minute: Int){
//        let timestamp = Date().timeIntervalSince1970
//        self.timeData(timestring: "stoptostop-timetable/?start_stop_id=36236495&finish_stop_id=36232896&date=\(timestamp)&duration=\(minute)")
        if self.suitableStopsAroundCurentLocationArray.count == 0 || self.suitableStopsAroundDestinationArray.count == 0 {
            dismiss(animated: true)
            minutesFor15Button.isHidden = false
            minutesFor30Button.isHidden = false
            minutesFor45Button.isHidden = false
            metersFor500Button.isHidden = false
            metersFor1000Button.isHidden = false
            metersFor1500Button.isHidden = false
            print("hata2")

            let alert = UIAlertController(title: String(localized: "routeTimeError"), message: "", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String(localized: "tryAgainAlertView"), style: UIAlertAction.Style.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        } else {
            for start in self.suitableStopsAroundCurentLocationArray {
                for destination in self.suitableStopsAroundDestinationArray {
                    let timestamp = Date().timeIntervalSince1970
                    self.timeData(timestring: "stoptostop-timetable/?start_stop_id=\(start.stopID)&finish_stop_id=\(destination.stopID)&date=\(timestamp)&duration=\(minute)")
                }
            }
        }
    }

    //MARK: Get Route Details
    func getRouteDetails() {
        for times in (0..<self.times.count) {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "HH:mm"
            dateFormatter.timeZone = TimeZone(abbreviation: "GMT+00:00")
            let departure = self.times[times].departures[0].time
            let destination = self.times[times].departures[self.times[times].departures.count-1].time
            let departuredate = dateFormatter.date(from: departure)
            let destinationdate =  dateFormatter.date(from: destination)
            let diffSeconds = destinationdate!.timeIntervalSinceReferenceDate - departuredate!.timeIntervalSinceReferenceDate
            let diffMinutes = diffSeconds / 60
            routesArray.append(Routes(departureID: self.times[times].departures[0].stopID,
                                      departureName: self.times[times].departures[0].name,
                                      departureTime: self.times[times].departures[0].time,
                                      departureCoordinates: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0)),
                                      destinationID: self.times[times].departures[self.times[times].departures.count-1].stopID,
                                      destinationName: self.times[times].departures[self.times[times].departures.count-1].name,
                                      destinationTime: self.times[times].departures[self.times[times].departures.count-1].time,
                                      destinationCoordinates: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0)),
                                      routetime: Int(diffMinutes),
                                      walkingfromcurrent: 0,
                                      walkingtodestination: 0,
                                      services: self.times[times].serviceName))
        }
    }

    //MARK: Get Start and Finish Stop Coordinates
    func getStartandFinishCoordinates(){
        for departure in suitableStopsAroundDestinationArray {
            for suitable in (0..<routesArray.count) {
                if departure.stopID == routesArray[suitable].departureID{
                    routesArray[suitable].departureCoordinates = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: departure.latitude!, longitude: departure.longitude!), addressDictionary: nil)
                }
            }
        }
        for destination in suitableStopsAroundDestinationArray{
            for suitable in (0..<routesArray.count){
                if destination.stopID == routesArray[suitable].destinationID{
                    routesArray[suitable].destinationCoordinates = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: destination.latitude!, longitude: destination.longitude!), addressDictionary: nil)
                }
            }
        }
    }
    
    //MARK: Get Walking Time
    var count: Int = 0
    var user_latitude = Double(0)
    var user_longitude = Double(0)
    func getWalkingTime(){
        LocationManager.shared.getUserLocation { [weak self] location in
            
            guard let self = self else { return }
            self.user_latitude = location.coordinate.latitude
            self.user_longitude = location.coordinate.longitude
            self.run(location: location, walkings: self.count) {
                self.count += 1
                if self.count < self.routesArray.count{
                    self.getWalkingTime()
                }
            }
        }
    }
    
        //MARK: Repeat Request for Walking Time
    func run(location: CLLocation, walkings: Int, completion: @escaping () -> ()){
        
        let request = MKDirections.Request()
        let secondrequest = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude), addressDictionary: nil))
        request.destination = MKMapItem(placemark: self.routesArray[walkings].departureCoordinates)
        request.requestsAlternateRoutes = true
        request.transportType = .walking

        secondrequest.source = MKMapItem(placemark: self.routesArray[walkings].destinationCoordinates)
        secondrequest.destination = MKMapItem(placemark: MKPlacemark(coordinate: self.selectedItemCoordination))
        secondrequest.requestsAlternateRoutes = true
        secondrequest.transportType = .walking
        
        self.walkings_calculator(request: request) { Double in
            self.routesArray[walkings].walkingfromcurrent = Double
            
            self.walkings_calculator(request: secondrequest) { Double in
                self.routesArray[walkings].walkingtodestination = Double
                completion()

            }
        }
        
    }
        //MARK: Send Request for Walking Time
    func walkings_calculator(request: MKDirections.Request, completion: @escaping (Double) -> ()) {
        var time_duration: Double = 0
        let directionsfromcurrent = MKDirections(request: request)
        directionsfromcurrent.calculate {(response, error) -> Void in
            guard let response = response else {
               if let _ = error {
                   self.dismiss(animated: true)
                   completion(Double(0))
//                   String(localized: "walkingRouteError")
//                   let alert = UIAlertController(title: String(localized: "walkingRouteError"), message: "", preferredStyle: .alert)
//                   alert.addAction(UIAlertAction(title: String(localized: "okButton"), style: UIAlertAction.Style.default, handler: nil))
//                   self.present(alert, animated: true, completion: nil)
               }
               return
            }
            if response.routes.count > 0 {
                let route = response.routes[0]
                time_duration = (route.expectedTravelTime / 60)
                completion(Double(time_duration))
            }
        }
    }
    
    //MARK: Cancel Route Button
    func cancelRoute(){
        for selectedItemAnnotation in self.map.annotations {
            if let selectedItemAnnotation = selectedItemAnnotation as? CustomPointAnnotation, selectedItemAnnotation.customidentifier == "howToGoAnnotation" {
                self.map.removeAnnotation(selectedItemAnnotation)
            }
        }
        for BusAnnotation in self.map.annotations {
            if let BusAnnotation = BusAnnotation as? CustomPointAnnotation, BusAnnotation.customidentifier == "selectedBusAnnotation" {
                self.map.removeAnnotation(BusAnnotation)
            }
        }
        minutesFor15Button.isHidden = false
        minutesFor30Button.isHidden = false
        minutesFor45Button.isHidden = false
        metersFor500Button.isHidden = false
        metersFor1000Button.isHidden = false
        metersFor1500Button.isHidden = false
        self.map.removeOverlays(self.map.overlays)
        
        BusData()
        BusDataRepeat()
        searchController.isActive = true
        searchController.isActive = false
        floatingPanel.hide()
    }
    
    //MARK: Draw Polyline
    var toFirst: MKPolyline?
    var toFinal: MKPolyline?
    var toDestination: MKPolyline?
    func polyLines(currentLocationLatitude: Double, currentLocationLongitude: Double, startStopLatitude: Double, startStopLongitude: Double, finalStopLatitude: Double, finalStopLongitude: Double, busRouteCoordinates: [CLLocationCoordinate2D], destinationLatitude: Double, destinationLongitude: Double, polymapView: MKMapView){
        let current = CLLocationCoordinate2DMake(currentLocationLatitude, currentLocationLongitude);
        let start = CLLocationCoordinate2DMake(startStopLatitude, startStopLongitude);
        let final = CLLocationCoordinate2DMake(finalStopLatitude, finalStopLongitude);
        let destination = CLLocationCoordinate2DMake(destinationLatitude, destinationLongitude);
        
        let starttostartstop: [CLLocationCoordinate2D]
        starttostartstop = [current, start]
        let finalstoptodestination: [CLLocationCoordinate2D]
        finalstoptodestination = [final, destination]
        
        let polyline1 = MKPolyline(coordinates: starttostartstop, count: starttostartstop.count)
        let polyline2 = MKPolyline(coordinates: busRouteCoordinates, count: busRouteCoordinates.count)
        let polyline3 = MKPolyline(coordinates: finalstoptodestination, count: finalstoptodestination.count)
        toFirst = polyline1
        toFinal = polyline2
        toDestination = polyline3
        polymapView.addOverlay(polyline1)
        polymapView.addOverlay(polyline2)
        polymapView.addOverlay(polyline3)
    }
    
    //MARK: Selected Bus Service Annotation
    func selectedBusLocation(selectedservice: String){
        let busCount = busses.count
        for i in (0..<busCount){
            if busses[i].serviceName == selectedservice{
                let coordinate = CLLocationCoordinate2DMake(busses[i].latitude, busses[i].longitude)
                let BusAnnotation = CustomPointAnnotation()
                BusAnnotation.coordinate = coordinate
                BusAnnotation.title = busses[i].serviceName
                BusAnnotation.subtitle = busses[i].destination
                BusAnnotation.customidentifier = "selectedBusAnnotation"
                map.addAnnotation(BusAnnotation)
            }
        }
    }
    
    //MARK: Selected Bus Service Reload
    func selectedBusDataRepeat(selectedservice: String){
        timerForSelectedBus = Timer.scheduledTimer(withTimeInterval: 15, repeats: true, block: { _ in
            self.selectedBusLocation(selectedservice: selectedservice)
        })
    }
    
    
    
//MARK: Floating Panel Move Limit
    func floatingPanelDidMove(_ vc: FloatingPanelController) {
        if vc.isAttracting == false {
            let loc = vc.surfaceLocation
            let minY = vc.surfaceLocation(for: .half).y
            let maxY = vc.surfaceLocation(for: .tip).y+10
            vc.surfaceLocation = CGPoint(x: loc.x, y: min(max(loc.y, minY), maxY))
        }
    }

    
    
//MARK: Service Lines
    
    
    
    //MARK: Service Data
    func serviceDataCall(){
        serviceData(servicestring: "services")
    }
    
    //MARK: Service Route Coordinates
    func serviceLines(serviceName: String){
        if serviceName != ""{
            cancelServiceButton.isHidden = false
            minutesFor15Button.isHidden = true
            minutesFor30Button.isHidden = true
            minutesFor45Button.isHidden = true
            metersFor500Button.isHidden = true
            metersFor1000Button.isHidden = true
            metersFor1500Button.isHidden = true
            for services in servicesArray {
                if services.name == serviceName {
                    for serviceRoutes in services.routes{
                        for serviceCoordinates in serviceRoutes.points {
                            if serviceCoordinates.stopID != nil {
                                selectedServiceRouteStopIDs.append(Int(serviceCoordinates.stopID ?? "0") ?? 0)
                            }
                            let servicecoordinates = CLLocationCoordinate2DMake(serviceCoordinates.latitude, serviceCoordinates.longitude);
                            selectedServiceRouteCoordinates.append(servicecoordinates)
                        }
                    }
                }
            }
            servicePolyLine(selectedServiceRouteCoordinates: selectedServiceRouteCoordinates, stopID: selectedServiceRouteStopIDs, servicepPolyMapView: map)
            selectedBusLocation(selectedservice: serviceName)
            for BusAnnotation in self.map.annotations {
                if let BusAnnotation = BusAnnotation as? CustomPointAnnotation, BusAnnotation.customidentifier == "busAnnotation" {
                    self.map.removeAnnotation(BusAnnotation)
                }
            }
            selectedBusDataRepeat(selectedservice: serviceName)
            timer.invalidate()
        }
    }

    //MARK: Service Route Polyline
    var servicePolyline: MKPolyline?
    func servicePolyLine(selectedServiceRouteCoordinates: [CLLocationCoordinate2D], stopID: [Int], servicepPolyMapView: MKMapView){
        let servicepolyline = MKPolyline(coordinates: selectedServiceRouteCoordinates, count: selectedServiceRouteCoordinates.count)
        servicePolyline = servicepolyline
        servicepPolyMapView.addOverlay(servicepolyline)
        for busStops in stops {
            for stopIDs in stopID{
                if busStops.stopID == stopIDs {
                    let coordinate = CLLocationCoordinate2DMake(busStops.latitude!, busStops.longitude!)
                    let busStopAnnotation = CustomPointAnnotation()
                    busStopAnnotation.coordinate = coordinate
                    busStopAnnotation.title = busStops.name
                    busStopAnnotation.customidentifier = "busStopAnnotation"
                    map.addAnnotation(busStopAnnotation)
                }
            }
        }
    }
    
    //MARK: Service Route Cancel
    @objc func removeServicePolyline(){
        cancelServiceButton.isHidden = true
        minutesFor15Button.isHidden = false
        minutesFor30Button.isHidden = false
        minutesFor45Button.isHidden = false
        metersFor500Button.isHidden = false
        metersFor1000Button.isHidden = false
        metersFor1500Button.isHidden = false
        self.map.removeOverlays(self.map.overlays)
        for ServiceStopAnnotation in self.map.annotations {
            if let ServiceStopAnnotation = ServiceStopAnnotation as? CustomPointAnnotation, ServiceStopAnnotation.customidentifier == "busStopAnnotation" {
                self.map.removeAnnotation(ServiceStopAnnotation)
            }
        }
        for BusAnnotation in self.map.annotations {
            if let BusAnnotation = BusAnnotation as? CustomPointAnnotation, BusAnnotation.customidentifier == "selectedBusAnnotation" {
                self.map.removeAnnotation(BusAnnotation)
            }
        }
        BusData()
        BusDataRepeat()
    }
    
    
    
    
//MARK: Map
    
    
    
    //MARK: Map Location
    func mapLocation(){
        LocationManager.shared.getUserLocation { [weak self] location in DispatchQueue.main.async {
                guard let strongSelf = self else {
                    return
                }
                strongSelf.map.setRegion(MKCoordinateRegion(center: location.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)), animated: true)
                strongSelf.map.showsUserLocation = true
            }
        }
    }
    
    //MARK: Map Layout
    func setMapLayout(){
        map.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([map.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor), map.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor), map.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor), map.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor)])
    }
    
    

//MARK: Buttons Setup
    let currentlocationButton = UIButton(type: .custom)
    let zoomOutButton = UIButton(type: .custom)
    let zoomInButton = UIButton(type: .custom)
    let minutesFor15Button = UIButton(type: .custom)
    let minutesFor30Button = UIButton(type: .custom)
    let minutesFor45Button = UIButton(type: .custom)
    let metersFor500Button = UIButton(type: .custom)
    let metersFor1000Button = UIButton(type: .custom)
    let metersFor1500Button = UIButton(type: .custom)
    let cancelServiceButton = UIButton(type: .custom)
    var minute15check = true
    var minute30check = false
    var minute45check = false
    var meter500check = true
    var meter1000check = false
    var meter1500check = false
    func setButton(){
        
        
        //MARK: Current Location Button
        currentlocationButton.backgroundColor = UIColor(white: 1, alpha: 0.8)
        currentlocationButton.setImage(UIImage(systemName: "location.fill")?.resized(to: CGSize(width: 25, height: 25)).withTintColor(.systemBlue), for: .normal)
        currentlocationButton.addTarget(self, action: #selector(pressed), for: .touchUpInside)
        view.addSubview(currentlocationButton)
        
        currentlocationButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([currentlocationButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -10), currentlocationButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -60), currentlocationButton.widthAnchor.constraint(equalToConstant: 50), currentlocationButton.heightAnchor.constraint(equalToConstant: 50)])
        currentlocationButton.layer.cornerRadius = 25
        currentlocationButton.layer.masksToBounds = true
        
        //MARK: Zoom Out Button
        zoomOutButton.backgroundColor = UIColor(white: 1, alpha: 0.8)
        zoomOutButton.setImage(UIImage(systemName: "minus.square.fill")?.resized(to: CGSize(width: 25, height: 25)).withTintColor(.systemBlue), for: .normal)
        zoomOutButton.addTarget(self, action: #selector(zoomOut), for: .touchUpInside)
        view.addSubview(zoomOutButton)
        
        zoomOutButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([zoomOutButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -10), zoomOutButton.bottomAnchor.constraint(equalTo: currentlocationButton.topAnchor, constant: -20), zoomOutButton.widthAnchor.constraint(equalToConstant: 50), zoomOutButton.heightAnchor.constraint(equalToConstant: 50)])
        zoomOutButton.layer.cornerRadius = 10
        zoomOutButton.layer.maskedCorners = [.layerMaxXMaxYCorner, .layerMinXMaxYCorner]
        
        //MARK: Zoom In Button
        zoomInButton.backgroundColor = UIColor(white: 1, alpha: 0.8)
        zoomInButton.setImage(UIImage(systemName: "plus.square.fill")?.resized(to: CGSize(width: 25, height: 25)).withTintColor(.systemBlue), for: .normal)
        zoomInButton.addTarget(self, action: #selector(zoomIn), for: .touchUpInside)
        view.addSubview(zoomInButton)
        
        zoomInButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([zoomInButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -10), zoomInButton.bottomAnchor.constraint(equalTo: zoomOutButton.topAnchor), zoomInButton.widthAnchor.constraint(equalToConstant: 50), zoomInButton.heightAnchor.constraint(equalToConstant: 50)])
        zoomInButton.layer.cornerRadius = 10
        zoomInButton.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]
        
        
        //MARK: 15 Minutes Button
        minutesFor15Button.backgroundColor = UIColor(red: 10/255, green: 96/255, blue: 254/255, alpha: 0.5)
        minutesFor15Button.setTitle("15", for: .normal)
        minutesFor15Button.setTitleColor(.black, for: .normal)
        minutesFor15Button.titleLabel?.font = minutesFor15Button.titleLabel?.font.withSize(14)
        minutesFor15Button.addTarget(self, action: #selector(minute15), for: .touchUpInside)
        view.addSubview(minutesFor15Button)
        
        minutesFor15Button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([minutesFor15Button.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 10), minutesFor15Button.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10), minutesFor15Button.widthAnchor.constraint(equalToConstant: 30), minutesFor15Button.heightAnchor.constraint(equalToConstant: 25)])
        minutesFor15Button.layer.cornerRadius = 8
        minutesFor15Button.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMinXMinYCorner]
        
        //MARK: 30 Minutes Button
        minutesFor30Button.backgroundColor = UIColor(white: 1, alpha: 0.8)
        minutesFor30Button.setTitle("30", for: .normal)
        minutesFor30Button.setTitleColor(.black, for: .normal)
        minutesFor30Button.titleLabel?.font = minutesFor15Button.titleLabel?.font.withSize(14)
        minutesFor30Button.addTarget(self, action: #selector(minute30), for: .touchUpInside)
        view.addSubview(minutesFor30Button)
        
        minutesFor30Button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([minutesFor30Button.leadingAnchor.constraint(equalTo: minutesFor15Button.trailingAnchor), minutesFor30Button.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10), minutesFor30Button.widthAnchor.constraint(equalToConstant: 30), minutesFor30Button.heightAnchor.constraint(equalToConstant: 25)])
        
        //MARK: 45 Minutes Button
        minutesFor45Button.backgroundColor = UIColor(white: 1, alpha: 0.8)
        minutesFor45Button.setTitle("45 \(String(localized: "min"))", for: .normal)
        minutesFor45Button.setTitleColor(.black, for: .normal)
        minutesFor45Button.titleLabel?.font = minutesFor15Button.titleLabel?.font.withSize(14)
        minutesFor45Button.addTarget(self, action: #selector(minute45), for: .touchUpInside)
        view.addSubview(minutesFor45Button)
        minutesFor45Button.layer.cornerRadius = 8
        minutesFor45Button.layer.maskedCorners = [.layerMaxXMaxYCorner, .layerMaxXMinYCorner]
        
        minutesFor45Button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([minutesFor45Button.leadingAnchor.constraint(equalTo: minutesFor30Button.trailingAnchor), minutesFor45Button.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10), minutesFor45Button.widthAnchor.constraint(equalToConstant: 60), minutesFor45Button.heightAnchor.constraint(equalToConstant: 25)])
        
        //MARK: 1500 Meters Button
        metersFor1500Button.backgroundColor = UIColor(white: 1, alpha: 0.8)
        metersFor1500Button.setTitle("1500 m", for: .normal)
        metersFor1500Button.setTitleColor(.black, for: .normal)
        metersFor1500Button.titleLabel?.font = minutesFor15Button.titleLabel?.font.withSize(14)
        metersFor1500Button.addTarget(self, action: #selector(meter1500), for: .touchUpInside)
        view.addSubview(metersFor1500Button)
        
        metersFor1500Button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([metersFor1500Button.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -10), metersFor1500Button.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10), metersFor1500Button.widthAnchor.constraint(equalToConstant: 70), metersFor1500Button.heightAnchor.constraint(equalToConstant: 25)])
        metersFor1500Button.layer.cornerRadius = 8
        metersFor1500Button.layer.maskedCorners = [.layerMaxXMaxYCorner, .layerMaxXMinYCorner]
        
        //MARK: 1000 Meters Button
        metersFor1000Button.backgroundColor = UIColor(white: 1, alpha: 0.8)
        metersFor1000Button.setTitle("1000", for: .normal)
        metersFor1000Button.setTitleColor(.black, for: .normal)
        metersFor1000Button.titleLabel?.font = minutesFor15Button.titleLabel?.font.withSize(14)
        metersFor1000Button.addTarget(self, action: #selector(meter1000), for: .touchUpInside)
        view.addSubview(metersFor1000Button)

        metersFor1000Button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([metersFor1000Button.trailingAnchor.constraint(equalTo: metersFor1500Button.leadingAnchor), metersFor1000Button.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10), metersFor1000Button.widthAnchor.constraint(equalToConstant: 60), metersFor1000Button.heightAnchor.constraint(equalToConstant: 25)])
        
        //MARK: 500 Meters Button
        metersFor500Button.backgroundColor = UIColor(red: 10/255, green: 96/255, blue: 254/255, alpha: 0.5)
        metersFor500Button.setTitle("500", for: .normal)
        metersFor500Button.setTitleColor(.black, for: .normal)
        metersFor500Button.titleLabel?.font = minutesFor15Button.titleLabel?.font.withSize(14)
        metersFor500Button.addTarget(self, action: #selector(meter500), for: .touchUpInside)
        view.addSubview(metersFor500Button)
        
        metersFor500Button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([metersFor500Button.trailingAnchor.constraint(equalTo: metersFor1000Button.leadingAnchor), metersFor500Button.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10), metersFor500Button.widthAnchor.constraint(equalToConstant: 60), metersFor500Button.heightAnchor.constraint(equalToConstant: 25)])
        metersFor500Button.layer.cornerRadius = 8
        metersFor500Button.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMinXMinYCorner]
        
        //MARK: Cancel Service Button
        cancelServiceButton.backgroundColor = UIColor(white: 1, alpha: 1)
        cancelServiceButton.setTitle(String(localized: "cancelButton"), for: .normal)
        cancelServiceButton.setTitleColor(.black, for: .normal)
        cancelServiceButton.titleLabel?.font = cancelServiceButton.titleLabel?.font.withSize(14)
        cancelServiceButton.addTarget(self, action: #selector(removeServicePolyline), for: .touchUpInside)
        view.addSubview(cancelServiceButton)
        
        cancelServiceButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([cancelServiceButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -10), cancelServiceButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10), cancelServiceButton.widthAnchor.constraint(equalToConstant: 60), cancelServiceButton.heightAnchor.constraint(equalToConstant: 25)])
        cancelServiceButton.layer.cornerRadius = 8
        cancelServiceButton.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMaxXMaxYCorner]
    }
    
    //MARK: Current Location Button Action
    @objc func pressed() {
        zoom_count = 0
        LocationManager.shared.getUserLocation { [weak self] location in DispatchQueue.main.async {
                guard let strongSelf = self else {
                    return
                }
                strongSelf.map.setRegion(MKCoordinateRegion(center: location.coordinate, span:MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)), animated: true)
            }
        }
    }
    
    var zoom_count = 0
    //MARK: Zoom In Button Action
    @objc func zoomIn() {
        zoomMap(byFactor: 0.5)
        zoom_count = zoom_count-1
    }
    
    //MARK: Zoom Out Button Action
    @objc func zoomOut() {
        if zoom_count < 14 {
            zoomMap(byFactor: 2)
            zoom_count = zoom_count+1
        }
    }
    
    //MARK: 15 Minutes Button Action
    @objc func minute15() {
        minutesFor15Button.backgroundColor = UIColor(red: 10/255, green: 96/255, blue: 254/255, alpha: 0.5)
        minutesFor30Button.backgroundColor = UIColor(white: 1, alpha: 0.8)
        minutesFor45Button.backgroundColor = UIColor(white: 1, alpha: 0.8)
        minute15check = true
        minute30check = false
        minute45check = false
    }
    
    //MARK: 30 Minutes Button Action
    @objc func minute30() {
        minutesFor15Button.backgroundColor = UIColor(white: 1, alpha: 0.8)
        minutesFor30Button.backgroundColor = UIColor(red: 10/255, green: 96/255, blue: 254/255, alpha: 0.5)
        minutesFor45Button.backgroundColor = UIColor(white: 1, alpha: 0.8)
        minute15check = false
        minute30check = true
        minute45check = false
    }
    
    //MARK: 45 Minutes Button Action
    @objc func minute45() {
        minutesFor15Button.backgroundColor = UIColor(white: 1, alpha: 0.8)
        minutesFor30Button.backgroundColor = UIColor(white: 1, alpha: 0.8)
        minutesFor45Button.backgroundColor = UIColor(red: 10/255, green: 96/255, blue: 254/255, alpha: 0.5)
        minute15check = false
        minute30check = false
        minute45check = true
    }
    
    //MARK: 500 Meter Button Action
    @objc func meter500() {
        metersFor500Button.backgroundColor = UIColor(red: 10/255, green: 96/255, blue: 254/255, alpha: 0.5)
        metersFor1000Button.backgroundColor = UIColor(white: 1, alpha: 0.8)
        metersFor1500Button.backgroundColor = UIColor(white: 1, alpha: 0.8)
        meter500check = true
        meter1000check = false
        meter1500check = false
    }
    
    //MARK: 1000 Meter Button Action
    @objc func meter1000() {
        metersFor500Button.backgroundColor = UIColor(white: 1, alpha: 0.8)
        metersFor1000Button.backgroundColor = UIColor(red: 10/255, green: 96/255, blue: 254/255, alpha: 0.5)
        metersFor1500Button.backgroundColor = UIColor(white: 1, alpha: 0.8)
        meter500check = false
        meter1000check = true
        meter1500check = false
    }
    
    //MARK: 1500 Meter Button Action
    @objc func meter1500() {
        metersFor500Button.backgroundColor = UIColor(white: 1, alpha: 0.8)
        metersFor1000Button.backgroundColor = UIColor(white: 1, alpha: 0.8)
        metersFor1500Button.backgroundColor = UIColor(red: 10/255, green: 96/255, blue: 254/255, alpha: 0.5)
        meter500check = false
        meter1000check = false
        meter1500check = true
    }
    
    
//MARK: Bus Location Annotation
    var BusAnnotation: CustomPointAnnotation!
    var BusAnnotationView:MKPinAnnotationView!
    //MARK: Check and mark bus locations in every 15 second
    @objc func busLocations(){
        let busCount = busses.count
        for i in (0..<busCount){
            let coordinate = CLLocationCoordinate2DMake(busses[i].latitude, busses[i].longitude)
            let BusAnnotation = CustomPointAnnotation()
            BusAnnotation.coordinate = coordinate
            BusAnnotation.title = busses[i].serviceName
            BusAnnotation.subtitle = busses[i].destination
            BusAnnotation.customidentifier = "busAnnotation"
            map.addAnnotation(BusAnnotation)
        }
    }
    
    

//MARK: Zoom in and Out Function
    func zoomMap(byFactor delta: Double) {
        var region: MKCoordinateRegion = self.map.region
        var span: MKCoordinateSpan = map.region.span
        span.latitudeDelta *= delta
        span.longitudeDelta *= delta
        region.span = span
        map.setRegion(region, animated: true)
    }
    
    
    
//MARK: Bus Data
    func BusDataRepeat(){
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true, block: { _ in
            self.BusData()
        })
    }
    @objc func BusData(){
        let basedata = GetBaseData()
        basedata.busCompletionHandler { busses, error, message in
            self.busses = busses ?? []
        }
        basedata.getBusBaseData(endPoint: "vehicle_locations")
    }
    
    
    
//MARK: Bus Stops Data
    func BusStopsData(){
        let basedata = GetBaseData()
        basedata.completionHandler { stops, error, message in
            
            self.stops = stops ?? []
        }
        basedata.getStopsBaseData(endPoint: "stops")
    }
    
    
    
//MARK: Time Data
    func timeData(timestring: String){
        let basedata = GetBaseData()
        basedata.timeCompletionHandler { times, status, message in
            for times_append in times! {
                self.times.append(times_append)
            }
        }
        basedata.getTimeBaseData(endPoint: timestring)
    }

//MARK: Service Data
    func serviceData(servicestring: String){
        let basedata = GetBaseData()
        basedata.serviceCompletionHandler { services, status, message in
            self.servicesArray = services ?? []
        }
        basedata.getServiceData(endPoint: servicestring)
    }
    
    
    
    let selectedItemAnnotation = CustomPointAnnotation()
}



//MARK: Image Resize Extension
extension UIImage {
    public func resized(to target: CGSize) -> UIImage {
        let ratio = min(
            target.height / size.height, target.width / size.width
        )
        let new = CGSize(
            width: size.width * ratio, height: size.height * ratio
        )
        let renderer = UIGraphicsImageRenderer(size: new)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: new))
        }
    }
}



//MARK: Pin With Image Extension
extension HomeViewController : MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView?  {
        
        guard let annotation = annotation as? CustomPointAnnotation else {
            return nil
        }
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: "reuseIdentifier")
        if annotationView == nil {
            annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: "reuseIdentifier")
            annotationView?.canShowCallout = true

        } else {
            annotationView?.annotation = annotation
        }
        
        //MARK: Bus Annotation
        if annotation.customidentifier == "busAnnotation" {
            annotationView?.image = UIImage(systemName: "bus")!.withRenderingMode(.alwaysOriginal).withTintColor(.systemBlue).resized(to: CGSize(width: 15, height: 15))
        }
        
        //MARK: Selected Bus Annotation
        if annotation.customidentifier == "selectedBusAnnotation" {
            annotationView?.image = UIImage(systemName: "bus")!.withRenderingMode(.alwaysOriginal).withTintColor(.systemBlue).resized(to: CGSize(width: 15, height: 15))
        }
        
        //MARK: Selected Bus Annotation
        if annotation.customidentifier == "selectedServiceBusAnnotation" {
            annotationView?.image = UIImage(systemName: "bus")!.withRenderingMode(.alwaysOriginal).withTintColor(.systemBlue).resized(to: CGSize(width: 15, height: 15))
        }
        
        //MARK: Selected Bus Annotation
        if annotation.customidentifier == "busStopAnnotation" {
            annotationView?.image = UIImage(named: "bus-stop-logo")!.withRenderingMode(.alwaysOriginal).withTintColor(.systemBlue).resized(to: CGSize(width: 25, height: 25))
        }
        
        //MARK: Location Annotation
        if annotation.customidentifier == "howToGoAnnotation" {
            let pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: String(annotation.hash))
            let rightButton = UIButton(type: .contactAdd)
            rightButton.setImage(UIImage(named: "customAnnotationButton"), for: .normal)
            rightButton.tag = annotation.hash
            pinView.animatesDrop = true
            pinView.canShowCallout = true
            pinView.rightCalloutAccessoryView = rightButton
            rightButton.addTarget(self, action: #selector(makeRoad), for: .touchUpInside)
            return pinView
        }
        return annotationView
    }
    
    
    
    //MARK: Select Annotation
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView)  {
        
        let annotation = view.annotation as? CustomPointAnnotation
        
        if annotation?.customidentifier == "busAnnotation" {
            serviceLines(serviceName: annotation?.title ?? "")
        }
    }
    
    
    
    //MARK: Polyline Addition
    func mapView(_ mapView : MKMapView , rendererFor overlay: MKOverlay) ->MKOverlayRenderer! {

        if overlay is MKPolyline {
            if ( toFirst  != nil) && (toFinal != nil ) && (toDestination != nil ) {
                if overlay as? MKPolyline  == toFirst {
                    let polyLineRenderer = MKPolylineRenderer(overlay: overlay)
                    polyLineRenderer.strokeColor = .systemBlue
                    polyLineRenderer.lineWidth = 6
                    return polyLineRenderer
                }
                
                if overlay as? MKPolyline  == toFinal {
                    let polyLineRenderer = MKPolylineRenderer(overlay: overlay)
                    polyLineRenderer.strokeColor = .systemRed
                    polyLineRenderer.lineWidth = 6
                    return polyLineRenderer
                }
                
                if overlay as? MKPolyline  == toDestination {
                    let polyLineRenderer = MKPolylineRenderer(overlay: overlay)
                    polyLineRenderer.strokeColor = .systemBlue
                    polyLineRenderer.lineWidth = 6
                    return polyLineRenderer
                }
            }
        }
        
        if overlay is MKPolyline {
            if (servicePolyline != nil) {
                if overlay as? MKPolyline  == servicePolyline {
                    let polyLineRenderer = MKPolylineRenderer(overlay: overlay)
                    polyLineRenderer.strokeColor = .systemRed
                    polyLineRenderer.lineWidth = 6
                    return polyLineRenderer
                }
            }
        }
        return nil
    }
}



//MARK: Adress Search Tableview
extension HomeViewController: UITableViewDelegate, UITableViewDataSource {
    
    //MARK: Row Number
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return matchingItems.count
    }
    
    //MARK: Cell Content
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: HowToGoSearchTableCellSetup.identifer, for: indexPath) as! HowToGoSearchTableCellSetup
        let selectedItem = matchingItems[indexPath.row].placemark
        cell.titleLabel?.text = selectedItem.name
        cell.detailLabel?.text = parseAddress(selectedItem: selectedItem)
        return cell
    }
    
    //MARK: Cell Height
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    //MARK: Select Function
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        
        //MARK: Hidden
        howToGoSearchTable.isHidden = true
        zoomInButton.isHidden = false
        zoomOutButton.isHidden = false
        currentlocationButton.isHidden = false
        map.isHidden = false
        searchController.isActive = false
        searchController.searchBar.text = nil
        searchController.searchBar.endEditing(true)
        
        //MARK: Selected Location Coordinates and Annotation
        selectedItemCoordination = matchingItems[indexPath.row].placemark.coordinate
        let selectedItemName = matchingItems[indexPath.row].placemark.name
        let selectedItemSubtitle = matchingItems[indexPath.row].placemark.compactAddress
        for selectedItemAnnotation in self.map.annotations {
            if let selectedItemAnnotation = selectedItemAnnotation as? CustomPointAnnotation, selectedItemAnnotation.customidentifier == "howToGoAnnotation" {
                self.map.removeAnnotation(selectedItemAnnotation)
            }
        }
        selectedItemAnnotation.coordinate = selectedItemCoordination
        selectedItemAnnotation.title = selectedItemName
        selectedItemAnnotation.subtitle = selectedItemSubtitle
        selectedItemAnnotation.customidentifier = "howToGoAnnotation"
        map.addAnnotation(selectedItemAnnotation)
        map.selectAnnotation(selectedItemAnnotation, animated: true)
    }
}
