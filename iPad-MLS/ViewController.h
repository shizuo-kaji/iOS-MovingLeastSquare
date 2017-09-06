//
//  ViewController.h
//
//  Copyright (c) 2013 S. Kaji
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>
#import <OpenGLES/ES2/glext.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreVideo/CVOpenGLESTextureCache.h>
#import "ImageMesh.h"

@interface ViewController : GLKViewController
<<<<<<< HEAD
<UINavigationControllerDelegate, UIImagePickerControllerDelegate, UIGestureRecognizerDelegate,
        AVCaptureVideoDataOutputSampleBufferDelegate>{
            
            // mesh data
            ImageMesh *mainImage;
            CFMutableDictionaryRef ipts;
            
            // is the camera on?
            BOOL cameraMode;
            
            // screen size
            float ratio_height, ratio_width;
            CGSize screen;
            
            //UI
            IBOutlet UISwitch *sw;
            int mode;
            
            // for capturing
            AVCaptureDevice *captureDevice;
            AVCaptureDeviceInput *deviceInput;
            AVCaptureSession *session;
            AVCaptureVideoDataOutput *videoOutput;
            CVOpenGLESTextureCacheRef textureCache;
            CVOpenGLESTextureRef textureObject;
            GLuint cameraTextureName;
            
=======
<UINavigationControllerDelegate, UIImagePickerControllerDelegate, UIGestureRecognizerDelegate>{
    // mesh data
    ImageMesh *mainImage;
    CFMutableDictionaryRef ipts;
    
    // screen size
    float ratio_height;
    float ratio_width;
    CGSize screen;
    
    // image selector
    UIPopoverController *imagePopController;
    
    //UI
    IBOutlet UISwitch *sw;
    int mode;
>>>>>>> 0e57c80a9c08089ee89aaa5ff8f72b1737d184cb
}
@property (strong, nonatomic) EAGLContext *context;
@property (strong, nonatomic) GLKBaseEffect *effect;
@property (weak, nonatomic) IBOutlet UISwitch *cameraSw;

- (void)setupGL;
- (void)tearDownGL;

- (IBAction)pushButton_ReadImage:(UIBarButtonItem *)sender;
- (IBAction)pushButton_Initialize:(UIBarButtonItem *)sender;
- (IBAction)pushButton_HowToUse:(UIBarButtonItem *)sender;
- (IBAction)pushSeg:(UISegmentedControl *)sender;
<<<<<<< HEAD
- (IBAction)pushCamera:(UISwitch *)sender;
- (IBAction)pushSaveImg:(UIBarButtonItem *)sender;
=======
>>>>>>> 0e57c80a9c08089ee89aaa5ff8f72b1737d184cb

@end
