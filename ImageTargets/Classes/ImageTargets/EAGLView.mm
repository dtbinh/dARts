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

#define PI 3.1415926

#define NOT_ON_BOARD -1
#define INNER_BULL 0
#define OUTER_BULL 1
#define INNER_AREA 2
#define TRIPLE_RING 3
#define OUTER_AREA 4
#define DOUBLE_RING 5
#define NUMBER_AREA 6


float dartboardScalefactor = 200.0f;
float dartScalefactor = 200.0f;
int targetIndex = 0;
float distance;
QCAR::Matrix44F modelViewMatrix;
QCAR::Matrix44F cameraPosition;
UILabel* label;
NSString  *labelString;
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
    
    
    // draw stuff that is only visible when we see the target
    if (state.getNumTrackableResults() == 1) {
        const QCAR::TrackableResult* result = state.getTrackableResult(targetIndex);
        modelViewMatrix = QCAR::Tool::convertPose2GLMatrix(result->getPose());
        [self computeDistanceToTarget:result->getPose()];
        [self computeCameraPosition:modelViewMatrix];
        
        float cam_x = cameraPosition.data[12];
        float cam_y = cameraPosition.data[13];
        float cam_z = cameraPosition.data[14];
        
        glPushMatrix();
        glRotatef(90.0f, 0.0f, 1.0f, 0.0f);
        glTranslatef(cam_x, cam_y, cam_z / 10);
        [self drawDart];
        glPopMatrix();
        
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

- (void)computeCameraPosition:(QCAR::Matrix44F)modelViewMatrix {
    QCAR::Matrix44F inverseMV = SampleMath::Matrix44FInverse(modelViewMatrix);
    cameraPosition = SampleMath::Matrix44FTranspose(inverseMV);
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
    glScalef(0.5f, 0.5f, 0.5f);
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
    float distanceFromOrigin = [self distanceFromOrigin:coord];
    int targetArea = [self getTargetArea:distanceFromOrigin];
    [self printTargetArea:targetArea];
    int number = [self getNumberFromAngle:[self getAngleFromPoint:coord]];
    [self getScoreBasedOnArea:targetArea andNumber:number];
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

- (float)distanceFromOrigin: (QCAR::Vec2F)point
{
    return sqrtf(point.data[0] * point.data[0] + point.data[1] * point.data[1]);
}

- (int)getScoreBasedOnArea: (int) area andNumber: (int) number
{
    int score = 0;
    
    if(area == NUMBER_AREA || area == NOT_ON_BOARD){
        score = 0;
    }
    else if(area == INNER_AREA || area == OUTER_AREA){
        score = number;
    }
    else if(area == DOUBLE_RING){
        score = number * 2;
    }
    else if(area == TRIPLE_RING){
        score = number * 3;
    }
    else if(area == OUTER_BULL){
        score = 25;
    }
    else if(area == INNER_BULL){
        score = 50;
    }
    
    NSLog(@"Score: %i", score);
    
    return score;
}

- (int)getNumberFromAngle: (float) angle
{
    int number = 0;
    
    float a = angle;
    
    if((a >= 351.0f && a <= 360.0f) || (a >= 0.0f && a < 9.0f)){
        number = 20;
    }
    else if(a >= 9.0f && a < 27.0f){
        number = 1;
    }
    else if(a >= 27.0f && a < 45.0f){
        number = 18;
    }
    else if(a >= 45.0f && a < 63.0f){
        number = 4;
    }
    else if(a >= 63.0f && a < 81.0f){
        number = 13;
    }
    else if(a >= 81.0f && a < 99.0f){
        number = 6;
    }
    else if(a >= 99.0f && a < 117.0f){
        number = 10;
    }
    else if(a >= 117.0f && a < 135.0f){
        number = 15;
    }
    else if(a >= 135.0f && a < 153.0f){
        number = 2;
    }
    else if(a >= 153.0f && a < 171.0f){
        number = 17;
    }
    else if(a >= 171.0f && a < 189.0f){
        number = 3;
    }
    else if(a >= 189.0f && a < 207.0f){
        number = 19;
    }
    else if(a >= 207.0f && a < 225.0f){
        number = 7;
    }
    else if(a >= 225.0f && a < 243.0f){
        number = 16;
    }
    else if(a >= 243.0f && a < 261.0f){
        number = 8;
    }
    else if(a >= 261.0f && a < 279.0f){
        number = 11;
    }
    else if(a >= 279.0f && a < 297.0f){
        number = 14;
    }
    else if(a >= 297.0f && a < 315.0f){
        number = 9;
    }
    else if(a >= 315.0f && a < 333.0f){
        number = 12;
    }
    else if(a >= 333.0f && a < 351.0f){
        number = 5;
    }
    
    NSLog(@"Target number: %i", number);
    return number;

}

- (float)getAngleFromPoint: (QCAR::Vec2F) point
{
    //get data from the points
    float x = point.data[0];
    float y = point.data[1];
    
    float angle = 0;
    
    //1st quadrant
    if(x > 0 && y > 0){
        angle = (atan2(abs(x), abs(y)) * 180.0f/PI);
    }
    //2nd quadrant
    else if(x > 0 && y < 0){
        angle = (atan2(abs(y), abs(x)) * 180.0f/PI) + 90.0f;
    }
    //3rd quadrant
    else if(x < 0 && y < 0){
        angle = (atan2(abs(x), abs(y)) * 180.0f/PI) + 180.0f;
    }
    //4th quadrant
    else if(x < 0 && y > 0){
        angle = (atan2(abs(y), abs(x)) * 180.0f/PI) + 270.0f;
    }
    
    //NSLog(@"Angle: %f°", angle);
    
    return angle;
}

- (int)getTargetArea: (float) d
{
    int t = 0;
    
    if(d >= 0.0f && d < 1.5625f){
        t = INNER_BULL;
    }
    else if(d >= 1.5625f && d < 3.125f){
        t = OUTER_BULL;
    }
    else if(d >= 3.125f && d < 21.09375f){
        t = INNER_AREA;
    }
    else if(d >= 21.09375f && d < 23.046875f){
        t = TRIPLE_RING;
    }
    else if(d >= 23.046875f && d < 35.546875f){
        t = OUTER_AREA;
    }
    else if(d >= 35.546875f && d < 37.5f){
        t = DOUBLE_RING;
    }
    else if(d >= 37.5f && d < 50.0f){
        t = NUMBER_AREA;
    }
    else{
        t = NOT_ON_BOARD;
    }
    return t;
}

- (void)printTargetArea:(int) a
{
    switch (a) {
        case INNER_BULL:
            NSLog(@"Target Area: INNER_BULL");
            break;
        case OUTER_BULL:
            NSLog(@"Target Area: OUTER_BULL");
            break;
        case INNER_AREA:
            NSLog(@"Target Area: INNER_AREA");
            break;
        case TRIPLE_RING:
            NSLog(@"Target Area: TRIPLE RING");
            break;
        case OUTER_AREA:
            NSLog(@"Target Area: OUTER_AREA");
            break;
        case DOUBLE_RING:
            NSLog(@"Target Area: DOUBLE_RING");
            break;
        case NUMBER_AREA:
            NSLog(@"Target Area: NUMBER_AREA");
            break;
        default:
            NSLog(@"Target Area: NOT_ON_BOARD");
            break;
    }
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
        for (int i = 0; i < nTextures; ++i) {
            [textureList addObject: [NSString stringWithUTF8String:textureFilenames[i]]];
        }
        
        //[self createLabel: @"Hello"];
    }
    return self;
}

- (void)createLabel:(NSString *)text {
    label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 568, 30)];
    label.transform = CGAffineTransformMakeRotation(M_PI_2*2);
    label.text = text;
    label.backgroundColor = [UIColor blackColor];
    label.textColor = [UIColor orangeColor];
    [self addSubview:label];
    [label release];
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
