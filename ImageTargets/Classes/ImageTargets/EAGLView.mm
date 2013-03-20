// Subclassed from AR_EAGLView
#import "EAGLView.h"
#import "Teapot.h"
#import "Texture.h"
#import "Texture2D.h"
#import "dart.h"
#import "dartboard.h"
#import "banana.h"
#import "math.h"
#import "SampleMath.h"

#import <QCAR/Renderer.h>
#import <QCAR/VideoBackgroundConfig.h>
#import "QCARutils.h"

#define _USE_MATH_DEFINES

float dartboardScalefactor = 200.0f;
float dartScalefactor = 200.0f;
int targetIndex = 0;
float distance;
QCAR::Matrix44F modelViewMatrix;
float width = 247.0f;
float height = 173.0f;

//C++ function prototypes
void GLDrawCircle (int circleSegments, CGFloat circleSize, bool filled);
void GLDrawEllipse (int segments, CGFloat width, CGFloat height, bool filled);
GLfloat degreesToRadian(GLfloat deg);
void projectScreenPointToPlane(QCAR::Vec2F point, QCAR::Vec3F planeCenter,
                               QCAR::Vec3F planeNormal, QCAR::Vec3F &intersection,
                               QCAR::Vec3F &lineStart, QCAR::Vec3F &lineEnd);
bool linePlaneIntersection(QCAR::Vec3F lineStart, QCAR::Vec3F lineEnd,
                           QCAR::Vec3F pointOnPlane, QCAR::Vec3F planeNormal,
                           QCAR::Vec3F &intersection);


namespace {
    // Teapot texture filenames
    const char* textureFilenames[] = {
        "TextureTeapotBrass.png",
        "TextureTeapotBlue.png",
        "TextureTeapotRed.png"
    };

    // Model scale factor
    const float kObjectScale = 1.0f;
}


@implementation EAGLView

- (void)renderFrameQCAR {
    
    [self setFramebuffer];
    
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    QCAR::State state = QCAR::Renderer::getInstance().begin();
    QCAR::Renderer::getInstance().drawVideoBackground();
    
    [self enableStuff];
    
    
    glMatrixMode(GL_PROJECTION);
    glLoadMatrixf(qUtils.projectionMatrix.data);
    
    //draw stuff that is always visible
    //glTranslatef(0.0f, 0.0f, 50.0f);
    //[self drawDart];
    
    
    // draw stuff that is only visible when we see the target
    if (state.getNumTrackableResults() == 1) {
        const QCAR::TrackableResult* result = state.getTrackableResult(targetIndex);
        modelViewMatrix = QCAR::Tool::convertPose2GLMatrix(result->getPose());
        [self computeDistanceToTarget:result->getPose()];
        
        //draw stuff relative to the viewport
        
        glMatrixMode(GL_MODELVIEW);
        glLoadMatrixf(modelViewMatrix.data);
        
        //draw stuff relative to the image target
        

        [self drawDart];
    }
    
    [self disableStuff];
    
    QCAR::Renderer::getInstance().end();
    [self presentFramebuffer];
}

- (void)enableStuff {
    glEnable(GL_TEXTURE_2D);
    glEnable(GL_LIGHTING);
    glEnable(GL_LIGHT0);
    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_NORMAL_ARRAY);
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);
    glEnable(GL_DEPTH_TEST);
    glEnable(GL_CULL_FACE);
    glCullFace(GL_BACK);
}

- (void)disableStuff {
    glDisable(GL_DEPTH_TEST);
    glDisable(GL_CULL_FACE);    
    glDisable(GL_TEXTURE_2D);
    glDisableClientState(GL_VERTEX_ARRAY);
    glDisableClientState(GL_NORMAL_ARRAY);
    glDisableClientState(GL_TEXTURE_COORD_ARRAY);
}

- (void)computeDistanceToTarget:(QCAR::Matrix34F)pose {
    QCAR::Vec3F position(pose.data[3], pose.data[7], pose.data[11]);
    distance = sqrt(position.data[0] * position.data[0] +
                    position.data[1] * position.data[1] +
                    position.data[2] * position.data[2]);
}

- (void)drawBanana {
    glPushMatrix();
    glRotatef(90.0f, 1.0f, 0.0f, 0.0f);
    glRotatef(-180.0f, 0.0f, 0.0f, 1.0f);
    glVertexPointer(3, GL_FLOAT, 0, bananaVerts);
    glNormalPointer(GL_FLOAT, 0, bananaNormals);
    glTexCoordPointer(2, GL_FLOAT, 0, bananaTexCoords);
    glDrawArrays(GL_TRIANGLES, 0, bananaNumVerts);
    glPopMatrix();
}

- (void)drawDartboard {
    glPushMatrix();
    glRotatef(90.0f, 1.0f, 0.0f, 0.0f);
    glVertexPointer(3, GL_FLOAT, 0, dartboardVerts);
    glNormalPointer(GL_FLOAT, 0, dartboardNormals);
    glTexCoordPointer(2, GL_FLOAT, 0, dartboardTexCoords);
    glDrawArrays(GL_TRIANGLES, 0, dartboardNumVerts);
    glPopMatrix();
}

- (void)drawDart {
    glPushMatrix();
    glVertexPointer(3, GL_FLOAT, 0, dartVerts);
    glNormalPointer(GL_FLOAT, 0, dartNormals);
    glTexCoordPointer(2, GL_FLOAT, 0, dartTexCoords);
    glDrawArrays(GL_TRIANGLES, 0, dartNumVerts);
    glPopMatrix();
}

- (void)drawObjectDragged {
    glPushMatrix();
    glTranslatef(0.0f, 0.0f, 80.0f);
    glRotatef(180.0f, 1.0f, 0.0f, 0.0f);
    glRotatef(180.0f, 0.0f, 0.0f, 1.0f);
    [self drawObjectX:0 andY:0];
    glPopMatrix();
}

- (void)drawObjectX: (int)x andY:(int)y {
    glPushMatrix();
    //translate from center to where the object should be drawn
    glTranslatef(x, y, 0.0f);
    glTranslatef(0.0f, 0.0f, -kObjectScale);
    Object3D *obj3d = [objects3D objectAtIndex:targetIndex];
    // Draw object
    glBindTexture(GL_TEXTURE_2D, [obj3d.texture textureID]);
    glTexCoordPointer(2, GL_FLOAT, 0, (const GLvoid*) obj3d.texCoords);
    glVertexPointer(3, GL_FLOAT, 0, (const GLvoid*)obj3d.vertices);
    glNormalPointer(GL_FLOAT, 0, (const GLvoid*)obj3d.normals);
    glDrawElements(GL_TRIANGLES, obj3d.numIndices, GL_UNSIGNED_SHORT, (const GLvoid*)obj3d.indices);
    //translate back to the origin / center
    glTranslatef(-x, -y, 0.0f);
    glPopMatrix();
}

- (void)drawObject
{
    Object3D *obj3D = [objects3D objectAtIndex:targetIndex];
    glTranslatef(0.0f, 0.0f, -kObjectScale);
    glPushMatrix();
    glBindTexture(GL_TEXTURE_2D, [obj3D.texture textureID]);
    glTexCoordPointer(2, GL_FLOAT, 0, (const GLvoid*)obj3D.texCoords);
    glVertexPointer(3, GL_FLOAT, 0, (const GLvoid*)obj3D.vertices);
    glNormalPointer(GL_FLOAT, 0, (const GLvoid*)obj3D.normals);
    glDrawElements(GL_TRIANGLES, obj3D.numIndices, GL_UNSIGNED_SHORT, (const GLvoid*)obj3D.indices);
    glPopMatrix();
}

- (void)drawCircle:(GLfloat)size
{
    GLDrawCircle(360, size, YES);
}

- (void)drawBullseye
{
    glPushMatrix();
    glColor4f(0.0f, 0.0f, 0.0f, 1.0f);
    [self drawCircle:80.0f];
    glTranslatef(0.0f, 0.0f, 1.0f);
    glColor4f(1.0f, 0.0f, 0.0f, 1.0f);
    [self drawCircle:10.0f];
    glPopMatrix();
}

- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    //get the location of the tap in screen coordinates
    UITouch* touch = [touches anyObject];
    CGPoint location = [touch locationInView:self];
    //put plane coordinates into 2D vector
    QCAR::Vec2F coord = [self projectPoint: QCAR::Vec2F(location.x, location.y)];
    //check if touched point on the screen would be projected on the plane
    NSLog(@"Touch at: (%f,%f)", coord.data[0], coord.data[1]);
    if(![self isPointOnPlane:coord]){
        NSLog(@"Point not on the target!");
    }
}

- (void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    //not needed
}

- (void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    //not needed
}

- (void) touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    //not needed
}

- (QCAR::Vec2F)projectPoint: (QCAR::Vec2F)point
{
    //define temporary variables for the plane coordinates
    QCAR::Vec3F intersection, lineStart, lineEnd;
    //project sreen points onto the plane
    projectScreenPointToPlane(point, QCAR::Vec3F(0, 0, 0), QCAR::Vec3F(0, 0, 1), intersection, lineStart, lineEnd);
    return QCAR::Vec2F(intersection.data[0], intersection.data[1]);
}

- (BOOL)isPointOnPlane: (QCAR::Vec2F)point
{
    return abs(point.data[0]) < (width / 2.0f) && abs(point.data[1]) < (height / 2.0f);
}

// called after QCAR is initialised but before the camera starts
- (void) postInitQCAR
{
    // Here we could make a QCAR::setHint call to set the maximum
    // number of simultaneous targets
    // QCAR::setHint(QCAR::HINT_MAX_SIMULTANEOUS_IMAGE_TARGETS, 2);
}

- (void) setup3dObjects
{
    // build the array of objects we want drawn and their texture
    // in this example we have 3 targets and require 3 models
    // but using the same underlying 3D model of a teapot, differentiated
    // by using a different texture for each
    
    for (int i=0; i < [textures count]; i++)
    {
        Object3D *obj3D = [[Object3D alloc] init];
        
        obj3D.numVertices = NUM_TEAPOT_OBJECT_VERTEX;
        obj3D.vertices = teapotVertices;
        obj3D.normals = teapotNormals;
        obj3D.texCoords = teapotTexCoords;
        
        obj3D.numIndices = NUM_TEAPOT_OBJECT_INDEX;
        obj3D.indices = teapotIndices;
        
        obj3D.texture = [textures objectAtIndex:i];
        
        [objects3D addObject:obj3D];
        [obj3D release];
    }
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
	if (self)
    {
        // create list of textures we want loading - ARViewController will do this for us
        int nTextures = sizeof(textureFilenames) / sizeof(textureFilenames[0]);
        for (int i = 0; i < nTextures; ++i)
            [textureList addObject: [NSString stringWithUTF8String:textureFilenames[i]]];
    }
    return self;
}



@end

/*THIS IS WHERE C++ CODE STARTS */
/*THIS IS WHERE C++ CODE STARTS */
/*THIS IS WHERE C++ CODE STARTS */


GLfloat degreesToRadian(GLfloat deg)
{
    return deg * (180.0/M_PI);
}

void GLDrawEllipse (int segments, CGFloat width, CGFloat height, bool filled)
{
    GLfloat vertices[segments*2];
    int count=0;
    for (GLfloat i = 0; i < 360.0f; i+=(360.0f/segments))
    {
        vertices[count++] = (cos(degreesToRadian(i))*width);
        vertices[count++] = (sin(degreesToRadian(i))*height);
    }
    glVertexPointer (2, GL_FLOAT , 0, vertices);
    glDrawArrays ((filled) ? GL_TRIANGLE_FAN : GL_LINE_LOOP, 0, segments);
}
void GLDrawCircle (int circleSegments, CGFloat circleSize, bool filled)
{
    GLDrawEllipse(circleSegments, circleSize, circleSize, filled);
}

//copied from Dominoes sample Application
void projectScreenPointToPlane(QCAR::Vec2F point, QCAR::Vec3F planeCenter,
                               QCAR::Vec3F planeNormal, QCAR::Vec3F &intersection,
                               QCAR::Vec3F &lineStart, QCAR::Vec3F &lineEnd){
    
    QCARutils *qUtils = [QCARutils getInstance];
    
    // Window Coordinates to Normalized Device Coordinates
    QCAR::VideoBackgroundConfig config = QCAR::Renderer::getInstance().getVideoBackgroundConfig();
    
    float halfScreenWidth = qUtils.viewSize.height / 2.0f; // note use of height for width
    float halfScreenHeight = qUtils.viewSize.width / 2.0f; // likewise
    
    float halfViewportWidth = config.mSize.data[0] / 2.0f;
    float halfViewportHeight = config.mSize.data[1] / 2.0f;
    
    float x = (qUtils.contentScalingFactor * point.data[0] - halfScreenWidth) / halfViewportWidth;
    float y = (qUtils.contentScalingFactor * point.data[1] - halfScreenHeight) / halfViewportHeight * -1;
    
    QCAR::Vec4F ndcNear(x, y, -1, 1);
    QCAR::Vec4F ndcFar(x, y, 1, 1);
    
    // Normalized Device Coordinates to Eye Coordinates
    QCAR::Matrix44F projectionMatrix = [QCARutils getInstance].projectionMatrix;
    QCAR::Matrix44F inverseProjMatrix = SampleMath::Matrix44FInverse(projectionMatrix);
    
    QCAR::Vec4F pointOnNearPlane = SampleMath::Vec4FTransform(ndcNear, inverseProjMatrix);
    QCAR::Vec4F pointOnFarPlane = SampleMath::Vec4FTransform(ndcFar, inverseProjMatrix);
    pointOnNearPlane = SampleMath::Vec4FDiv(pointOnNearPlane, pointOnNearPlane.data[3]);
    pointOnFarPlane = SampleMath::Vec4FDiv(pointOnFarPlane, pointOnFarPlane.data[3]);
    
    // Eye Coordinates to Object Coordinates
    QCAR::Matrix44F inverseModelViewMatrix = SampleMath::Matrix44FInverse(modelViewMatrix);
    
    QCAR::Vec4F nearWorld = SampleMath::Vec4FTransform(pointOnNearPlane, inverseModelViewMatrix);
    QCAR::Vec4F farWorld = SampleMath::Vec4FTransform(pointOnFarPlane, inverseModelViewMatrix);
    
    lineStart = QCAR::Vec3F(nearWorld.data[0], nearWorld.data[1], nearWorld.data[2]);
    lineEnd = QCAR::Vec3F(farWorld.data[0], farWorld.data[1], farWorld.data[2]);
    linePlaneIntersection(lineStart, lineEnd, planeCenter, planeNormal, intersection);
}

//also copied from Dominoes Sample Application
bool linePlaneIntersection(QCAR::Vec3F lineStart, QCAR::Vec3F lineEnd,
                           QCAR::Vec3F pointOnPlane, QCAR::Vec3F planeNormal,
                           QCAR::Vec3F &intersection){
    
    QCAR::Vec3F lineDir = SampleMath::Vec3FSub(lineEnd, lineStart);
    lineDir = SampleMath::Vec3FNormalize(lineDir);
    
    QCAR::Vec3F planeDir = SampleMath::Vec3FSub(pointOnPlane, lineStart);
    
    float n = SampleMath::Vec3FDot(planeNormal, planeDir);
    float d = SampleMath::Vec3FDot(planeNormal, lineDir);
    
    if (fabs(d) < 0.00001) {
        // Line is parallel to plane
        return false;
    }
    
    float dist = n / d;
    
    QCAR::Vec3F offset = SampleMath::Vec3FScale(lineDir, dist);
    intersection = SampleMath::Vec3FAdd(lineStart, offset);
    
    return true;
}
