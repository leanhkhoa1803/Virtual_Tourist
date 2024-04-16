//
//  AlbumLocationController.swift
//  vitural_tourist
//
//  Created by KhoaLA8 on 12/4/24.
//

import Foundation
import UIKit
import MapKit
import CoreData


class AlbumLocationController : UIViewController, MKMapViewDelegate, UICollectionViewDelegate, UICollectionViewDataSource{
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var photoCollection: UICollectionView!
    @IBOutlet weak var noPhotoLabel: UILabel!
    @IBOutlet weak var reloadButton: UIBarButtonItem!
    @IBOutlet weak var flowLayout: UICollectionViewFlowLayout!
    var activityIndicator: UIActivityIndicatorView!
    
    let annotation = MKPointAnnotation()
    var lat: Double = 0.0
    var lon: Double = 0.0
    var page: Int = 0
    var cellsPerRow = 0
    var photos: [PhotoDetail] = []
    var corePhotos: [Photo] = []
    var pin: Pin!
    var dataController: DataController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initIndicator()
        mapView.delegate = self
        self.photoCollection.delegate = self
        
        let space:CGFloat = 3.0
        let dimension = (view.frame.size.width - (2 * space)) / 3.0
        let width = (photoCollection.bounds.width - (10.0 * (space - 1))) / space
        
        flowLayout.minimumInteritemSpacing = space
        flowLayout.minimumLineSpacing = space
        flowLayout.itemSize = CGSize(width: dimension, height: dimension)
        
        corePhotos = getCorePhotos()
        if corePhotos.count > 0 {
            for corePhoto in corePhotos {
                corePhotos.append(corePhoto)
                photoCollection.reloadData()
            }
        } else {
            getPhotos()
        }
    }
    
    func initIndicator(){
        activityIndicator = UIActivityIndicatorView (style: UIActivityIndicatorView.Style.gray)
        self.view.addSubview(activityIndicator)
        activityIndicator.bringSubviewToFront(self.view)
        activityIndicator.center = self.view.center
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        showActivityIndicator()
        showSelectedPin()
        getPhotos()
    }
    
    @IBAction func reloadPhotos(_ sender: Any) {
        showActivityIndicator()
        reloadButton.isEnabled = false
        clearPhotos()
        photos = []
        corePhotos = []
        getPhotos()
        photoCollection.reloadData()
    }
    
    func clearPhotos() {
        for corePhoto in corePhotos {
            dataController.viewContext.delete(corePhoto)
            do {
                try self.dataController.viewContext.save()
                hideActivityIndicator()
            } catch {
                self.showAlert(message: "There was an error clearing the album", title: "Error")
            }
        }
    }
    
    func showSelectedPin() {
        mapView.removeAnnotations(mapView.annotations)
        annotation.coordinate.latitude = lat
        annotation.coordinate.longitude = lon
        mapView.addAnnotation(annotation)
        mapView.showAnnotations(mapView.annotations, animated: true)
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
    
    func getCorePhotos() -> [Photo] {
        let fetchRequest: NSFetchRequest<Photo> = Photo.fetchRequest()
        let predicate = NSPredicate(format: "pin == %@", pin)
        fetchRequest.predicate = predicate
        do {
            let result = try dataController.viewContext.fetch(fetchRequest)
            corePhotos = result
            hideActivityIndicator()
        } catch {
            showAlert(message: "There was an error retrieving photos", title: "Error")
            hideActivityIndicator()
        }
        return corePhotos
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return corePhotos.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        self.reloadButton.isEnabled = false
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCollectionViewCell", for: indexPath) as! PhotoCollectionViewCell
        cell.imgView.image = UIImage(named: "imagePlaceHolder")
        let cellImage = corePhotos[indexPath.row]
        
        if cellImage.image != nil {
            DispatchQueue.main.async{
                cell.imgView.image = UIImage(data: cellImage.image!)
                self.reloadButton.isEnabled = true
            }
        } else {
            
            if cellImage.imageUrl != nil {
                let url = URL(string: cellImage.imageUrl ?? "")
                FlickrService.downloadPhoto(url: url!) { (data, error) in
                    if (data != nil) {
                        DispatchQueue.main.async {
                            cellImage.image = data
                            cellImage.pin = self.pin
                            do {
                                try self.dataController.viewContext.save()
                            } catch {
                                print("There was an error saving photos")
                            }
                            DispatchQueue.main.async {
                                cell.imgView?.image = UIImage(data: data!)
                            }
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.showAlert(message: "There was an error downloading photos", title: "Error")
                        }
                        
                    }
                    DispatchQueue.main.async {
                        self.reloadButton.isEnabled = true
                    }
                    
                }
            }
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let alertVC = UIAlertController(title: "Delete", message: "Do you want to delete this photo?", preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: "Delete", style: .default, handler: { (action: UIAlertAction) in
            let corePhoto = self.corePhotos[indexPath.row]
            self.dataController.viewContext.delete(corePhoto)
            self.corePhotos.remove(at: indexPath.row)
            do {
                try self.dataController.viewContext.save()
            } catch {
                self.showAlert(message: "There was an error deleting photo", title: "Error")
            }
            self.photoCollection.reloadData()
        }))
        alertVC.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (action: UIAlertAction) in
            alertVC.dismiss(animated: true, completion: nil)
        }))
        self.present(alertVC, animated: true)
    }
    
    // MARK: Collection View Layout
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let flowLayout = collectionViewLayout as! UICollectionViewFlowLayout
        let totalSpace = flowLayout.sectionInset.left + flowLayout.sectionInset.right + (flowLayout.minimumInteritemSpacing * CGFloat(cellsPerRow - 1))
        let size = Int((photoCollection.bounds.width - totalSpace) / CGFloat(cellsPerRow))
        return CGSize(width: size, height: size)
    }
    
    override func viewWillLayoutSubviews() {
        guard let flowLayout = photoCollection.collectionViewLayout as? UICollectionViewFlowLayout else {
            return
        }
        if UIDevice.current.orientation == .portrait {
            cellsPerRow = 3
        } else {
            cellsPerRow = 5
        }
        
        flowLayout.invalidateLayout()
    }
    
    func getPhotos() {
        showActivityIndicator()
        FlickrService.searchPhotos(lat: lat, lon: lon, page: page, completion: { (photos, error) in
            if (photos != nil) {
                if photos?.pages == 0 {
                    self.noPhotoLabel.isHidden = false
                    self.reloadButton.isEnabled = false
                    self.hideActivityIndicator()
                } else {
                    self.photos = (photos?.photo)!
                    let randomPage = Int.random(in: 1...photos!.pages)
                    self.page = randomPage
                    self.getImageURL()
                    self.photoCollection.reloadData()
                    self.hideActivityIndicator()
                }
            } else {
                self.showAlert(message: "There was an error retrieving photos", title: "Error")
                self.reloadButton.isEnabled = true
                self.hideActivityIndicator()
            }
        })
    }
    
    func getImageURL() {
        for photo in photos {
            let corePhoto = Photo(context: dataController.viewContext)
            corePhoto.imageUrl = photo.urlSq
            corePhoto.pin = pin
            corePhotos.append(corePhoto)
            do {
                try self.dataController.viewContext.save()
            } catch {
                print("Unable to get image url")
            }
        }
        DispatchQueue.main.async {
            self.photoCollection.reloadData()
        }
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
