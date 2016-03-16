#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "HeadTracker-Bridging-Header.h"
#import "NSImage_OpenCV.h"
#import <opencv2/opencv.hpp>
#import <opencv2/highgui/highgui.hpp>

@interface Recognizer() {
    cv::CascadeClassifier cascadeProfile;
    cv::CascadeClassifier cascadeFrontal;
}
@end

@implementation Recognizer : NSObject

- (id)init {
    self = [super init];
    
    NSBundle* bundle = [NSBundle mainBundle];
    
    NSString* pathProfile = [bundle pathForResource:@"haarcascade_profileface" ofType:@"xml"];
    std::string cascadeProfilePath = (char*)[pathProfile UTF8String];
    if (cascadeProfile.load(cascadeProfilePath) == false) {
        return nil;
    }
    
    NSString* pathFrontal = [bundle pathForResource:@"haarcascade_frontalface_alt" ofType:@"xml"];
    std::string cascadeFrontalPath = (char*)[pathFrontal UTF8String];
    if (cascadeFrontal.load(cascadeFrontalPath) == false) {
        return nil;
    }
    
    return self;
}

- (unsigned int)recognize:(NSImage *)image {
    cv::Mat cvImage = [image CVMat];
    
    std::vector<cv::Rect> faces;
    int found = 0;
    
    // frontal
    cascadeFrontal.detectMultiScale(cvImage, faces, 1.1, 3, CV_HAAR_DO_ROUGH_SEARCH | CV_HAAR_FIND_BIGGEST_OBJECT, cv::Size(28, 28));
    if (faces.size() > 0) {
        found |= 0x01 << 0;
    }
    
    // profile
    cascadeProfile.detectMultiScale(cvImage, faces, 1.1, 3, CV_HAAR_DO_ROUGH_SEARCH | CV_HAAR_FIND_BIGGEST_OBJECT, cv::Size(33, 33));
    if (faces.size() > 0) {
        found |= 0x01 << 1;
    }
    
    return found;
}

@end