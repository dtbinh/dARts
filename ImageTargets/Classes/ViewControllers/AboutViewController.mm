/*==============================================================================
 Copyright (c) 2010-2012 QUALCOMM Austria Research Center GmbH.
 All Rights Reserved.
 Qualcomm Confidential and Proprietary
 ==============================================================================*/

#import "AboutViewController.h"
#import "dARtsQCARutils.h"

@implementation AboutViewController

#pragma mark - Private

- (void)loadWebView
{
    //  Load html from a local file for the about screen
    NSString *aboutFilePath = [[NSBundle mainBundle] pathForResource:@"about"
                                                              ofType:@"html"];
    
    NSString* htmlString = [NSString stringWithContentsOfFile:aboutFilePath
                                                     encoding:NSUTF8StringEncoding
                                                        error:nil];
    
    NSString *aPath = [[NSBundle mainBundle] bundlePath];
    NSURL *anURL = [NSURL fileURLWithPath:aPath];
    webView.scrollView.scrollEnabled = NO;
    webView.scrollView.bounces = NO;
    [webView loadHTMLString:htmlString baseURL:anURL];
}

#pragma mark - Public

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self loadWebView];
}

- (void)viewDidUnload
{
    [webView release];
    webView = nil;
    [super viewDidUnload];
}

//  Deprecated on iOS 6. Use the two methods below to control autorotation
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    dARtsQCARutils *utils = [dARtsQCARutils getInstance];
    BOOL retVal = [utils shouldAutorotateToInterfaceOrientation:interfaceOrientation];
    
    return retVal;
}

- (NSUInteger)supportedInterfaceOrientations
{
    NSUInteger retVal = [[dARtsQCARutils getInstance] supportedInterfaceOrientations];
    return retVal;
}

- (BOOL)shouldAutorotate
{
    BOOL retVal = [[dARtsQCARutils getInstance] shouldAutorotate];
    return retVal;
}

- (void)dealloc
{
    [webView release];
    [super dealloc];
}

- (IBAction)startButtonTapped:(id)sender
{
    [self dismissModalViewControllerAnimated:YES];
}

#pragma mark - UIWebViewDelegate

-(BOOL) webView:(UIWebView *)inWeb shouldStartLoadWithRequest:(NSURLRequest *)inRequest navigationType:(UIWebViewNavigationType)inType
{
    //  Opens the links within this UIWebView on a safari web browser
    
    BOOL retVal = NO;
    
    if ( inType == UIWebViewNavigationTypeLinkClicked )
    {
        [[UIApplication sharedApplication] openURL:[inRequest URL]];
    }
    else
    {
        retVal = YES;
    }
    
    return retVal;
}
@end
