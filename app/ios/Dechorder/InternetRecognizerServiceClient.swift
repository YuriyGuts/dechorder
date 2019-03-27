import Alamofire
import SwiftyJSON

class InternetRecognizerServiceClient: RecognizerServiceClient {
    
    private let _serviceURL = "https://dechorder.yuriyguts.com/api/recognize"
    
    private var _userDocumentManager: UserDocumentManager
    
    init(withUserDocumentManager userDocumentManager: UserDocumentManager) {
        _userDocumentManager = userDocumentManager
    }
    
    func recognizeChords(forTrack track: Track) throws -> RecognizeChordsResponse {
        guard let fileName = track.filename,
            let audioFileURL = _userDocumentManager.documentURL(forFileName: fileName) else {
            return RecognizeChordsResponse.empty()
        }

        var uploadResponse: DataResponse<Any>? = nil
        Alamofire.upload(
            multipartFormData: { multipartFormData in
                multipartFormData.append(
                    audioFileURL,
                    withName: "audio-file",
                    fileName: "audio.m4a",
                    mimeType: "audio/m4a"
                )
            },
            to: _serviceURL,
            encodingCompletion: { encodingResult in
                switch encodingResult {
                case .success(let upload, _, _):
                    upload.responseJSON { response in
                        uploadResponse = response
                    }
                case .failure(let encodingError):
                    NSLog("Request encoding error: \(encodingError)")
                }
            }
        )

        // Async completions will overcomplicate the RecognizerServiceClient interface
        // which is already called in another thread, so we'll just sleep at this point.
        // I know, I know, it smells a bit.
        while uploadResponse == nil {
            Thread.sleep(forTimeInterval: 0.5)
        }
        
        switch uploadResponse!.result {
            case .failure(let error):
                throw(error)
            
            case .success:
                return decodeResponseForRecognizeChordsCall(response: uploadResponse!)
        }
    }
    
    func decodeResponseForRecognizeChordsCall(response: DataResponse<Any>) -> RecognizeChordsResponse {
        guard let data = response.data else {
            return RecognizeChordsResponse.empty()
        }
        
        let json = try! JSON(data: data)
        var recognizedChords: [RecognizedChord] = []
        
        for (_, chordJson): (String, JSON) in json {
            recognizedChords.append(RecognizedChord(
                name: chordJson["name"].string ?? "",
                timeOffset: chordJson["timeOffset"].double ?? 0.0,
                confidence: chordJson["confidence"].double ?? 1.0
            ))
        }
        
        return RecognizeChordsResponse(chords: recognizedChords)
    }
}
