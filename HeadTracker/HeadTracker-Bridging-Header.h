#import <Cocoa/Cocoa.h>

@interface Recognizer : NSObject

- (id) init;
- (unsigned int) recognize:(NSImage*) image;

@end