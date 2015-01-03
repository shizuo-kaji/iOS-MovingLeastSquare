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

@synthesize verticalDivisions;
@synthesize horizontalDivisions;

@synthesize verticesArr;
@synthesize textureCoordsArr;
@synthesize vertexIndices;
@synthesize indexArrsize;
@synthesize texture;

@synthesize image_width;
@synthesize image_height;


@synthesize numVertices;
@synthesize radius;
@synthesize xy;
@synthesize ixy;
@synthesize selected;
@synthesize triangles;
@synthesize numTriangles;

/** copyWithZone **/
- (id)copyWithZone:(NSZone *)zone{
    ImageMesh *clone =
    [[[self class] allocWithZone:zone] init];
    
    [clone setVerticalDivisions:self.verticalDivisions];
    [clone setHorizontalDivisions:self.horizontalDivisions];
    [clone setIndexArrsize:indexArrsize];
    [clone setVertexIndices:vertexIndices];
    
    [clone setVerticesArr:self.verticesArr];
    [clone setTextureCoordsArr:textureCoordsArr];
    [clone setTexture:self.texture];
    
    [clone setImage_width:self.image_width];
    [clone setImage_height:self.image_height];
    
    [clone setRadius:self.radius];
    [clone setSelected:self.selected];
    [clone setTriangles:self.triangles];
    [clone setNumVertices:self.numVertices];
    [clone setNumTriangles:self.numTriangles];
    [clone setXy:self.xy];
    [clone setIxy:self.ixy];
    
    return  clone;
}

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
- (ImageMesh*)initWithUIImage:(UIImage*)uiImage VerticalDivisions:(GLuint)lverticalDivisions HorizontalDivisions:(GLuint)lhorizontalDivisions{
    if (self = [super init]) {
        verticalDivisions = lverticalDivisions;
        horizontalDivisions = lhorizontalDivisions;
        numVertices = (verticalDivisions+1) * (horizontalDivisions+1);
        indexArrsize = 2 * verticalDivisions * (horizontalDivisions+1);
        numTriangles = 2 * verticalDivisions * horizontalDivisions;
        image_width = (float)uiImage.size.width;
        image_height = (float)uiImage.size.height;
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
                float currY = j * yIncrease;
                textureCoordsArr[count++] = currX;
                textureCoordsArr[count++] = currY + yIncrease;
                textureCoordsArr[count++] = currX;
                textureCoordsArr[count++] = currY;
            }
        }
        [self initialize];
    }
    return self;
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