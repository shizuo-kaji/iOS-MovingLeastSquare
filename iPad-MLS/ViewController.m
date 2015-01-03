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
#define HDIV 20
#define VDIV 20
#define NUMV 2*(HDIV+1)*(VDIV+1)
#define DEFAULTIMAGE @"Default.png"

@interface ViewController ()
@property (strong, nonatomic) EAGLContext *context;
@property (strong, nonatomic) GLKBaseEffect *effect;
- (void)setupGL;
- (void)tearDownGL;
@end

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
    
    // enable multi-touch tracking
    self.view.multipleTouchEnabled = YES;
    // prepare dictionary for touch tracking
    ipts = CFDictionaryCreateMutable(NULL, MAX_TOUCHES, &kCFTypeDictionaryKeyCallBacks, NULL);
    // load default image
    UIImage *pImage = [ UIImage imageNamed:DEFAULTIMAGE ];
    mainImage = [[ImageMesh alloc] initWithUIImage:pImage VerticalDivisions:VDIV HorizontalDivisions:HDIV];
    [self loadTexture:pImage];
    
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

- (void)loadTexture:(UIImage *)pImage{
    NSError *error;
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES],
                             GLKTextureLoaderOriginBottomLeft,
                             nil];
    UIImage *image = [UIImage imageWithData:UIImagePNGRepresentation(pImage)];
    mainImage.texture = [GLKTextureLoader textureWithCGImage:image.CGImage options:options error:&error];
    if (error)
        NSLog(@"Error loading texture from image: %@",error);
}

- (void)setupGL
{
    [EAGLContext setCurrentContext:self.context];
    self.effect = [[GLKBaseEffect alloc] init];
    [self setupScreen];
}

- (void)setupScreen{
    float gl_height, gl_width, ratio;
    if (self.interfaceOrientation<3) {
        screen.height = [UIScreen mainScreen].bounds.size.height;
        screen.width = [UIScreen mainScreen].bounds.size.width;
    }else{
        screen.height = [UIScreen mainScreen].bounds.size.width;
        screen.width = [UIScreen mainScreen].bounds.size.height;
    }
    if (screen.width*mainImage.image_height<screen.height*mainImage.image_width) {
        ratio = mainImage.image_width/screen.width;
        gl_width = mainImage.image_width;
        gl_height = screen.height*ratio;
    }else{
        ratio = mainImage.image_height/screen.height;
        gl_height = mainImage.image_height;
        gl_width = screen.width*ratio;
    }
    ratio_height = gl_height / screen.height;
    ratio_width = gl_width / screen.width;
    // compute touch radius for each vertex
    float r = mainImage.image_width/(float)(2*mainImage.horizontalDivisions);
    mainImage.radius = r*r;
    
    GLKMatrix4 projectionMatrix = GLKMatrix4MakeOrtho(-gl_width/2.0, gl_width/2.0, -gl_height/2.0, gl_height/2.0, -1024, 1024);
    self.effect.transform.projectionMatrix = projectionMatrix;
}

- (void)tearDownGL
{
    GLuint name = mainImage.texture.name;
    glDeleteTextures(1, &name);
    [EAGLContext setCurrentContext:self.context];
    self.effect = nil;    
}

#pragma mark - GLKView and GLKViewController delegate methods

- (void)update
{
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    [self renderImage];
}

- (void)renderImage{
    self.effect.texture2d0.name = mainImage.texture.name;
    self.effect.texture2d0.enabled = YES;
    
    glClearColor(0, 104.0/255.0, 55.0/255.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glEnable(GL_BLEND);
    
    [self.effect prepareToDraw];
    
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
    int count = [allTouches count];
    std::vector<Vector2f> p(count),q(count);
    for(int i=0;i<count;i++){
        UITouch *touch = [[allTouches allObjects] objectAtIndex:i];
        CGPoint pt = [touch locationInView:self.view];
        q[i] << (pt.x - screen.width/2.0)*ratio_width, (screen.height/2.0 - pt.y)*ratio_height;
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
            // barycentre
            Vector2f center = Vector2f::Zero();
            Vector2f icenter = Vector2f::Zero();
            float wsum = 0;
            for(int j=0;j<count;j++){
                wsum += w[j];
                center += w[j] * q[j];
                icenter += w[j] * p[j];
            }
            center /= wsum;
            icenter /= wsum;
            // centred coordinates
            std::vector<Vector2f> ph(count), qh(count);
            for(int j=0;j<count;j++){
                ph[j] = p[j]-icenter;
                qh[j] = q[j]-center;
            }
            // similarity matrix
            Matrix2f M,P,Q;
            M = Matrix2f::Zero();
            float mu = 0;
            for(int j=0;j<count;j++){
                P << ph[j][0], ph[j][1], ph[j][1], -ph[j][0];
                Q << qh[j][0], qh[j][1], qh[j][1], -qh[j][0];
                M += w[j]*Q*P;
                mu += w[j] * ph[j].squaredNorm();
            }
            mainImage.xy[i] = M * (mainImage.ixy[i]-icenter) / mu + center;
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

// Load new image
- (IBAction)pushButton_ReadImage:(UIBarButtonItem *)sender {
    if([UIImagePickerController
        isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]){
        UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
        imagePicker.delegate = self;
        imagePicker.allowsEditing = YES;
        imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone){
            //for iPhone
            [self presentViewController:imagePicker animated:YES completion:nil];
        }else{
            //for iPad
            if(imagePopController!=NULL){
                [imagePopController dismissPopoverAnimated:YES];
            }
            imagePopController = [[UIPopoverController alloc] initWithContentViewController:imagePicker];
            [imagePopController presentPopoverFromBarButtonItem:sender
                                       permittedArrowDirections:UIPopoverArrowDirectionAny
                                                       animated:YES];
        }
    }else{
        NSLog(@"Photo library not available");
    }
}
#pragma mark -
#pragma mark UIImagePickerControllerDelegate implementation
// select image
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info{
    GLuint name = mainImage.texture.name;
    glDeleteTextures(1, &name);
    UIImage *pImage = [info objectForKey: UIImagePickerControllerOriginalImage];
    mainImage = [[ImageMesh alloc] initWithUIImage:pImage VerticalDivisions:VDIV HorizontalDivisions:HDIV];
    [self loadTexture:pImage];
    [self setupScreen];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone){
        [self dismissViewControllerAnimated:YES completion:nil];
    }else{
        [imagePopController dismissPopoverAnimated:YES];
    }
}
//cancel
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone){
        [self dismissViewControllerAnimated:YES completion:nil];
    }else{
        [imagePopController dismissPopoverAnimated:YES];
    }
}

// show help screen
- (IBAction)pushButton_HowToUse:(UIBarButtonItem *)sender {
//    creditController = [[CreditController alloc] initWithNibName:@"CreditController" bundle:nil];
//    [self.view addSubview:creditController.view];
}


// Devise orientation
- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration{
    NSLog(@"Orientation changed:%d",self.interfaceOrientation);
    [self setupScreen];
}



/**
 *  termination procedure
 */
- (void)viewDidUnload {
    [super viewDidUnload];
    if (ipts)
        CFRelease(ipts);
}

@end
