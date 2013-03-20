/*==============================================================================
 Copyright (c) 2010-2012 QUALCOMM Austria Research Center GmbH.
 All Rights Reserved.
 Qualcomm Confidential and Proprietary
 ==============================================================================*/

#import <UIKit/UIKit.h>

@interface AboutViewController : UIViewController <UIWebViewDelegate>
{
    IBOutlet UIWebView *webView;
}

- (IBAction)startButtonTapped:(id)sender;

@end
