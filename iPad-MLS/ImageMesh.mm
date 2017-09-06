//
//  ImageMesh.m
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

#import "ImageMesh.h"

using namespace Eigen;

@implementation ImageMesh

@synthesize verticalDivisions,horizontalDivisions;

@synthesize verticesArr,textureCoordsArr,vertexIndices,indexArrsize;
@synthesize texture;

@synthesize image_width,image_height;

@synthesize xy,ixy,radius;
@synthesize selected;
@synthesize triangles;
@synthesize numTriangles,numVertices;

// dealloc
- (void)dealloc{
    free(verticesArr);
    free(textureCoordsArr);
    free(vertexIndices);
    free(xy);
    free(ixy);
    free(selected);
    free(triangles);
}

// init
- (ImageMesh*)initWithVDiv:(GLuint)lverticalDivisions HDiv:(GLuint)lhorizontalDivisions{
    if (self = [super init]) {
        verticalDivisions = lverticalDivisions;
        horizontalDivisions = lhorizontalDivisions;
        numVertices = (verticalDivisions+1) * (horizontalDivisions+1);
        indexArrsize = 2 * verticalDivisions * (horizontalDivisions+1);
        numTriangles = 2 * verticalDivisions * horizontalDivisions;
        //malloc
        verticesArr = (GLfloat *)malloc(2 * indexArrsize * sizeof(*verticesArr));
        textureCoordsArr = (GLfloat *)malloc(2 * indexArrsize * sizeof(*textureCoordsArr));
        vertexIndices = (int *)malloc(indexArrsize * sizeof(*vertexIndices));
        xy = (Vector2f *)malloc(numVertices * sizeof(*xy));
        ixy = (Vector2f *)malloc(numVertices * sizeof(*ixy));
        selected = (bool *)calloc(numVertices, sizeof(*selected));
        triangles = (int *)malloc(3 * numTriangles * sizeof(*triangles));
        
        // prepare indice array:  each point is doubled to draw triangles correctly.
        int count=0;
        for (int j=0; j<verticalDivisions; j++) {
            for (int i=0; i <= horizontalDivisions; i++) {
                vertexIndices[count++] = (j+1)*(horizontalDivisions+1)+i;   // lower
                vertexIndices[count++] = j*(horizontalDivisions+1)+i;       // upper
            }
        }
        // prepare triangles
        count=0;
        int stv=0;
        for (int j=0; j<verticalDivisions; j++) {
            for (int i=0; i < 2*horizontalDivisions; i++) {
                triangles[count++] = vertexIndices[stv];
                triangles[count++] = vertexIndices[stv+1];
                triangles[count++] = vertexIndices[stv+2];
                stv++;
            }
            stv = stv +2;
        }
        
        // prepare texture coordinate
        float xIncrease = 1.0f/horizontalDivisions;
        float yIncrease = 1.0f/verticalDivisions;
        count = 0;
        for (int j=0; j< verticalDivisions; j++) {
            for (int i=0; i <= horizontalDivisions; i++) {
                float currX = i * xIncrease;
                float currY = 1- j * yIncrease;
                textureCoordsArr[count++] = currX;
                textureCoordsArr[count++] = currY - yIncrease;
                textureCoordsArr[count++] = currX;
                textureCoordsArr[count++] = currY;
            }
        }
    }
    return self;
}

-(void) loadImage:(UIImage*)pImage{
    NSError *error;
    NSDictionary* options = nil; //@{GLKTextureLoaderOriginBottomLeft: @YES};
    //resize
    CGFloat oldWidth = pImage.size.width;
    CGFloat oldHeight = pImage.size.height;
    CGFloat scaleFactor = (oldWidth > oldHeight) ? 1024 / oldWidth : 1024 / oldHeight;
    CGSize size = CGSizeMake(oldWidth * scaleFactor, oldHeight * scaleFactor);
    UIGraphicsBeginImageContext(size);
    [pImage drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    //generate texture
    UIImage *pngimage = [UIImage imageWithData:UIImagePNGRepresentation(image)];
    NSLog(@"GL Error = %u", glGetError());
    texture = [GLKTextureLoader textureWithCGImage:pngimage.CGImage options:options error:&error];
    if(error)NSLog(@"Error loading texture from image: %@",error);
    image_width = (float)image.size.width;
    image_height = (float)image.size.height;
    // compute touch radius for each vertex
    float r = image_width/(float)(2*horizontalDivisions);
    radius = r*r;
    [self initialize];
    [self deform];
}


// set coordinates
- (void)deform{
    // prepare OpenGL vertices
    for(int i=0;i<indexArrsize;i++){
        verticesArr[2*i]=xy[vertexIndices[i]][0];
        verticesArr[2*i+1]=xy[vertexIndices[i]][1];
    }
}
- (void)initialize{
    // prepare mesh vertices
    float stX = - image_width / 2;
    float stY = - image_height / 2;
    int count = 0;
    float width = (image_width)/horizontalDivisions;
    float height = (image_height)/verticalDivisions;
    for (int j=0; j<=verticalDivisions; j++) {
        for (int i=0; i<=horizontalDivisions; i++) {
            xy[count] <<  i * width + stX, j * height + stY;
            ixy[count] = xy[count];
            count++;
        }
    }
    for(int i=0;i<numVertices;i++){
        selected[i] = false;
    }
    [self deform];
}
@end
