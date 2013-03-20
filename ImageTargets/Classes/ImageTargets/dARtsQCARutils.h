/*==============================================================================
            Copyright (c) 2010-2012 QUALCOMM Austria Research Center GmbH.
            All Rights Reserved.
            Qualcomm Confidential and Proprietary
==============================================================================*/

#import "QCARutils.h"

typedef enum {
    DeviceOrientationLockPortrait,
    DeviceOrientationLockLandscape,
    DeviceOrientationLockAuto
} DeviceOrientationLock;

@interface dARtsQCARutils : QCARutils
{
    DeviceOrientationLock deviceOrientationLock;
}

@property (assign) DeviceOrientationLock deviceOrientationLock;

+ (dARtsQCARutils *) getInstance;

//  Autorotation
- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;
- (NSUInteger) supportedInterfaceOrientations;
- (BOOL) shouldAutorotate;
@end
