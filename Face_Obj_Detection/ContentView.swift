//
//  ContentView.swift
//  Face_Obj_Detection
//
//  Created by Rohan Kumar on 9/2/22.
//

import SwiftUI
import Alamofire
import SwiftyJSON

let UIPink = Color.init(red: 1, green: 0.2, blue: 0.56)

let AIURL = "https://askai.aiclub.world/018cb7b9-ad1c-4c60-84a1-267fac249865" // REPLACE WITH YOUR AI LINK

let COMPRESSION_QUALITY = 0.05 // Amount of compression done on image (Higher Value = faster, less accurate)
let PYR_SCALE = 1.75 // Scale factor used in imagePyramid() function (Higher Value = faster, less accurate)
let WIN_STEP = 36 // Size of step that the Sliding Window is taking (Higher Value = faster, less accurate)
let MAX_NUM_ATTEMPTS = 3 // Maximum number of attempts to detect objects (Higher Value = slower, more accurate)
let STARTING_MIN_CONF_SCORE = 0.93 // Minimum threshold to be beat for a frame to be counted as an object (Higher Value = slower, more accurate) -- threshold is reduced upon each attempt if no objects are detected
let ROI_FRACTION = CGSize(width: 0.2, height: 0.2) // Fraction of image taken up by size of object (Ex: face takes up about 20% of pictures)


struct ContentView: View {
    @State private var predictedAgeGroup = " " // String value for prediction displayed on screen
    @State private var showSheet = false // Boolean state variable to toggle action sheet (used to pick camera source type)
    @State private var showingImagePicker = false // Boolean state variable to toggle sheet that displays camera or photo library
    @State private var sourceType: UIImagePickerController.SourceType = .camera // State variable holds user choice of which source type to use
    @State private var inputImage: UIImage? = UIImage(named: "default") // Stores user inputted image
    @State private var isLoading = false // Boolean state variable to toggle loading circle on screen
    @State private var numAttemptsToDetectObj = 0 // Global variable representing number of attempts made to detect objects (stops algorithm once value reaches a programmer-defined threshold)
    
    var body: some View {
        VStack {
            // Header
            Header()
                    
            AgeInfoTexts(predictedAgeGroup: self.$predictedAgeGroup, isLoading: self.$isLoading)
            
            // Image view
            if let img = self.inputImage {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: UIScreen.main.bounds.height * 0.5)
                    .cornerRadius(25)
            }
            
            Spacer()
            
            // How Old Am I? button
            SubmitButton(showSheet: self.$showSheet)
                .padding(.bottom)
            
        } // Action sheet allowing user to select between using camera roll or taking a realtime photo
        .actionSheet(isPresented: self.$showSheet) {
            ActionSheet(title: Text("Select Photo Source Type"), buttons: [
                .default(Text("Photo Library")) {
                    self.showingImagePicker = true
                    self.sourceType = .photoLibrary // Sets source type to camera roll
                },
                .default(Text("Take Photo")) {
                    self.showingImagePicker = true
                    self.sourceType = .camera // Sets source type to live camera
                },
                .cancel() {
                    self.showSheet = false
                }
            ] )
        }
        .fullScreenCover(isPresented: $showingImagePicker, onDismiss: processImage) { // Displays Image Picker with correct Source Type
            ImagePicker(image: self.$inputImage, isShown: self.$showingImagePicker, sourceType: self.sourceType)
        }
    }

    /// Displays Age Predictor text on top of screen along with pink background
    struct Header: View {
        var body: some View {
            ZStack(alignment: .bottom) {
                UIPink.opacity(0.8).ignoresSafeArea()
                Text("Age Predictor")
                    .font(.system(size: 35, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .padding()
            }
            .frame(height: UIScreen.main.bounds.height * 0.12)
        }
    }
    /// Displays all info about inputImage's calculated age + loading feedback bar
    struct AgeInfoTexts: View {
        @Binding var predictedAgeGroup: String
        @Binding var isLoading: Bool
        
        var body: some View {
            VStack {
                // Text to display age
                Text("Your Calculated Age:")
                    .font(.system(size: 30, weight: .medium))
                    .padding(.vertical, 30)
                
                // Text that displays Predicted Age Group
                Text(predictedAgeGroup)
                    .font(.system(size: 40, weight: .semibold))
                
                // Gives user feedback when object detection algorithm is loading
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: UIPink))
                    .scaleEffect(1.5)
                    .opacity(isLoading ? 1 : 0)
            }
            .foregroundColor(.gray)
        }
    }
    /// Displays submit "How Old Am I?" button
    struct SubmitButton: View {
        @Binding var showSheet: Bool
        
        var body: some View {

            Button {
                self.showSheet = true // Turns on ImagePicker sheet
            } label: {
                Text("How Old Am I ?")
                    .foregroundColor(.white)
                    .font(.title)
                    .padding()
                    .background(UIPink)
                    .cornerRadius(15)
                    .shadow(color: UIPink.opacity(0.7), radius: 20, x: 0, y: 0)
            }
            .padding(.bottom)
        }
    }
    
    /// Is called after Submit Button is pressed and Image is selected.
    ///1. Turns off Image Picker.
    ///2. Processes API Call on entire image and outputs prediction.
    ///3. Applies Image Processing procedures on image.
    func processImage() {
        self.showingImagePicker = false // Removes Camera Roll Image picker from UI
        guard let inputImage = inputImage else {return} // Unwraps inputImage

        // Processes API Call on whole image
        processAPICall(image: inputImage, {(prediction, _) in
            // Displays prediction to UI
            let convertToAgeGroup = ["Kid": "6-20", "Young Adult": "21-35", "Adult": "36-59", "Elderly": "60+"] // Helper Dictionary to convert AI prediction to Age Group
            self.predictedAgeGroup = convertToAgeGroup[prediction] ?? " "
        })

        self.isLoading = true // Turns on loading view
        // Calls Object Detection Function
        self.numAttemptsToDetectObj = 0
        
        // Averages two calculated width and height ROI values to make ROI square-shaped (accurate for facial detection)
        let averageSize = (inputImage.size.width * ROI_FRACTION.width + inputImage.size.height * ROI_FRACTION.height) / 2
        let roiSize = CGSize(width: averageSize, height: averageSize)
        // Calls object detection function
        detectObjsInImage(image: inputImage, ROI_SIZE: roiSize)
    }
    
    /// Processes API Call by sending image to global AI API link
    /// - parameter image: Image to be sent to AI API link.
    /// - parameter completion: completion handler to be executed using AI output once API call finishes.
    ///1. Is called on entire image to determine age range
    ///2. Is called on all subimages created by slidingWindow() function
    func processAPICall(image: UIImage, _
                        completion: @escaping (_ prediction:String, _ confidenceScore:Double) -> Void) {
        let apiCall = DispatchGroup()

        var prediction = ""
        var confidenceScore = 0.0
        // Pre processing before image is sent to AI
        let imageCompressed = image.jpegData(compressionQuality: COMPRESSION_QUALITY)!
        let imageB64 = Data(imageCompressed).base64EncodedData()

        // Enters Dispatch Group before starting API Call
        apiCall.enter()

        AF.upload(imageB64, to: AIURL).responseDecodable(of: JSON.self) { response in
            switch response.result {
            case .success(let resultJSON):
                prediction = resultJSON["predicted_label"].string ?? ""

                // Calculates confidence score of prediction
                let confidence = resultJSON["score"]

                let convertToIndex = ["Kid": 0, "Young Adult": 1, "Adult": 2, "Elderly": 3] // Helper Dictionary to convert Labels to Indexes

                guard let confidenceIndex = convertToIndex[prediction] else { return } // Unwraps Index
                confidenceScore = confidence[confidenceIndex].rawValue as? Double ?? 0.0 // Sets confidenceScore to highest confidence among the categories outputted by the AI
            case .failure:
                print("Failure")
            } // END SWITCH-CASE STATEMENT

            // Leaves Dispatch Group after finishing API call
            apiCall.leave()
        } // END UPLOAD
        // Will Not be executed until apiCall dispatch group is empty
        apiCall.notify(queue: .main, execute: {
            // Calls Completion Handler after API Call finishes
            completion(prediction, confidenceScore)
        })
    }

    /// Applies all steps of object detection to output an array of non-overlapping rectangles which are drawn on inputImage
    /// - parameter image: image to be processed for object detection.
    /// - parameter ROI_SIZE: size of image used for slidingWindow() function (should be around the size of the object being detected) is set to 150x150 by default
    /// - parameter MIN_CONFIDENCE_SCORE: threshold value which must be crossed to add subimage to array - is set to 0.93 by default
    ///1. Calls imagePyramid() function and saves data in an array
    ///2. Passes all images in pyramid array into slidingWindow() function
    ///3. Sends all subimages produced by each slidingWindow() call to API
    ///4. Retrieves data from API and adds subimage to arrayOut if it passes a threshold confidenceScore
    ///5. Passes arrayOut to nonMaximumSuppression() function to get rid of overlapping rectangles
    ///6. Calls drawRectangleOnImage() function
    func detectObjsInImage(image: UIImage, ROI_SIZE: CGSize, MIN_CONFIDENCE_SCORE: Double = STARTING_MIN_CONF_SCORE) {
        let INPUT_SIZE = (image.size.width, image.size.height) // Dimensions of Original Image
        
        var arrayOut:[((Int, Int, Int, Int), Double)] = [] // Array containing [ ( (X+Y Coordinates for rectangle), Confidence_Score ) ]
        let pyramid = image.imagePyramid(scale: PYR_SCALE, minSize: ROI_SIZE)

        let origImage = image
        var imageCopy = image

        let apiCall = DispatchGroup() // Creates DispatchGroup for apiCall

        for img in pyramid {
            // Finds scale factor between current image in pyramid and original
            // Scale factor is used to calculate x and y values of ROI
            let scale = INPUT_SIZE.0 / img.size.width

            // Loops through sliding window for every image in image pyramid
            for (i, j, roiOrig) in img.slidingWindow(step: WIN_STEP, windowSize: (Int(ROI_SIZE.width), Int(ROI_SIZE.height))) {
                // Applies Scale factor to calculate ROI's x and y values adjusted for the original image
                let I = Int(Double(i) * scale)
                let J = Int(Double(j) * scale)
                let w = Int(Double(ROI_SIZE.width) * scale)
                let h = Int(Double(ROI_SIZE.height) * scale)


                apiCall.enter() // Task Enters Dispatch Group before API Call Begins
                // Sends processed image to AI
                processAPICall(image: roiOrig, {(_, confidenceScore) in

                    inputImage = imageCopy.drawRectanglesOnImage([(I, J, I+w, J+h)], color: .systemRed)

                    // Appends Data to arrayOut if ROI has more than minimum confidence score
                    if confidenceScore >= MIN_CONFIDENCE_SCORE {
                        imageCopy = imageCopy.drawRectanglesOnImage([(I, J, I+w, J+h)], color: .systemOrange)
                        arrayOut.append( ((I, J, I+w, J+h), confidenceScore) )
                    }

                    apiCall.leave() // Task Leaves Dispatch Group after API call is completed

                }) // END API CALL

            } // END INNER FOR LOOP
        } // END OUTER FOR LOOP

        // Executes after all API calls are completed
        apiCall.notify(queue: .main, execute: {
            if arrayOut.count > 0 {
                inputImage = origImage
                // If at least 1 object is detected, calls drawRectangleOnImage() function
                inputImage = inputImage!.drawRectanglesOnImage(nonMaximumSuppression(arrayOut), color: .systemGreen)
                self.isLoading = false
                self.numAttemptsToDetectObj = 0 // Resets number attempts
            } else if self.numAttemptsToDetectObj <= MAX_NUM_ATTEMPTS {
                // If no objects are detected, program retries detectObjsInImage() function with a lower MIN_CONFIDENCE_SCORE

                self.numAttemptsToDetectObj += 1
                detectObjsInImage(image: image, ROI_SIZE: ROI_SIZE, MIN_CONFIDENCE_SCORE: MIN_CONFIDENCE_SCORE-0.02)
            } else {
                self.isLoading = false // Turns off loading screen when all attempts are used up
                self.numAttemptsToDetectObj = 0 // Resets number attempts
            }
        }) // END APICALL.NOTIFY BLOCK
    }
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
