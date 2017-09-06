//
//  ViewController.m
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

#import "ViewController.h"
#import <Accelerate/Accelerate.h>

#include <vector>

using namespace Eigen;


#define EPSILON 10e-6
#define MAX_TOUCHES 5
#define HDIV 30
#define VDIV 30
#define DEFAULTIMAGE @"Default.png"
#define MODE_SIM 0
#define MODE_RIGID 1

@implementation ViewController
@synthesize effect;


- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    if (!self.context) {
        NSLog(@"Failed to create ES context");
    }
    
    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
    [EAGLContext setCurrentContext:self.context];

    cameraMode = false;

    // enable multi-touch tracking
    self.view.multipleTouchEnabled = YES;
    // prepare dictionary for touch tracking
    ipts = CFDictionaryCreateMutable(NULL, MAX_TOUCHES, &kCFTypeDictionaryKeyCallBacks, NULL);
    // load default image
    mainImage = [[ImageMesh alloc] initWithVDiv:VDIV HDiv:HDIV];
    [mainImage loadImage:[ UIImage imageNamed:DEFAULTIMAGE ]];
    
    mode = MODE_SIM;
    
    [self setupGL];
}

- (void)dealloc
{    
    [self tearDownGL];
    
    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];

    if ([self isViewLoaded] && ([[self view] window] == nil)) {
        self.view = nil;
        
        [self tearDownGL];
        
        if ([EAGLContext currentContext] == self.context) {
            [EAGLContext setCurrentContext:nil];
        }
        self.context = nil;
    }

    // Dispose of any resources that can be recreated.
}

- (void)setupGL
{
    [EAGLContext setCurrentContext:self.context];
    self.effect = [[GLKBaseEffect alloc] init];
    [self setupScreen];
}

- (void)setupScreen{
    float gl_height, gl_width, ratio;
//    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    screen.height = [UIScreen mainScreen].bounds.size.height;
    screen.width = [UIScreen mainScreen].bounds.size.width;
    ratio = screen.height/screen.width;
    ratio = screen.height/screen.width;
    if (screen.width*mainImage.image_height<screen.height*mainImage.image_width) {
        gl_width = mainImage.image_width;
        gl_height = gl_width*ratio;
    }else{
        gl_height = mainImage.image_height;
        gl_width = gl_height/ratio;
    }
    ratio_height = gl_height / screen.height;
    ratio_width = gl_width / screen.width;
    
    GLKMatrix4 projectionMatrix = GLKMatrix4MakeOrtho(-gl_width/2.0, gl_width/2.0, -gl_height/2.0, gl_height/2.0, -1, 1);
    self.effect.transform.projectionMatrix = projectionMatrix;
}

- (void)tearDownGL
{
    GLuint name = mainImage.texture.name;
    glDeleteTextures(1, &name);
    glDeleteTextures(1, &cameraTextureName);
    [EAGLContext setCurrentContext:self.context];
    self.effect = nil;    
}

#pragma mark - GLKView and GLKViewController delegate methods

- (void)update
{
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    glClearColor(0, 104.0/255.0, 55.0/255.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glEnable(GL_BLEND);
    
    [self.effect prepareToDraw];

    [self renderImage];
}

- (void)renderImage{
    if(cameraMode){
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, cameraTextureName);
        glTexParameteri( GL_TEXTURE_2D, GL_GENERATE_MIPMAP_HINT, GL_TRUE );
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    }else{
        self.effect.texture2d0.name = mainImage.texture.name;
        self.effect.texture2d0.enabled = YES;
        [self.effect prepareToDraw];
    }
    
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
    
    glVertexAttribPointer(GLKVertexAttribPosition, 2, GL_FLOAT, GL_FALSE, sizeof(float) * 2, mainImage.verticesArr);
    glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, sizeof(float) * 2, mainImage.textureCoordsArr);
    
    for (int i=0; i<mainImage.verticalDivisions; i++) {
        glDrawArrays(GL_TRIANGLE_STRIP, i*(mainImage.horizontalDivisions*2+2), mainImage.horizontalDivisions*2+2);
    }
}

/**
 *  Touch event tracking
 */
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if ([touches count] > 0){
        NSSet *allTouches = [event allTouches];
        [self freeze_pts:allTouches];
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    for (UITouch *touch in touches) {
        int *p = (int *)CFDictionaryGetValue(ipts, (__bridge void*)touch);
        if(p != NULL){
            CFDictionaryRemoveValue(ipts, (__bridge void*)touch);
            free(p);
        }
    }
    NSMutableSet *allTouches = [NSMutableSet setWithSet:[event allTouches]];
    [allTouches minusSet:touches];
    [self freeze_pts:allTouches];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event{
    NSLog(@"allTouches count : %lu (touchesCancelled:withEvent:)", (unsigned long)[[event allTouches] count]);
    for (UITouch *touch in touches) {
        int *p = (int *)CFDictionaryGetValue(ipts, (__bridge void*)touch);
        if(p != NULL){
            CFDictionaryRemoveValue(ipts, (__bridge void*)touch);
            free(p);
        }
    }
    NSMutableSet *allTouches = [NSMutableSet setWithSet:[event allTouches]];
    [allTouches minusSet:touches];
    [self freeze_pts:allTouches];
}


- (void) freeze_pts:(NSSet *)allTouches{
    for(int i=0;i<[allTouches count];i++){
        UITouch *touch = [[allTouches allObjects] objectAtIndex:i];
        // touched location
        CGPoint pt = [touch locationInView:self.view];
        Vector2f poi;
        poi << (pt.x - screen.width/2.0)*ratio_width, (screen.height/2.0 - pt.y)*ratio_height;
        Vector2f *p = (Vector2f *)CFDictionaryGetValue(ipts, (__bridge void*)touch);
        if (p == NULL) {
            p = (Vector2f *)malloc(sizeof(*p));
            CFDictionarySetValue(ipts, (__bridge void*)touch, p);
        }
        *p = poi;
    }
    for(int j=0;j<mainImage.numVertices;j++){
        mainImage.ixy[j] = mainImage.xy[j];
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    NSSet *allTouches = [event allTouches];
    NSUInteger count = [allTouches count];
    std::vector<Vector2f> p(count),q(count);
    for(int i=0;i<count;i++){
        UITouch *touch = [[allTouches allObjects] objectAtIndex:i];
        CGPoint pt = [touch locationInView:self.view];
        // current location
        q[i] << (pt.x - screen.width/2.0)*ratio_width, (screen.height/2.0 - pt.y)*ratio_height;
        // original location
        p[i] = *(Vector2f *)CFDictionaryGetValue(ipts, (__bridge void*)touch);
    }
    std::vector<float> w(count);
    if(count==0){
        return;
    }else if(count==1){
        // just translate
        for(int i=0;i<mainImage.numVertices;i++){
            mainImage.xy[i] = mainImage.ixy[i] + q[0]-p[0];
        }
    }else{
        //weight
        for(int i=0;i<mainImage.numVertices;i++){
            bool touched = false;
            for(int j=0;j<count;j++){
                if( (mainImage.ixy[i]-p[j]).squaredNorm()<EPSILON){
                    touched = true;
                    mainImage.xy[i] = p[j];
                }
                w[j] = 1/(mainImage.ixy[i]-p[j]).squaredNorm();
            }
            if(touched){
                continue;
            }
            // barycentre of the original (p) and the current (q) touched points
            Vector2f pcenter = Vector2f::Zero();
            Vector2f qcenter = Vector2f::Zero();
            float wsum = 0;
            for(int j=0;j<count;j++){
                wsum += w[j];
                pcenter += w[j] * p[j];
                qcenter += w[j] * q[j];
            }
            pcenter /= wsum;
            qcenter /= wsum;
            // relative coordinates
            std::vector<Vector2f> ph(count), qh(count);
            for(int j=0;j<count;j++){
                ph[j] = p[j]-pcenter;
                qh[j] = q[j]-qcenter;
            }
            // determine matrix
            Matrix2f M,P,Q;
            M = Matrix2f::Zero();
            float mu = 0;
            for(int j=0;j<count;j++){
                P << ph[j][0], ph[j][1], ph[j][1], -ph[j][0];
                Q << qh[j][0], qh[j][1], qh[j][1], -qh[j][0];
                M += w[j]*Q*P;
                mu += w[j] * ph[j].squaredNorm();
            }
            if(mode==MODE_SIM){
                mainImage.xy[i] = M * (mainImage.ixy[i]-pcenter) / mu + qcenter;
            }else if(mode==MODE_RIGID){
                mainImage.xy[i] = M * (mainImage.ixy[i]-pcenter) / mu;
                mainImage.xy[i] = (mainImage.ixy[i]-pcenter).norm() * mainImage.xy[i].normalized() + qcenter;
            }
        }
    }
    // update
    [mainImage deform];
}


/**
 *  Buttons
 */

// Initialise
- (IBAction)pushButton_Initialize:(UIBarButtonItem *)sender {
    NSLog(@"Initialize");
    [mainImage initialize];
}

// snapshot
- (IBAction)pushSaveImg:(UIBarButtonItem *)sender{
    NSLog(@"saving image");
    UIImage* image = [(GLKView*)self.view snapshot];
    UIImageWriteToSavedPhotosAlbum(image, self, @selector(savingImageIsFinished:didFinishSavingWithError:contextInfo:), nil);
}
- (void) savingImageIsFinished:(UIImage *)_image didFinishSavingWithError:(NSError *)_error contextInfo:(void *)_contextInfo{
    NSMutableString *title = [NSMutableString string];
    NSMutableString *msg = [NSMutableString string];
    if(_error){
        [title setString:@"error"];
        [msg setString:@"Save failed."];
    }else{
        [title setString:@"Saved"];
        [msg setString:@"Image saved in Camera Roll"];
    }
    UIAlertController * ac = [UIAlertController alertControllerWithTitle:title
                                        message:msg
                                 preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction * okAction =
    [UIAlertAction actionWithTitle:@"OK"
                             style:UIAlertActionStyleDefault
                           handler:^(UIAlertAction * action) {
                               NSLog(@"OK button tapped.");
                           }];
    [ac addAction:okAction];
    [self presentViewController:ac animated:YES completion:nil];
}

// mode change
-(IBAction)pushSeg:(UISegmentedControl *)sender{
    mode = (int)sender.selectedSegmentIndex;
}

// Load new image
- (IBAction)pushButton_ReadImage:(UIBarButtonItem *)sender {
    if([UIImagePickerController
        isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]){
        UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
        imagePicker.delegate = self;
        imagePicker.allowsEditing = YES;
        imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        [self presentViewController:imagePicker animated:YES completion:nil];
    }else{
        NSLog(@"Photo library not available");
    }
}
#pragma mark -
#pragma mark UIImagePickerControllerDelegate implementation
// select image
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info{
    [self stopCamera];
    GLuint name = mainImage.texture.name;
    glDeleteTextures(1, &name);
    UIImage *pImage = [info objectForKey: UIImagePickerControllerOriginalImage];
    [mainImage loadImage:pImage];
    [self setupScreen];
    [self dismissViewControllerAnimated:YES completion:nil];
}
//cancel
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker{
    [self dismissViewControllerAnimated:YES completion:nil];
}

// show help screen
- (IBAction)pushButton_HowToUse:(UIBarButtonItem *)sender {
//    creditController = [[CreditController alloc] initWithNibName:@"CreditController" bundle:nil];
//    [self.view addSubview:creditController.view];
}


// Device orientation change
- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration{
    if(cameraMode){
        [self cameraOrientation];
    }
    [self setupScreen];
}

// Camera
-(IBAction)pushCamera:(UISwitch *)sender{
    //    [mainImage removeProbes];
    if([sender isOn]){
        @try {
            [self initializeCamera];
            [self cameraOrientation];
            NSLog(@"Camera ON");
        }
        @catch (NSException *exception) {
            NSLog(@"camera init error : %@", exception);
        }
    }else{
        [self stopCamera];
        [mainImage loadImage:[ UIImage imageNamed:DEFAULTIMAGE ]];
        NSLog(@"Camera OFF");
    }
    [self setupScreen];
    [mainImage initialize];
}


- (void)initializeCamera{
    cameraMode = true;
    captureDevice = nil;
    for(AVCaptureDevice *device in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]){
        if(device.position == AVCaptureDevicePositionBack){
            captureDevice = device;
        }
    }
    if(captureDevice == nil){
        [NSException raise:@"" format:@"AVCaptureDevicePositionBack not found"];
    }
    
    NSError *error;
    deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:&error];
    
    session = [[AVCaptureSession alloc] init];
    [session beginConfiguration];
    session.sessionPreset = AVCaptureSessionPreset1280x720;
    [session addInput:deviceInput];
    
    videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    videoOutput.videoSettings = @{(id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA) };
    [videoOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    [session addOutput:videoOutput];
    
    [session commitConfiguration];
    [session startRunning];
    for(AVCaptureConnection *connection in videoOutput.connections){
        if(connection.supportsVideoOrientation){
            connection.videoOrientation = AVCaptureVideoOrientationPortrait;
        }
    }
    
    CVReturn cvError = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, self.context, NULL, &textureCache);
    if(cvError){
        [NSException raise:@"" format:@"CVOpenGLESTextureCacheCreate failed"];
    }
}

-(void) stopCamera{
    cameraMode = false;
    _cameraSw.on = false;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if ([session isRunning]){
            [session stopRunning];
            [session removeInput:deviceInput];
            [session removeOutput:videoOutput];
            session = nil;
            videoOutput = nil;
            deviceInput = nil;
            
        }
    });
}

// the following is called 30 times per sec
- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    int bufferWidth = (int)CVPixelBufferGetWidth(imageBuffer);
    int bufferHeight = (int)CVPixelBufferGetHeight(imageBuffer);
    
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    CVOpenGLESTextureRef esTexture;
    CVReturn cvError = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                                    textureCache,
                                                                    imageBuffer,
                                                                    NULL,
                                                                    GL_TEXTURE_2D,
                                                                    GL_RGBA,
                                                                    bufferWidth, bufferHeight,
                                                                    GL_BGRA,
                                                                    GL_UNSIGNED_BYTE,
                                                                    0,
                                                                    &esTexture);
    
    if(cvError){
        NSLog(@"CVOpenGLESTextureCacheCreateTextureFromImage failed");
    }
    cameraTextureName = CVOpenGLESTextureGetName(esTexture);
    CVOpenGLESTextureCacheFlush(textureCache, 0);
    if(textureObject)
        CFRelease(textureObject);
    
    textureObject = esTexture;
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
}

-(void)cameraOrientation{
    AVCaptureVideoOrientation orientation;
    switch ([UIDevice currentDevice].orientation) {
        case UIDeviceOrientationUnknown:
            orientation = AVCaptureVideoOrientationPortrait;
            mainImage.image_width =720;
            mainImage.image_height =1280;
            break;
        case UIDeviceOrientationPortrait:
            orientation = AVCaptureVideoOrientationPortrait;
            mainImage.image_width =720;
            mainImage.image_height =1280;
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            orientation = AVCaptureVideoOrientationPortraitUpsideDown;
            mainImage.image_width =720;
            mainImage.image_height =1280;
            break;
        case UIDeviceOrientationLandscapeLeft:
            orientation = AVCaptureVideoOrientationLandscapeRight;
            mainImage.image_width =1280;
            mainImage.image_height =720;
            break;
        case UIDeviceOrientationLandscapeRight:
            orientation = AVCaptureVideoOrientationLandscapeLeft;
            mainImage.image_width =1280;
            mainImage.image_height =720;
            break;
        case UIDeviceOrientationFaceUp:
        case UIDeviceOrientationFaceDown:
            orientation = AVCaptureVideoOrientationPortrait;
            mainImage.image_width =720;
            mainImage.image_height =1280;
            break;
    }
    for(AVCaptureConnection *connection in videoOutput.connections){
        if(connection.supportsVideoOrientation){
            connection.videoOrientation = orientation;
        }
    }
    [self setupScreen];
    [mainImage initialize];
    [mainImage deform];
}


/**
 *  termination procedure
 */
- (void)viewDidUnload {
    [super viewDidUnload];
    if (ipts)
        CFRelease(ipts);
    [self tearDownGL];
    self.context = nil;
}

@end
