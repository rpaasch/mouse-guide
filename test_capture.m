#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <AppKit/AppKit.h>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSLog(@"Testing screen capture on macOS 15...");

        // Get mouse location
        NSPoint mouseLocation = [NSEvent mouseLocation];
        NSLog(@"Mouse location: %f, %f", mouseLocation.x, mouseLocation.y);

        // Try to capture screen
        CGRect captureRect = CGRectMake(mouseLocation.x - 1, mouseLocation.y - 1, 3, 3);

        NSLog(@"Attempting CGWindowListCreateImage...");
        CGImageRef screenImage = CGWindowListCreateImage(
            captureRect,
            kCGWindowListOptionOnScreenOnly,
            kCGNullWindowID,
            kCGWindowImageDefault
        );

        if (screenImage == NULL) {
            NSLog(@"❌ FAILED: CGWindowListCreateImage returned NULL");
            NSLog(@"This means the API doesn't work on macOS 15");
            return 1;
        }

        NSLog(@"✅ SUCCESS: Got screen image!");
        NSLog(@"Image size: %zu x %zu", CGImageGetWidth(screenImage), CGImageGetHeight(screenImage));

        CFRelease(screenImage);
    }
    return 0;
}
