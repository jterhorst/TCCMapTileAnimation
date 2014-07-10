//
//  TCCViewController.m
//  MapTileAnimation
//
//  Created by Bruce Johnson on 6/11/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//

#import "TCCMapViewController.h"
#import "TCCTimeFrameParser.h"
#import "MATAnimatedTileOverlayRenderer.h"
#import "MATAnimatedTileOverlay.h"
#import "MATAnimatedTileOverlayDelegate.h"

#import "MATTileOverlay.h"

#import "MKMapView+Extras.h"


//#define FUTURE_RADAR_FRAMES_URI "https://qa1-twi.climate.com/assets/wdt-future-radar/LKG.txt?grower_apps=true"
#define FUTURE_RADAR_FRAMES_URI "http://climate.com/assets/wdt-future-radar/LKG.txt?grower_apps=true"

@interface TCCMapViewController () <MKMapViewDelegate, MATAnimatedTileOverlayDelegate, TCCTimeFrameParserDelegateProtocol, UIAlertViewDelegate>

@property (nonatomic, readwrite, weak) IBOutlet MKMapView *mapView;
@property (weak, nonatomic) IBOutlet UILabel *timeIndexLabel;
@property (weak, nonatomic) IBOutlet UIProgressView *downloadProgressView;
@property (weak, nonatomic) IBOutlet UIButton *startStopButton;
@property (weak, nonatomic) IBOutlet UISlider *timeSlider;
@property(nonatomic) MKMapRect visibleMapRect;
@property (nonatomic, readwrite, strong) TCCTimeFrameParser *timeFrameParser;
@property (nonatomic) BOOL initialLoad;
@property (readwrite, weak) MKTileOverlayRenderer *tileOverlayRenderer;
@property (readwrite, weak) MATAnimatedTileOverlay *animatedTileOverlay;
@property (readwrite, weak) MATAnimatedTileOverlayRenderer *animatedTileRenderer;

@property (readwrite, assign) BOOL shouldStop;
@end

@implementation TCCMapViewController
{
	CGFloat _oldTimeSliderValue;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Set the starting  location.
    CLLocationCoordinate2D startingLocation = {40.2444, -111.6608};
//	MKCoordinateSpan span = {8.403266, 7.031250};
	MKCoordinateSpan span = {7.0, 7.0};
	//calling regionThatFits: is very important, this will line up the visible map rect with the screen aspect ratio
	//which is important for calculating the number of tiles, their coordinates and map rect frame
	MKCoordinateRegion region = [self.mapView regionThatFits: MKCoordinateRegionMake(startingLocation, span)];
	
	[self.mapView setRegion: region animated: NO];
	
	self.shouldStop = NO;
	self.startStopButton.tag = MATAnimatingStateStopped;
	_oldTimeSliderValue = 0.0f;
    self.downloadProgressView.hidden = NO;
    self.initialLoad = YES;
	
}

- (void) viewDidAppear:(BOOL)animated
{
	[super viewDidAppear: animated];
	self.timeFrameParser = [[TCCTimeFrameParser alloc] initWithURLString: @FUTURE_RADAR_FRAMES_URI delegate: self];

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (IBAction)onHandleTimeIndexChange:(id)sender
{
	CGFloat sliderVal = floorf(self.timeSlider.value);

	if (_oldTimeSliderValue != sliderVal) {
		if ([self.animatedTileOverlay updateToCurrentFrameIndex: (unsigned long)sliderVal]) {
			self.timeIndexLabel.text = [NSString stringWithFormat: @"%lu", (unsigned long)self.animatedTileOverlay.currentFrameIndex];
			[self.animatedTileRenderer setNeedsDisplayInMapRect: self.mapView.visibleMapRect zoomScale: self.animatedTileRenderer.zoomScale];
		};
		_oldTimeSliderValue = sliderVal;
	}
}

- (IBAction) onHandleStartStopAction: (id)sender
{
	if (self.startStopButton.tag == MATAnimatingStateStopped) {
		
		[self.tileOverlayRenderer setAlpha: 1.0];
		
        TCCMapViewController __weak *controller = self;
        
		//start downloading the image tiles for the time frame indexes

		[self.animatedTileOverlay fetchTilesForMapRect: self.mapView.visibleMapRect zoomScale: self.animatedTileRenderer.zoomScale progressBlock: ^(NSUInteger currentTimeIndex, BOOL *stop) {
			         
			CGFloat progressValue = (CGFloat)currentTimeIndex / (CGFloat)(self.animatedTileOverlay.numberOfAnimationFrames - 1);
			[controller.downloadProgressView setProgress: progressValue animated: YES];
            
            if(self.initialLoad == YES) {
                controller.timeSlider.value = (CGFloat)currentTimeIndex;
                controller.timeIndexLabel.text = [NSString stringWithFormat: @"%lu", (unsigned long)currentTimeIndex];
			}
            
			if (currentTimeIndex == 0) {
				[controller.tileOverlayRenderer setAlpha: 0.0];
				[controller.animatedTileRenderer setAlpha: 1.0];
			}
			
			[controller.animatedTileOverlay updateImageTilesToFrameIndex: currentTimeIndex];
            
			[controller.animatedTileRenderer setNeedsDisplayInMapRect: self.mapView.visibleMapRect zoomScale: self.animatedTileRenderer.zoomScale];
			*stop = controller.shouldStop;
			
			//if we cancelled loading, reset the sliders max value to what we currently have
			if (controller.shouldStop == YES) {
				controller.timeSlider.maximumValue = (CGFloat)currentTimeIndex;
			}
			
		} completionBlock: ^(BOOL success, NSError *error) {
			
            if(success == YES) {
                self.initialLoad = NO;
                self.downloadProgressView.hidden = YES;
            } else {
                self.downloadProgressView.hidden = NO;
            }
            
			[controller.downloadProgressView setProgress: 0.0];
			controller.animatedTileOverlay.currentFrameIndex = 0;

			if (success) {
				[controller.animatedTileOverlay updateImageTilesToFrameIndex: controller.animatedTileOverlay.currentFrameIndex];
				
				[controller.animatedTileRenderer setNeedsDisplayInMapRect: self.mapView.visibleMapRect zoomScale: self.animatedTileRenderer.zoomScale];
				[controller.animatedTileOverlay startAnimating];
			} else {
				
				controller.shouldStop = NO;
			}
		}];
	} else if (self.startStopButton.tag == MATAnimatingStateLoading) {
		self.shouldStop = YES;
	} else if (self.startStopButton.tag == MATAnimatingStateAnimating) {
		[self.animatedTileOverlay pauseAnimating];
	}
}

#pragma mark - TCCTimeFrameParserDelegate Protocol

- (void) didLoadTimeStampData;
{
	NSArray *templateURLs = self.timeFrameParser.templateFrameTimeURLs;
	MATAnimatedTileOverlay *overlay = [[MATAnimatedTileOverlay alloc] initWithTemplateURLs: templateURLs frameDuration: 0.10];
	overlay.delegate = self;
	
	MATTileOverlay *tileOverlay = [[MATTileOverlay alloc] initWithAnimationTileOverlay: overlay];
	
	[self.mapView addOverlays: @[tileOverlay, overlay] level: MKOverlayLevelAboveRoads];
	self.timeSlider.maximumValue = (CGFloat)templateURLs.count - 1;
}

#pragma mark - MATAnimatedTileOverlayDelegate Protocol

- (void)animatedTileOverlay:(MATAnimatedTileOverlay *)animatedTileOverlay didChangeAnimationState:(MATAnimatingState)currentAnimationState {
   
    self.startStopButton.tag = currentAnimationState;

    //set titles of button to appropriate string based on currentAnimationState
    if(currentAnimationState == MATAnimatingStateLoading) {
        [self.startStopButton setTitle: @"Cancel" forState: UIControlStateNormal];
        //check if user has panned (visibleRects different)
        if(!MKMapRectEqualToRect(self.visibleMapRect, self.mapView.visibleMapRect)) {
            self.downloadProgressView.hidden = NO;
            self.initialLoad = YES;
        }
        self.visibleMapRect = self.mapView.visibleMapRect;
    }
    else if(currentAnimationState == MATAnimatingStateStopped) {
        [self.startStopButton setTitle: @"Play" forState: UIControlStateNormal];

    }
    else if(currentAnimationState == MATAnimatingStateAnimating) {
        [self.startStopButton setTitle: @"Stop" forState: UIControlStateNormal];
    }
    
}

- (void)animatedTileOverlay:(MATAnimatedTileOverlay *)animatedTileOverlay didAnimateWithAnimationFrameIndex:(NSInteger)animationFrameIndex
{
	[self.animatedTileRenderer setNeedsDisplayInMapRect: self.mapView.visibleMapRect zoomScale: self.animatedTileRenderer.zoomScale];
	//update the slider if we are loading or animating
    self.timeIndexLabel.text = [NSString stringWithFormat: @"%lu", (unsigned long)animationFrameIndex];
 	if (animatedTileOverlay.currentAnimatingState != MATAnimatingStateStopped) {
		self.timeSlider.value = (CGFloat)animationFrameIndex;
	}
}

- (void)animatedTileOverlay:(MATAnimatedTileOverlay *)animatedTileOverlay didHaveError:(NSError *) error
{
	NSLog(@"%s ERROR %ld %@", __PRETTY_FUNCTION__, (long)error.code, error.localizedDescription);
	
	if (error.code == MATAnimatingErrorInvalidZoomLevel) {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle: @"Invalid Zoom Level"
														message: error.localizedDescription
													   delegate: self
											  cancelButtonTitle: @"Ok"
											  otherButtonTitles: nil, nil];
		[alert show];
	}
}


#pragma mark - MKMapViewDelegate Protocol

- (void)mapViewDidFinishRenderingMap:(MKMapView *)mapView fullyRendered:(BOOL)fullyRendered
{
	if (fullyRendered == YES) {


	}
}

- (void)mapView:(MKMapView *)mapView regionWillChangeAnimated:(BOOL)animated
{
	if (self.startStopButton.tag != 0) {
		[self.animatedTileOverlay pauseAnimating];
	}

	[self.tileOverlayRenderer setAlpha: 1.0];
	[self.animatedTileRenderer setAlpha: 0.0];

}

- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated
{
	if (animated == NO) {
		
	}
}

- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay
{
	if ([overlay isKindOfClass: [MATTileOverlay class]]) {
		MKTileOverlayRenderer *renderer = [[MKTileOverlayRenderer alloc] initWithTileOverlay: (MKTileOverlay *)overlay];
		self.tileOverlayRenderer = renderer;
		return self.tileOverlayRenderer;
	} else if ([overlay isKindOfClass: [MATAnimatedTileOverlay class]]) {
		self.animatedTileOverlay = (MATAnimatedTileOverlay *)overlay;
		MATAnimatedTileOverlayRenderer *renderer = [[MATAnimatedTileOverlayRenderer alloc] initWithOverlay: overlay];
		self.animatedTileRenderer = renderer;

		return self.animatedTileRenderer;
	}
	return nil;
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	MKCoordinateRegion region = self.mapView.region;
}


@end
