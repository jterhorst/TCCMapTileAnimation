//
//  TCCTileOverlayHelpers.m
//  MapTileAnimationDemo
//
//  Created by Matthew Sniff on 7/23/14.
//  Copyright (c) 2014 The Climate Corporation. All rights reserved.
//

#import "TCCTileOverlayHelpers.h"

@implementation TCCTileOverlayHelpers

/**
 * Similar to above, but uses a MKZoomScale to determine the
 * Mercator zoomLevel. (MKZoomScale is a ratio of screen points to
 * map points.)
 */
+ (NSUInteger)zoomLevelForZoomScale:(MKZoomScale)zoomScale
{
    CGFloat realScale = zoomScale / [[UIScreen mainScreen] scale];
    NSUInteger z = (NSUInteger)(log(realScale)/log(2.0)+20.0);
	
    z += ([[UIScreen mainScreen] scale] - 1.0);
    return z;
}

+ (TCCTileCoordinate)tileCoordinateForMapRect:(MKMapRect)aMapRect zoomLevel:(NSInteger)zoomLevel
{
    CGPoint mercatorPoint = [self mercatorTileOriginForMapRect:aMapRect];
    NSUInteger tilex = floor(mercatorPoint.x * [self worldTileWidthForZoomLevel:zoomLevel]);
    NSUInteger tiley = floor(mercatorPoint.y * [self worldTileWidthForZoomLevel:zoomLevel]);
    return (TCCTileCoordinate){tilex, tiley, zoomLevel};
}

+ (MKMapRect)mapRectForTileCoordinate:(TCCTileCoordinate)coordinate
{
    CGFloat xScale = (double)coordinate.x / [self worldTileWidthForZoomLevel:coordinate.z];
    CGFloat yScale = (double)coordinate.y / [self worldTileWidthForZoomLevel:coordinate.z];
    MKMapRect world = MKMapRectWorld;
    return MKMapRectMake(world.size.width * xScale,
                         world.size.height * yScale,
                         world.size.width / [self worldTileWidthForZoomLevel:coordinate.z],
                         world.size.height / [self worldTileWidthForZoomLevel:coordinate.z]);
}

/*
 Determine the number of tiles wide *or tall* the world is, at the given zoomLevel.
 (In the Spherical Mercator projection, the poles are cut off so that the resulting 2D map is "square".)
 */
+ (NSUInteger)worldTileWidthForZoomLevel:(NSUInteger)zoomLevel
{
    return (NSUInteger)(pow(2,zoomLevel));
}

/**
 * Given a MKMapRect, this reprojects the center of the mapRect
 * into the Mercator projection and calculates the rect's top-left point
 * (so that we can later figure out the tile coordinate).
 *
 * See http://wiki.openstreetmap.org/wiki/Slippy_map_tilenames#Derivation_of_tile_names
 */
+ (CGPoint)mercatorTileOriginForMapRect:(MKMapRect)mapRect
{
    MKCoordinateRegion region = MKCoordinateRegionForMapRect(mapRect);
    
    // Convert lat/lon to radians
    CGFloat x = (region.center.longitude) * (M_PI/180.0); // Convert lon to radians
    CGFloat y = (region.center.latitude) * (M_PI/180.0); // Convert lat to radians
    y = log(tan(y)+1.0/cos(y));
    
    // X and Y should actually be the top-left of the rect (the values above represent
    // the center of the rect)
    x = (1.0 + (x/M_PI)) / 2.0;
    y = (1.0 - (y/M_PI)) / 2.0;
	
    return CGPointMake(x, y);
}

@end