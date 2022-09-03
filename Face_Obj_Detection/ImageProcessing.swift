//
//  ImageProcessing.swift
//  Face_Obj_Detection
//
//  Created by Rohan Kumar on 9/2/22.
//

import Foundation
import SwiftUI
import Alamofire
import SwiftyJSON
import UIKit

extension UIImage {
    
    /// Helper function that resizes image to a certain size, simply returns image if size = self.size
    /// - parameter size: CGSize variable that holds x and y values, which the image will be resized to
    func resizeImageTo(size: CGSize) -> UIImage {
        UIGraphicsBeginImageContext(size)
        self.draw(in: CGRect(origin: CGPoint.zero, size: size))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return resizedImage
    }
    
    /// Returns array of all resized images larger than minX and minY
    /// - parameter scale: scale factor to which image is divided by upon each iteration  (set to 1.5 by default)
    /// - parameter minSize: smallest possible size for resized image at which point algorithm exits
    func imagePyramid(scale:CGFloat = 1.5, minSize:CGSize = CGSize(width: 100, height: 100)) -> Array<UIImage> {
        var newImage:UIImage = self.resizeImageTo(size: self.size) // Creates copy of original image
        var arrayOut:Array<UIImage> = [newImage] // Adds original image to pyramid
        
        while true {
            // Computes next image size based on previous image size and scale parameter
            let targSize = CGSize(width: newImage.size.width / scale, height: newImage.size.height / scale)
            newImage = self.resizeImageTo(size: targSize) // Resizes newImage to targSize
            // Checks if resized image is greater than minX and minY parameters
            if newImage.size.width >= minSize.width && newImage.size.height >= minSize.height {
                arrayOut.append(newImage) // Appends newImage if all conditions are met
            } else { break }
        }
        return arrayOut
    }
    
    /// Returns a array of all subimages of original image based on parameters in
    /// - parameter step: step size between slidingWindow subimages
    /// - parameter windowSize: tuple containing the size of slidingWindow subimages (should be roughly the size of the target object)
    func slidingWindow(step:Int, windowSize:(Int, Int)) -> [(Int, Int, UIImage)] {
        var arrayOut:Array< (Int, Int, UIImage) > = [] // creates array of images to be outputted
        let image:UIImage = self.resizeImageTo(size: self.size) // Retrieves original image
        
        // slides through image's height by increments of step parameter
        for y in stride(from: 0, through: Int(image.size.height) - windowSize.1, by: step) {
            // slides through image's width by increments of step parameter
            for x in stride(from: 0, through: Int(image.size.width) - windowSize.0, by: step) {
                // creates rectangle at x and y with the size of windowSize
                let rec = CGRect(x: x, y: y, width: windowSize.0, height: windowSize.1)
                let subImage = UIImage(cgImage: image.cgImage!.cropping(to: rec)!)
                arrayOut.append( (x, y, subImage) ) // adds calculated subImage to output array
            }
        }
        return arrayOut
    }
    
    /// Takes in array of rectangle coordinates, draws them on top of the image inputted, and returns the edited image
    ///- parameter arrayIn: contains coordinates for all non-overlapping rectangles
    func drawRectanglesOnImage(_ arrayIn:[(Int, Int, Int, Int)], color:UIColor = .systemRed) -> UIImage{
        var editedInputImage:UIImage = self.resizeImageTo(size: self.size)
        let imageSize = editedInputImage.size
        
        for (x1,y1,x2,y2) in arrayIn {
            let scale: CGFloat = 0
            UIGraphicsBeginImageContextWithOptions(imageSize, false, scale) // Begins Drawing
            editedInputImage.draw(at: CGPoint.zero) // Sets Starting Point at (0,0)
            let rectangle = CGRect(x: x1, y: y1, width: x2-x1, height: y2-y1) // Creates Rectangle Object at the correct x and y coordinates
            color.set()
            
            // Draws Rectangle "Path" on top of UIImage
            let rect:UIBezierPath = UIBezierPath(rect: rectangle)
            rect.lineWidth = imageSize.width / 175
            rect.stroke()
            editedInputImage = UIGraphicsGetImageFromCurrentImageContext()!
            UIGraphicsEndImageContext() // Ends Drawing
        }
        return editedInputImage // Replaces inputImage with inputImage with Rectangles
    }

}


/// Helper function that resolves colliding rectangles by removing all rectangles besides the one with the maximum confidence score
/// - parameter infoArray: array containing rectangle coordinates and their corresponding confidence scores
func nonMaximumSuppression(_ infoArray:[((Int, Int, Int, Int), Double)]) -> [(Int, Int, Int, Int)]{
    var arrayNoOverlaps:[ ((Int, Int, Int, Int), Double) ] = []
    // Each index of arrayNoOverlaps contains a rectangle + confidenceScore tuple
    
    // Iterates through all entries in infoArray
    for ((x1,y1,x2,y2), confidenceScore) in infoArray {
        var overlapsOtherRectangle = false
        
        // Appends current info to array if overlapsOtherRectangle remains false
        // Compares to overlapping rectangle if overlapsOtherRectangle is true
        // Replaces current overlapping rectangle if confidence score is greater
        // Else, leaves arrayOut as is
        
        // Iterates through all current entries in arrayNoOverlaps if arrayNoOverlaps is not empty
        if !(arrayNoOverlaps.isEmpty) {
            for i in 0...arrayNoOverlaps.count-1 {
                if isOverlapping(rect1: (x1,y1,x2,y2), rect2: arrayNoOverlaps[i].0) {
                    // Replaces current rectangle if confidence score is higher
                    if confidenceScore > arrayNoOverlaps[i].1 {
                        arrayNoOverlaps[i] = ((x1,y1,x2,y2), confidenceScore)
                    }
                    overlapsOtherRectangle = true
                } // END IF STATEMENT
            } // END INNER FOR LOOP
        } // END IF STATEMENT
        
        // Appends current info if it does not overlap with any other rectangle
        if !overlapsOtherRectangle {
            arrayNoOverlaps.append(((x1,y1,x2,y2), confidenceScore))
        }
    }
    
    // Returns array of non-overlapping rectangle coordinates
    var arrayOut:[(Int, Int, Int, Int)] = []
    for (coordinates, _) in arrayNoOverlaps {
        arrayOut.append(coordinates)
    }
    return arrayOut
}

/// Helper function to check if two rectangles overlap
func isOverlapping(rect1: (Int,Int,Int,Int), rect2: (Int,Int,Int,Int)) -> Bool {
    let THRESH = (rect1.2 - rect1.0) / 20 // Threshold added to detect overlaps (is equal to rectangle width / 20)
    
    // Returns False if Rectangles are not overlapping
    if !( (rect1.2+THRESH < rect2.0) || (rect2.2+THRESH < rect1.0) || (rect1.3+THRESH < rect2.1) || (rect2.3+THRESH < rect1.1) ) {
        return true
    }
    return false // Returns false if no collisions are detected
}
