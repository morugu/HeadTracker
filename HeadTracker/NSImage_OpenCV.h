// code from https://gist.github.com/dominiklessel/1716068
#ifndef NSImage_OpenCV_h
#define NSImage_OpenCV_h

#import <AppKit/AppKit.h>
#import <opencv2/opencv.hpp>
#import <opencv2/highgui/highgui.hpp>

@interface NSImage (NSImage_OpenCV) {
}

+(NSImage*)imageWithCVMat:(const cv::Mat&)cvMat;
-(id)initWithCVMat:(const cv::Mat&)cvMat;

@property(nonatomic, readonly) cv::Mat CVMat;
@property(nonatomic, readonly) cv::Mat CVGrayscaleMat;

@end

#endif /* NSImage_OpenCV_h */
