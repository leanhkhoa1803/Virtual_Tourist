//
//  FlickrService.swift
//  vitural_tourist
//
//  Created by KhoaLA8 on 11/4/24.
//

import Foundation

class FlickrService {
    
    enum Endpoints {
        static let base = "https://api.flickr.com/services/rest"
        static let photoSearch = "?method=flickr.photos.search"
        static let apiKey = "e2d55078b7114f0a56d94448fb5c895c"
        
        case getPhotos(Double, Double, Int)
        
        var stringValue: String {
            switch self {
            case .getPhotos(let lat, let lon, let page):
                return Endpoints.base + Endpoints.photoSearch + "&extras=url_sq" + "&api_key=\(Endpoints.apiKey)" + "&lat=\(lat)" + "&lon=\(lon)" + "&per_page=30" + "&page=\(page)" + "&format=json&nojsoncallback=1"
            }
        }
        
        var url: URL {
            return URL(string: stringValue)!
        }
    }
    
    class func searchPhotos(lat: Double, lon: Double, page: Int, completion: @escaping (Photos?, Error?) -> Void) {
        var request = URLRequest(url: Endpoints.getPhotos(lat, lon, page).url)
        request.httpMethod = "GET"
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if error != nil {
                completion(nil, error)
            }
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }
            do {
                let response = try JSONDecoder().decode(PhotoSearchResponse.self, from: data)
                DispatchQueue.main.async {
                    completion(response.photos, nil)
                }
            } catch let error as NSError{
                DispatchQueue.main.async {
                    completion(nil, error)
                    print("Error decoding data." + error.localizedDescription)
                }
            }
        }
        task.resume()
    }
    
    class func downloadPhoto(url: URL, completion: @escaping (Data?, Error?) -> Void) {
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data else {
                completion(nil, error)
                print("no data, or there was an error")
                return
            }
            completion(data, nil)
        }
        task.resume()
    }
    
}
