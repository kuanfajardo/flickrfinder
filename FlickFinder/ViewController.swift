//
//  ViewController.swift
//  FlickFinder
//
//  Created by Jarrod Parkes on 11/5/15.
//  Copyright © 2015 Udacity. All rights reserved.
//

import UIKit

// MARK: - ViewController: UIViewController

class ViewController: UIViewController {
    
    // MARK: Properties
    
    var keyboardOnScreen = false
    
    // MARK: Outlets
    
    @IBOutlet weak var photoImageView: UIImageView!
    @IBOutlet weak var photoTitleLabel: UILabel!
    @IBOutlet weak var phraseTextField: UITextField!
    @IBOutlet weak var phraseSearchButton: UIButton!
    @IBOutlet weak var latitudeTextField: UITextField!
    @IBOutlet weak var longitudeTextField: UITextField!
    @IBOutlet weak var latLonSearchButton: UIButton!
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        phraseTextField.delegate = self
        latitudeTextField.delegate = self
        longitudeTextField.delegate = self
        // FIX: As of Swift 2.2, using strings for selectors has been deprecated. Instead, #selector(methodName) should be used.
        subscribeToNotification(UIKeyboardWillShowNotification, selector: #selector(keyboardWillShow))
        subscribeToNotification(UIKeyboardWillHideNotification, selector: #selector(keyboardWillHide))
        subscribeToNotification(UIKeyboardDidShowNotification, selector: #selector(keyboardDidShow))
        subscribeToNotification(UIKeyboardDidHideNotification, selector: #selector(keyboardDidHide))
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        unsubscribeFromAllNotifications()
    }
    
    // MARK: Search Actions
    
    @IBAction func searchByPhrase(sender: AnyObject) {

        userDidTapView(self)
        setUIEnabled(false)
        
        if !phraseTextField.text!.isEmpty {
            photoTitleLabel.text = "Searching..."
            // TODO: Set necessary parameters!
            let methodParameters: [String: String!] = [
                Constants.FlickrParameterKeys.APIKey : Constants.FlickrParameterValues.APIKey,
                Constants.FlickrParameterKeys.Format : Constants.FlickrParameterValues.ResponseFormat,
                Constants.FlickrParameterKeys.Method : Constants.FlickrParameterValues.SearchMethod,
                Constants.FlickrParameterKeys.NoJSONCallback : Constants.FlickrParameterValues.DisableJSONCallback,
                Constants.FlickrParameterKeys.Extras : Constants.FlickrParameterValues.MediumURL,
                Constants.FlickrParameterKeys.SafeSearch : Constants.FlickrParameterValues.UseSafeSearch,
                Constants.FlickrParameterKeys.Text : phraseTextField.text]
            
            displayImageFromFlickrBySearch(methodParameters)
        } else {
            setUIEnabled(true)
            photoTitleLabel.text = "Phrase Empty."
        }
    }
    
    @IBAction func searchByLatLon(sender: AnyObject) {

        userDidTapView(self)
        setUIEnabled(false)
        
        if isTextFieldValid(latitudeTextField, forRange: Constants.Flickr.SearchLatRange) && isTextFieldValid(longitudeTextField, forRange: Constants.Flickr.SearchLonRange) {
            photoTitleLabel.text = "Searching..."
            // TODO: Set necessary parameters!
            let methodParameters: [String: String!] = [
                Constants.FlickrParameterKeys.APIKey : Constants.FlickrParameterValues.APIKey,
                Constants.FlickrParameterKeys.Format : Constants.FlickrParameterValues.ResponseFormat,
                Constants.FlickrParameterKeys.Method : Constants.FlickrParameterValues.SearchMethod,
                Constants.FlickrParameterKeys.NoJSONCallback : Constants.FlickrParameterValues.DisableJSONCallback,
                Constants.FlickrParameterKeys.Extras : Constants.FlickrParameterValues.MediumURL,
                Constants.FlickrParameterKeys.SafeSearch : Constants.FlickrParameterValues.UseSafeSearch,
                Constants.FlickrParameterKeys.BoundingBox : bboxString()]
            
            displayImageFromFlickrBySearch(methodParameters)
        }
        else {
            setUIEnabled(true)
            photoTitleLabel.text = "Lat should be [-90, 90].\nLon should be [-180, 180]."
        }
    }
    
    // MARK: Flickr API
    
    private func displayImageFromFlickrBySearch(methodParameters: [String:AnyObject]) {
        
        // Create URL
        let url = flickrURLFromParameters(methodParameters)
        
        // TODO: Make request to Flickr!
        let session = NSURLSession.sharedSession()
        let request = NSURLRequest(URL: url)
        
        let task = session.dataTaskWithRequest(request) { (data, response, error) in
            
            // if an error occurs, print it and re-enable the UI
            func displayError(error: String) {
                print(error)
                print("URL at time of error: \(url)")
                performUIUpdatesOnMain {
                    self.setUIEnabled(true)
                    self.photoTitleLabel.text = "No photo returned... try again"
                    self.photoImageView.image = nil
                }
            }
            
            
            /* GUARD: Was there an error? */
            guard (error == nil) else {
                displayError("There was an error in the request: \(error!.localizedDescription)")
                return
            }
            
            /* GUARD: Successful Request? */
            guard let statusCode = (response as? NSHTTPURLResponse)?.statusCode where statusCode >= 200 && statusCode <= 299 else {
                displayError("Unsuccessful request, status code not 2xx)")
                return
            }
            
            /* GUARD: Did we get Data? */
            guard let data = data else {
                displayError("No data returned")
                return
            }
            
            // parse the data
            let parsedResult: AnyObject!
            do {
                parsedResult = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
            } catch {
                displayError("Could not parse data as JSON: \(data)")
                return
            }
            
            
            /* GUARD: did Flickr return ok? */
            guard let statResponse = parsedResult[Constants.FlickrResponseKeys.Status] as? String where statResponse == "ok" else {
                displayError("Flickr did not return 'ok'")
                return
            }
            
            
            /* GUARD: Is the 'page' key in our response? */
            guard let photosDictionary = parsedResult[Constants.FlickrResponseKeys.Photos] as? [String: AnyObject], numPages = photosDictionary[Constants.FlickrResponseKeys.Pages] as? Int else {
                displayError("Could not find keys: \(Constants.FlickrResponseKeys.Photos), \(Constants.FlickrResponseKeys.Pages)")
                return
            }
            
            // select random page
            let availableNumPages = min(numPages, 40)
            let randomPageIndex = Int(arc4random_uniform(UInt32(availableNumPages))) + 1
            print(randomPageIndex)
            
            self.displayimageFromFlickrBySearch(methodParameters, withPage: randomPageIndex)
        }
        
        task.resume()
    }
    
    private func displayimageFromFlickrBySearch(methodParameters: [String:AnyObject], withPage: Int) {
        
        // Create URL
        var updatedMethodParameters = methodParameters
        updatedMethodParameters[Constants.FlickrParameterKeys.Page] = "\(withPage)"
        let url = flickrURLFromParameters(updatedMethodParameters)
        print(url)
        
        // TODO: Make request to Flickr!
        let session = NSURLSession.sharedSession()
        let request = NSURLRequest(URL: url)
        
        let task = session.dataTaskWithRequest(request) { (data, response, error) in
            
            // if an error occurs, print it and re-enable the UI
            func displayError(error: String) {
                print(error)
                print("URL at time of error: \(url)")
                performUIUpdatesOnMain {
                    self.setUIEnabled(true)
                    self.photoTitleLabel.text = "No photo returned... try again"
                    self.photoImageView.image = nil
                }
            }
            
            
            /* GUARD: Was there an error? */
            guard (error == nil) else {
                displayError("There was an error in the request: \(error!.localizedDescription)")
                return
            }
            
            /* GUARD: Successful Request? */
            guard let statusCode = (response as? NSHTTPURLResponse)?.statusCode where statusCode >= 200 && statusCode <= 299 else {
                displayError("Unsuccessful request, status code not 2xx)")
                return
            }
            
            /* GUARD: Did we get Data? */
            guard let data = data else {
                displayError("No data returned")
                return
            }
            
            // parse the data
            let parsedResult: AnyObject!
            do {
                parsedResult = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
            } catch {
                displayError("Could not parse data as JSON: \(data)")
                return
            }
            
            
            /* GUARD: did Flickr return ok? */
            guard let statResponse = parsedResult[Constants.FlickrResponseKeys.Status] as? String where statResponse == "ok" else {
                displayError("Flickr did not return 'ok'")
                return
            }
            
            
            /* GUARD: Are the 'photo' and 'photos' keys in our repsonse ? */
            guard let photosDictionary = parsedResult[Constants.FlickrResponseKeys.Photos] as? [String:AnyObject], photoArray = photosDictionary[Constants.FlickrResponseKeys.Photo] as? [[String:AnyObject]] else {
                displayError("Could not find keys \(Constants.FlickrResponseKeys.Photos), \(Constants.FlickrResponseKeys.Photo)")
            return
            }

            // select random photo to display
            guard let numPhotos = photoArray.count as? Int where numPhotos > 0 else {
                displayError("No photos returned... please try again")
                return
            }
            
            let randomPhotoIndex = Int(arc4random_uniform(UInt32(photoArray.count)))
            print(randomPhotoIndex, photoArray.count)
            let photoDictionary = photoArray[randomPhotoIndex] as [String:AnyObject]

            /* GUARD: does our photo have url_m? */
            guard let photoUrlString = photoDictionary[Constants.FlickrResponseKeys.MediumURL] as? String else {
                displayError("Photo does not have url... please try again")
            return
            }

            // photo title
            let photoTitle = photoDictionary[Constants.FlickrResponseKeys.Title] as? String

            // if it exists, display photo and title
            let imageURL = NSURL(string: photoUrlString)
            if let imageData = NSData(contentsOfURL: imageURL!) {
                performUIUpdatesOnMain() {
                    self.photoImageView.image = UIImage(data: imageData)
                    self.photoTitleLabel.text = photoTitle ?? "Untitled"
                    self.setUIEnabled(true)
                }
            } else {
                displayError("Data does not exist at url: \(imageURL)")
            }
        }
        
        task.resume()

    }
    
    // MARK: Helper for creating Boundingbox String from text input and constants
    private func bboxString() -> String {
        let minLat = max(Double(latitudeTextField.text!)! - Constants.Flickr.SearchBBoxHalfWidth, Constants.Flickr.SearchLatRange.0)
        let maxLat = min(Double(latitudeTextField.text!)! + Constants.Flickr.SearchBBoxHalfWidth, Constants.Flickr.SearchLatRange.1)
        let minLon = max(Double(longitudeTextField.text!)! - Constants.Flickr.SearchBBoxHalfHeight, Constants.Flickr.SearchLonRange.0)
        let maxLon = min(Double(longitudeTextField.text!)! + Constants.Flickr.SearchBBoxHalfHeight, Constants.Flickr.SearchLonRange.1)
        
        return "\(minLon),\(minLat),\(maxLon),\(maxLat)"
    }
    
    // MARK: Helper for Creating a URL from Parameters
    
    private func flickrURLFromParameters(parameters: [String:AnyObject]) -> NSURL {
        
        let components = NSURLComponents()
        components.scheme = Constants.Flickr.APIScheme
        components.host = Constants.Flickr.APIHost
        components.path = Constants.Flickr.APIPath
        components.queryItems = [NSURLQueryItem]()
        
        for (key, value) in parameters {
            let queryItem = NSURLQueryItem(name: key, value: "\(value)")
            components.queryItems!.append(queryItem)
        }
        
        return components.URL!
    }
}

// MARK: - ViewController: UITextFieldDelegate

extension ViewController: UITextFieldDelegate {
    
    // MARK: UITextFieldDelegate
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    // MARK: Show/Hide Keyboard
    
    func keyboardWillShow(notification: NSNotification) {
        if !keyboardOnScreen {
            view.frame.origin.y -= keyboardHeight(notification)
        }
    }
    
    func keyboardWillHide(notification: NSNotification) {
        if keyboardOnScreen {
            view.frame.origin.y += keyboardHeight(notification)
        }
    }
    
    func keyboardDidShow(notification: NSNotification) {
        keyboardOnScreen = true
    }
    
    func keyboardDidHide(notification: NSNotification) {
        keyboardOnScreen = false
    }
    
    private func keyboardHeight(notification: NSNotification) -> CGFloat {
        let userInfo = notification.userInfo
        let keyboardSize = userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue
        return keyboardSize.CGRectValue().height
    }
    
    private func resignIfFirstResponder(textField: UITextField) {
        if textField.isFirstResponder() {
            textField.resignFirstResponder()
        }
    }
    
    @IBAction func userDidTapView(sender: AnyObject) {
        resignIfFirstResponder(phraseTextField)
        resignIfFirstResponder(latitudeTextField)
        resignIfFirstResponder(longitudeTextField)
    }
    
    // MARK: TextField Validation
    
    private func isTextFieldValid(textField: UITextField, forRange: (Double, Double)) -> Bool {
        if let value = Double(textField.text!) where !textField.text!.isEmpty {
            return isValueInRange(value, min: forRange.0, max: forRange.1)
        } else {
            return false
        }
    }
    
    private func isValueInRange(value: Double, min: Double, max: Double) -> Bool {
        return !(value < min || value > max)
    }
}

// MARK: - ViewController (Configure UI)

extension ViewController {
    
    private func setUIEnabled(enabled: Bool) {
        photoTitleLabel.enabled = enabled
        phraseTextField.enabled = enabled
        latitudeTextField.enabled = enabled
        longitudeTextField.enabled = enabled
        phraseSearchButton.enabled = enabled
        latLonSearchButton.enabled = enabled
        
        // adjust search button alphas
        if enabled {
            phraseSearchButton.alpha = 1.0
            latLonSearchButton.alpha = 1.0
        } else {
            phraseSearchButton.alpha = 0.5
            latLonSearchButton.alpha = 0.5
        }
    }
}

// MARK: - ViewController (Notifications)

extension ViewController {
    
    private func subscribeToNotification(notification: String, selector: Selector) {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: selector, name: notification, object: nil)
    }
    
    private func unsubscribeFromAllNotifications() {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
}