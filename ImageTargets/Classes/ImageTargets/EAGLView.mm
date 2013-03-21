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
#import <vector>

#import <QCAR/Renderer.h>
#import <QCAR/VideoBackgroundConfig.h>
#import "QCARutils.h"

#define _USE_MATH_DEFINES

#define PI 3.1415926
#define CAMERA_TO_DART_DISTANCE 80.0
#define THROWING_DISTANCE 250.0

#define THROWING_PHASE 0
#define COLLECTION_PHASE 1

int currentPhase = 0;

#define PLAYER_A 0
#define PLAYER_B 1

int currentPlayer = 0;

#define NOT_ON_BOARD -1
#define INNER_BULL 0
#define OUTER_BULL 1
#define INNER_AREA 2
#define TRIPLE_RING 3
#define OUTER_AREA 4
#define DOUBLE_RING 5
#define NUMBER_AREA 6

#define FINAL_SCORE 300;

int throwone = 0;
int throwtwo = 0;
int throwthree = 0;

#define THROW_1 1
#define THROW_2 2
#define THROW_3 3

int currentThrow = 1;

int targetIndex = 0;
float distance;
QCAR::Matrix44F modelViewMatrix;
QCAR::Matrix44F cameraPosition;
QCAR::Matrix44F dartPoseCamera;
QCAR::Matrix44F dartPoseTarget;
bool throwDart = NO;
std::vector<QCAR::Vec2F> dartPositions;


UILabel * statusLabel;
UILabel * turnLabel;
UILabel * playerAScoreLabel;
UILabel * playerBScoreLabel;
UILabel * playerADartLabel;
UILabel * playerBDartLabel;
UILabel * playerAThrowOneLabel;
UILabel * playerBThrowOneLabel;
UILabel * playerAThrowTwoLabel;
UILabel * playerBThrowTwoLabel;
UILabel * playerAThrowThreeLabel;
UILabel * playerBThrowThreeLabel;

int playerAScore = 0;
int playerBScore = 0;
int numberOfDarts = 3;

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

@synthesize accelerometer;

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
        distance = [self computeDistanceToTarget:result->getPose()];
        cameraPosition = [self computeCameraPosition:modelViewMatrix];
        
        //draw stuff relative to the viewport
        
        if(currentPhase == THROWING_PHASE){
            if (distance <= THROWING_DISTANCE){
                [self setLabel:statusLabel toText:@"Step away from the dart board!"];
            }
            else if(distance > THROWING_DISTANCE){
                [self setLabel:statusLabel toText:@"Accelerate device to throw!"];
                [self drawDartInFrontOfCamera];
            }
        }
        else if (currentPhase == COLLECTION_PHASE){
            [self setLabel:statusLabel toText:@"Collect darts by tapping them!"];
        }
        
        
        glMatrixMode(GL_MODELVIEW);
        glLoadMatrixf(modelViewMatrix.data);
        
        //draw stuff relative to the image target
        
        for(int i = 0; i < dartPositions.size(); i ++){
            [self drawDartAtPosition:dartPositions.at(i)];
        }

    }
    else {
        [self setLabel:statusLabel toText:@"Aim at the dartboard!"];
    }
    
    [self disableStuff];
    
    QCAR::Renderer::getInstance().end();
    [self presentFramebuffer];
}

- (void)accelerometer:(UIAccelerometer *)accelerometer didAccelerate:(UIAcceleration *)acceleration {
    if(acceleration.z > 0.3f && distance > THROWING_DISTANCE && currentPhase == THROWING_PHASE){
        NSLog(@"Throw speed: %f", acceleration.z);
        dartPoseTarget = modelViewMatrix;
        dartPoseCamera = cameraPosition;
        //project the middle of the touch screen to world coordinates
        QCAR::Vec2F coord = [self projectPoint:QCAR::Vec2F(284.0f,160.0f)];
        //push the new world coordinate on the vector of the dart positions
        dartPositions.push_back(coord);
        //compute the distance of that point to the origin
        float distanceFromOrigin = [self distanceFromOrigin:coord];
        //based on this distance, return the target area (inner bullseye etc.)
        int targetArea = [self getTargetArea:distanceFromOrigin];
        //based on the angle from the origin, determine which number was hit
        int number = [self getNumberFromAngle:[self getAngleFromPoint:coord]];
        //now get the score
        int score = [self getScoreBasedOnArea:targetArea andNumber:number];
        //add the score to the current score
        NSString *scoreText = [self getScoreTextBasedOnArea:targetArea andNumber:number];
        
        //depending on who is the current player - update the score and number of darts
        if(currentPlayer == PLAYER_A){
            if(currentThrow == THROW_1){
                throwone = score;
                [self setLabel:playerAThrowOneLabel toText:scoreText];
            }
            else if(currentThrow == THROW_2){
                throwtwo = score;
                [self setLabel:playerAThrowTwoLabel toText:scoreText];
            }
            else if(currentThrow == THROW_3){
                throwthree = score;
                [self setLabel:playerAThrowThreeLabel toText:scoreText];
            }
            playerAScore += score;
            //set new score
            [self setLabel:playerAScoreLabel toText: [NSString stringWithFormat:@"Score: %i", playerAScore]];
            //subtract 1 from the total number of darts
            numberOfDarts = numberOfDarts - 1;
            //set the dart label accordingly
            [self setLabel:playerADartLabel toText:[NSString stringWithFormat:@"Darts: %i", numberOfDarts]];
        }
        else if(currentPlayer == PLAYER_B){
            if(currentThrow == THROW_1){
                throwone = score;
                [self setLabel:playerBThrowOneLabel toText:scoreText];
            }
            else if(currentThrow == THROW_2){
                throwtwo = score;
                [self setLabel:playerBThrowTwoLabel toText:scoreText];
            }
            else if(currentThrow == THROW_3){
                throwthree = score;
                [self setLabel:playerBThrowThreeLabel toText:scoreText];
            }
            playerBScore += score;
            //set new score
            [self setLabel:playerBScoreLabel toText: [NSString stringWithFormat:@"Score: %i", playerBScore]];
            //subtract 1 from the total number of darts
            numberOfDarts = numberOfDarts - 1;
            //set the dart label accordingly
            [self setLabel:playerBDartLabel toText:[NSString stringWithFormat:@"Darts: %i", numberOfDarts]];
        }
        
        //if the current player has no more darts left, the collection phase begins
        if(numberOfDarts == 0){
            throwone = 0;
            throwtwo = 0;
            throwthree = 0;
            currentThrow = THROW_1;
            currentPhase = COLLECTION_PHASE;
        }
        else{
            currentThrow = currentThrow + 1;
        }
        
    }
}

- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    //not needed
}

- (void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    //not needed
}

- (void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if(currentPhase == COLLECTION_PHASE){
        UITouch *touch = [touches anyObject];
        CGPoint location = [touch locationInView:self];
        QCAR::Vec2F coord = [self projectPoint: QCAR::Vec2F(location.x, location.y)];
        int index = [self getDartAt:coord];
        if (index != -1){
            dartPositions.erase(dartPositions.begin() + index);
            NSLog(@"You picked up a dart!");
            numberOfDarts = numberOfDarts + 1;
            if(currentPlayer == PLAYER_A){
                [self setLabel:playerADartLabel toText:[NSString stringWithFormat:@"Darts: %i", numberOfDarts]];
            }
            else if(currentPlayer == PLAYER_B){
                [self setLabel:playerBDartLabel toText:[NSString stringWithFormat:@"Darts: %i", numberOfDarts]];
            }
        
        }
        
        //if the number of darts equals 3 again, change player and phase
        if(numberOfDarts == 3){
            if(currentPlayer == PLAYER_A){
                [self setLabel:playerAThrowOneLabel toText:@""];
                [self setLabel:playerAThrowTwoLabel toText:@""];
                [self setLabel:playerAThrowThreeLabel toText:@""];
                currentPlayer = PLAYER_B;
                turnLabel.text = @"Player B";
                turnLabel.textColor = [UIColor redColor];
            }
            else if(currentPlayer == PLAYER_B){
                [self setLabel:playerBThrowOneLabel toText:@""];
                [self setLabel:playerBThrowTwoLabel toText:@""];
                [self setLabel:playerBThrowThreeLabel toText:@""];
                currentPlayer = PLAYER_A;
                turnLabel.text = @"Player A";
                turnLabel.textColor = [UIColor blueColor];
            }
            currentPhase = THROWING_PHASE;
        }

    }
}

- (void) touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    //not needed
}


- (int)getDartAt: (QCAR::Vec2F)point
{
    int index = -1;
    for (int i = 0; i < dartPositions.size(); i++) {
        float distance = sqrt(pow(point.data[0] - dartPositions[i].data[0], 2.0) + pow(point.data[1] - dartPositions[i].data[1], 2.0));
        if (distance < 15.0) {
            index = i;
            break;
        }
    }
    return index;
}

- (void)drawDartInFrontOfCamera
{
    glPushMatrix();
    glMatrixMode(GL_MODELVIEW);
    dartPoseCamera = cameraPosition;
    //we don't want x and y translation because the dart should be in front of the viewport
    dartPoseCamera.data[12] = 0.0f;
    dartPoseCamera.data[13] = 0.0f;
    //we want the dart floating in front of the viewport
    dartPoseCamera.data[14] = CAMERA_TO_DART_DISTANCE;
    //the dart should not rotate when the camera rotates
    dartPoseCamera.data[8] = 0.0f;
    dartPoseCamera.data[9] = 0.0f;
    dartPoseCamera.data[10] = 0.0f;
    glLoadMatrixf(dartPoseCamera.data);
    [self drawDart];
    glPopMatrix();
}

- (void)drawDartAtPosition: (QCAR::Vec2F) position
{

    glPushMatrix();
    glTranslatef(position.data[0], position.data[1], 32.0f);
    glScalef(0.5f, 0.5f, 0.5f);
    glRotatef(4.0f, 1.0f, 0.0f, 0.0f);
    glRotatef(90.0f, 0.0f, 1.0f, 0.0f);
    glVertexPointer(3, GL_FLOAT, 0, dartVerts);
    glNormalPointer(GL_FLOAT, 0, dartNormals);
    glTexCoordPointer(2, GL_FLOAT, 0, dartTexCoords);
    glDrawArrays(GL_TRIANGLES, 0, dartNumVerts);
    glPopMatrix();

}

- (void)drawDart {
    //dart origin is in the middle -> have to pull it out of the board
    
    glPushMatrix();
    glTranslatef(0.0f, 0.0f, 32.0f);
    glScalef(0.5f, 0.5f, 0.5f);
    glRotatef(8.0f, 1.0f, 0.0f, 0.0f);
    glRotatef(90.0f, 0.0f, 1.0f, 0.0f);
    glVertexPointer(3, GL_FLOAT, 0, dartVerts);
    glNormalPointer(GL_FLOAT, 0, dartNormals);
    glTexCoordPointer(2, GL_FLOAT, 0, dartTexCoords);
    glDrawArrays(GL_TRIANGLES, 0, dartNumVerts);
    glPopMatrix();
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
        
        //start the accelerometer
        self.accelerometer = [UIAccelerometer sharedAccelerometer];
        self.accelerometer.updateInterval = 0.1;
        self.accelerometer.delegate = self;
        
        
        [self initStatusLabel];
        [self initTurnLabel];
        [self initPlayerAScoreLabel];
        [self initPlayerBScoreLabel];
        [self initPlayerADartLabel];
        [self initPlayerBDartLabel];
        [self initPlayerAThrowOneLabel];
        [self initPlayerBThrowOneLabel];
        [self initPlayerAThrowTwoLabel];
        [self initPlayerBThrowTwoLabel];
        [self initPlayerAThrowThreeLabel];
        [self initPlayerBThrowThreeLabel];
        
        
    }
    return self;
}

- (void) initPlayerBThrowThreeLabel
{
    playerBThrowThreeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, 60.0f, 100.0f, 30.0f)];
    playerBThrowThreeLabel.transform = CGAffineTransformMakeRotation(M_PI_2 * 2);
    //playerBThrowThreeLabel.text = @"Throw Three";
    playerBThrowThreeLabel.textAlignment = NSTextAlignmentCenter;
    playerBThrowThreeLabel.font = [UIFont fontWithName:@"Arial-BoldMT" size:16];
    playerBThrowThreeLabel.backgroundColor = [UIColor clearColor];
    playerBThrowThreeLabel.textColor = [UIColor redColor];
    [self addSubview: playerBThrowThreeLabel];
}

- (void) initPlayerAThrowThreeLabel
{
    playerAThrowThreeLabel = [[UILabel alloc] initWithFrame:CGRectMake(468.0f, 60.0f, 100.0f, 30.0f)];
    playerAThrowThreeLabel.transform = CGAffineTransformMakeRotation(M_PI_2 * 2);
    //playerAThrowThreeLabel.text = @"Throw Three";
    playerAThrowThreeLabel.textAlignment = NSTextAlignmentCenter;
    playerAThrowThreeLabel.font = [UIFont fontWithName:@"Arial-BoldMT" size:16];
    playerAThrowThreeLabel.backgroundColor = [UIColor clearColor];
    playerAThrowThreeLabel.textColor = [UIColor blueColor];
    [self addSubview: playerAThrowThreeLabel];
}

- (void) initPlayerBThrowTwoLabel
{
    playerBThrowTwoLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, 30.0f, 100.0f, 30.0f)];
    playerBThrowTwoLabel.transform = CGAffineTransformMakeRotation(M_PI_2 * 2);
    //playerBThrowTwoLabel.text = @"Throw Two";
    playerBThrowTwoLabel.textAlignment = NSTextAlignmentCenter;
    playerBThrowTwoLabel.font = [UIFont fontWithName:@"Arial-BoldMT" size:16];
    playerBThrowTwoLabel.backgroundColor = [UIColor clearColor];
    playerBThrowTwoLabel.textColor = [UIColor redColor];
    [self addSubview: playerBThrowTwoLabel];
}

- (void) initPlayerAThrowTwoLabel
{
    playerAThrowTwoLabel = [[UILabel alloc] initWithFrame:CGRectMake(468.0f, 30.0f, 100.0f, 30.0f)];
    playerAThrowTwoLabel.transform = CGAffineTransformMakeRotation(M_PI_2 * 2);
    //playerAThrowTwoLabel.text = @"Throw Two";
    playerAThrowTwoLabel.textAlignment = NSTextAlignmentCenter;
    playerAThrowTwoLabel.font = [UIFont fontWithName:@"Arial-BoldMT" size:16];
    playerAThrowTwoLabel.backgroundColor = [UIColor clearColor];
    playerAThrowTwoLabel.textColor = [UIColor blueColor];
    [self addSubview: playerAThrowTwoLabel];
}

- (void) initPlayerBThrowOneLabel
{
    playerBThrowOneLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 100.0f, 30.0f)];
    playerBThrowOneLabel.transform = CGAffineTransformMakeRotation(M_PI_2 * 2);
    //playerBThrowOneLabel.text = @"Throw One";
    playerBThrowOneLabel.textAlignment = NSTextAlignmentCenter;
    playerBThrowOneLabel.font = [UIFont fontWithName:@"Arial-BoldMT" size:16];
    playerBThrowOneLabel.backgroundColor = [UIColor clearColor];
    playerBThrowOneLabel.textColor = [UIColor redColor];
    [self addSubview: playerBThrowOneLabel];
}

- (void) initPlayerAThrowOneLabel
{
    playerAThrowOneLabel = [[UILabel alloc] initWithFrame:CGRectMake(468.0f, 0.0f, 100.0f, 30.0f)];
    playerAThrowOneLabel.transform = CGAffineTransformMakeRotation(M_PI_2 * 2);
    //playerAThrowOneLabel.text = @"Throw One";
    playerAThrowOneLabel.textAlignment = NSTextAlignmentCenter;
    playerAThrowOneLabel.font = [UIFont fontWithName:@"Arial-BoldMT" size:16];
    playerAThrowOneLabel.backgroundColor = [UIColor clearColor];
    playerAThrowOneLabel.textColor = [UIColor blueColor];
    [self addSubview: playerAThrowOneLabel];
}

- (void) initTurnLabel
{
    turnLabel = [[UILabel alloc] initWithFrame:CGRectMake(134.0f, 290.0f, 300.0f, 30.0f)];
    turnLabel.transform = CGAffineTransformMakeRotation(M_PI_2 * 2);
    turnLabel.text = @"Player A";
    turnLabel.textAlignment = NSTextAlignmentCenter;
    turnLabel.font = [UIFont fontWithName:@"Arial-BoldMT" size:16];
    turnLabel.backgroundColor = [UIColor clearColor];
    turnLabel.textColor = [UIColor blueColor];
    [self addSubview: turnLabel];
}

- (void) initPlayerBDartLabel
{
    playerBDartLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, 260.0f, 100.0f, 30.0f)];
    playerBDartLabel.transform = CGAffineTransformMakeRotation(M_PI_2 * 2);
    playerBDartLabel.text = @"Darts: 3";
    playerBDartLabel.textAlignment = NSTextAlignmentCenter;
    playerBDartLabel.font = [UIFont fontWithName:@"Arial-BoldMT" size:16];
    playerBDartLabel.backgroundColor = [UIColor clearColor];
    playerBDartLabel.textColor = [UIColor redColor];
    [self addSubview: playerBDartLabel];
}

- (void) initPlayerADartLabel
{
    playerADartLabel = [[UILabel alloc] initWithFrame:CGRectMake(468.0f, 260.0f, 100.0f, 30.0f)];
    playerADartLabel.transform = CGAffineTransformMakeRotation(M_PI_2 * 2);
    playerADartLabel.text = @"Darts: 3";
    playerADartLabel.textAlignment = NSTextAlignmentCenter;
    playerADartLabel.font = [UIFont fontWithName:@"Arial-BoldMT" size:16];
    playerADartLabel.backgroundColor = [UIColor clearColor];
    playerADartLabel.textColor = [UIColor blueColor];
    [self addSubview: playerADartLabel];
}

- (void) initPlayerBScoreLabel
{
    playerBScoreLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, 290.0f, 100.0f, 30.0f)];
    playerBScoreLabel.transform = CGAffineTransformMakeRotation(M_PI_2 * 2);
    playerBScoreLabel.text = @"Score: 0";
    playerBScoreLabel.textAlignment = NSTextAlignmentCenter;
    playerBScoreLabel.font = [UIFont fontWithName:@"Arial-BoldMT" size:16];
    playerBScoreLabel.backgroundColor = [UIColor clearColor];
    playerBScoreLabel.textColor = [UIColor redColor];
    [self addSubview:playerBScoreLabel];
}

- (void) initPlayerAScoreLabel
{
    playerAScoreLabel = [[UILabel alloc] initWithFrame:CGRectMake(468.0f, 290.0f, 100.0f, 30.0f)];
    playerAScoreLabel.transform = CGAffineTransformMakeRotation(M_PI_2 * 2);
    playerAScoreLabel.text = @"Score: 0";
    playerAScoreLabel.textAlignment = NSTextAlignmentCenter;
    playerAScoreLabel.font = [UIFont fontWithName:@"Arial-BoldMT" size:16];
    playerAScoreLabel.backgroundColor = [UIColor clearColor];
    playerAScoreLabel.textColor = [UIColor blueColor];
    [self addSubview:playerAScoreLabel];
}

- (void) initStatusLabel
{
    statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(134.0f, 0.0f, 300.0f, 30.0f)];
    statusLabel.transform = CGAffineTransformMakeRotation(M_PI_2 * 2);
    statusLabel.text = @"STATUS";
    statusLabel.textAlignment = NSTextAlignmentCenter;
    statusLabel.font = [UIFont fontWithName:@"Arial-BoldMT" size:16];
    statusLabel.backgroundColor = [UIColor clearColor];
    statusLabel.textColor = [UIColor greenColor];
    [self addSubview:statusLabel];
}

- (void) setLabel: (UILabel *) label toText: (NSString *) text
{
    dispatch_async(dispatch_get_main_queue(), ^{
        label.text = text;
    });
}

- (void) printMatrix: (QCAR::Matrix44F) m
{
    NSLog(@"%f %f %f %f", m.data[0], m.data[1], m.data[2], m.data[3]);
    NSLog(@"%f %f %f %f", m.data[4], m.data[5], m.data[6], m.data[7]);
    NSLog(@"%f %f %f %f", m.data[8], m.data[9], m.data[10], m.data[11]);
    NSLog(@"%f %f %f %f", m.data[12], m.data[13], m.data[14], m.data[15]);
}

- (QCAR::Vec2F)projectPoint: (QCAR::Vec2F)point
{
    //define temporary variables for the plane coordinates
    QCAR::Vec3F intersection, lineStart, lineEnd;
    //project sreen points onto the plane
    projectScreenPointToPlane(point, QCAR::Vec3F(0, 0, 0), QCAR::Vec3F(0, 0, 1), intersection, lineStart, lineEnd);
    return QCAR::Vec2F(intersection.data[0], intersection.data[1]);
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

- (NSString *)getScoreTextBasedOnArea: (int)area andNumber: (int) number
{
    NSString *score;
    
    if(area == NUMBER_AREA || area == NOT_ON_BOARD){
        score = @"Fail";
    }
    else if(area == INNER_AREA || area == OUTER_AREA){
        score = [NSString stringWithFormat:@"Single %i", number];
    }
    else if(area == DOUBLE_RING){
        score = [NSString stringWithFormat:@"Double %i", number];
    }
    else if(area == TRIPLE_RING){
        score = [NSString stringWithFormat:@"Triple %i", number];
    }
    else if(area == OUTER_BULL){
        score = [NSString stringWithFormat:@"Outer Bull"];
    }
    else if(area == INNER_BULL){
        score = [NSString stringWithFormat:@"Bull's Eye"];
    }
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

- (float)computeDistanceToTarget:(QCAR::Matrix34F)pose {
    QCAR::Vec3F position(pose.data[3], pose.data[7], pose.data[11]);
    return sqrt(    position.data[0] * position.data[0] +
                    position.data[1] * position.data[1] +
                    position.data[2] * position.data[2]);
}

- (QCAR::Matrix44F)computeCameraPosition:(QCAR::Matrix44F)modelViewMatrix {
    QCAR::Matrix44F inverseMV = SampleMath::Matrix44FInverse(modelViewMatrix);
    return SampleMath::Matrix44FTranspose(inverseMV);
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
    glScalef(0.5f, 0.5f, 0.5f);
    glRotatef(90.0f, 1.0f, 0.0f, 0.0f);
    glVertexPointer(3, GL_FLOAT, 0, dartboardVerts);
    glNormalPointer(GL_FLOAT, 0, dartboardNormals);
    glTexCoordPointer(2, GL_FLOAT, 0, dartboardTexCoords);
    glDrawArrays(GL_TRIANGLES, 0, dartboardNumVerts);
    glPopMatrix();
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
