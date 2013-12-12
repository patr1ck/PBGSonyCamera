//
//  PBGSonyCamera.h
//
//  Created by Patrick B. Gibson on 12/3/13.
//

#import <Foundation/Foundation.h>

@class PBGSonyCamera;

// Delegate method for recieving the captured image. This will be called after the camera takes a photo.
@protocol PBGSonyCameraDelegate <NSObject>
@optional
- (void)imageTaken:(UIImage *)image;
@end

// Live view callback. This will be called serveral times a second with the current liveview image.
typedef void (^PBGSonyCameraLiveViewCallback)(UIImage *liveViewImage);

// Caputer image sizes
typedef NS_ENUM(NSInteger, PBGSonyCameraCaptureSize) {
    PBGSonyCameraCaptureSizeOriginal,
    PBGSonyCameraCaptureSize2M
};

@interface PBGSonyCamera : NSObject

@property (nonatomic, readonly) BOOL recModeStarted;
@property (nonatomic, weak) id<PBGSonyCameraDelegate> delegate;

// The camera needs to be put into "record mode" before doing many things.
- (void)startRecMode;

- (void)startLiveViewWithImageCallback:(PBGSonyCameraLiveViewCallback)liveViewCallback;
- (void)stopLiveView;

- (void)setCaptureImageSize:(PBGSonyCameraCaptureSize)size;

- (void)takePicture;

@end
