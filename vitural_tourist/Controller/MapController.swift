//
//  MapController.swift
//  vitural_tourist
//
//  Created by KhoaLA8 on 11/4/24.
//

import UIKit
import MapKit
import CoreData

class MapController: UIViewController, MKMapViewDelegate {
    
    @IBOutlet weak var toolbar: UIToolbar!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var deleteLabel: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    var annotations = [MKPointAnnotation]()
    var annotation = MKPointAnnotation()
    var pins: [Pin] = []
    var dataController: DataController!
    var isEdit = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        showActivityIndicator()
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        dataController = appDelegate.dataController
        
        let gestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleTap))
        mapView.addGestureRecognizer(gestureRecognizer)
        
        pins = getPins()
        if pins.count > 0 {
            for pin in pins {
                let annotation = MKPointAnnotation()
                annotation.coordinate = CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)
                mapView.addAnnotation(annotation)
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        showActivityIndicator()
        mapView.deselectAnnotation(annotations as? MKAnnotation, animated: false)
        hideActivityIndicator()
    }
    
    @IBAction func handleEdit(_ sender: Any) {
        if (!self.isEdit) {
            toolbar.isHidden = false
            deleteLabel.isHidden = false
            self.isEdit = true
        } else {
            toolbar.isHidden = true
            deleteLabel.isHidden = true
            self.isEdit = false
        }
    }
    @objc func handleTap(gestureReconizer: UIGestureRecognizer) {
        if gestureReconizer.state == .began {
            let location = gestureReconizer.location(in: mapView)
            let coordinate = mapView.convert(location,toCoordinateFrom: mapView)
            let pin = Pin(context: dataController.viewContext)
            pin.latitude = coordinate.latitude
            pin.longitude = coordinate.longitude
            let annotation = MKPointAnnotation()
            annotation.coordinate = CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)
            mapView.addAnnotation(annotation)
            do {
                try dataController.viewContext.save()
            } catch {
                showAlert(message: "There was an error saving the pin", title: "Error")
            }
            pins.append(pin)
            mapView.reloadInputViews()
            hideActivityIndicator()
        }
    }
    
    func getPins() -> [Pin] {
        let fetchRequest: NSFetchRequest<Pin> = Pin.fetchRequest()
        do {
            let result = try dataController.viewContext.fetch(fetchRequest)
            pins = result
            hideActivityIndicator()
        } catch {
            showAlert(message: "There was an error retrieving pins", title: "Error")
            hideActivityIndicator()
        }
        return pins
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard annotation is MKPointAnnotation else { print("no mkpointannotaions"); return nil }
        let reuseId = "pin"
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? MKPinAnnotationView
        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            pinView!.pinTintColor = .red
        }
        else {
            pinView!.annotation = annotation
        }
        return pinView
    }
    
    // MARK: Segue to Photo Album on pin tap
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        // delete pin on tap when editing
        if isEdit, let viewAnnotation = view.annotation {
            for pin in pins {
                if pin.latitude == view.annotation?.coordinate.latitude && pin.longitude == view.annotation?.coordinate.longitude {
                    dataController.viewContext.delete(pin)
                }
            }
            do {
                try dataController.viewContext.save()
            } catch {
                showAlert(message: "There was an error deleting pins", title: "Error")
            }
            mapView.removeAnnotation(viewAnnotation)
            return
        }
        
        let controller = storyboard?.instantiateViewController(withIdentifier: "AlbumLocationController") as! AlbumLocationController
        controller.lat = view.annotation?.coordinate.latitude ?? 0.0
        controller.lon = view.annotation?.coordinate.longitude ?? 0.0
        for pin in pins {
            if pin.latitude == view.annotation?.coordinate.latitude && pin.longitude == view.annotation?.coordinate.longitude {
                controller.pin = pin
            }
        }
        controller.dataController = dataController
        self.navigationController?.pushViewController(controller, animated: true)
    }
    
    func showAlert(message: String, title: String) {
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alertVC, animated: true)
    }
    
    func showActivityIndicator() {
        activityIndicator.isHidden = false
        activityIndicator.startAnimating()
    }
    
    func hideActivityIndicator() {
        activityIndicator.stopAnimating()
        activityIndicator.isHidden = true
    }
}

