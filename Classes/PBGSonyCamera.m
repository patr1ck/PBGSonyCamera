//
//  PBGSonyCamera.m
//
//  Created by Patrick B. Gibson on 12/3/13.
//

#import "PBGSonyCamera.h"

#import <AFNetworking/AFNetworking.h>
#import "AsyncUdpSocket.h"


@interface PBGSonyCamera () <NSURLConnectionDelegate, NSURLConnectionDataDelegate>
@property (nonatomic, strong) NSString *findCamerasString;
@property (nonatomic, strong) AsyncUdpSocket *ssdpSock;
@property (nonatomic, strong) NSString *apiEndpoint;

// startRecMod
@property (nonatomic, assign) BOOL recModeStarted;

// startLiveView
@property (nonatomic, copy) PBGSonyCameraLiveViewCallback liveViewCallback;
@property (nonatomic, strong) NSString *livefeedURL;
@property (nonatomic, strong) NSURLConnection *livefeedConnection;

@property (nonatomic, strong) NSMutableData *photoData;
@property (nonatomic, assign) NSUInteger bytesRemaining;
@property (nonatomic, assign) NSUInteger paddingSize;

@end


@implementation PBGSonyCamera

- (id)init
{
    self = [super init];
    if (self) {
        self.recModeStarted = NO;
        self.apiEndpoint = @"http://192.168.122.1:8080/sony/camera";
    }
    return self;
}

#pragma mark Methods for finding the camera via SSDP (Disabled)

/*
 Ideally these methods would be used to find the camera via SSDP and then read the appropriate
 endpoint from the SSDP XML. Currently they aren't being used because the camera is always at 
 the same IP and has the same endpoint, making the SSDP search needlessly complex and slow, 
 at least until Sony updates or otherwise changes the behavior of their cameras/Smart Remote
 Control apps.
 
 
 */

- (void)searchNetworkForCamera
{
    self.findCamerasString = @"M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: \"ssdp:discover\"\r\nMX: 1\r\nST: urn:schemas-sony-com:service:ScalarWebAPI:1\r\n\r\n";
    self.ssdpSock = [[AsyncUdpSocket alloc] initWithDelegate:self];
    
    NSError *socketError = nil;
    
    if (![_ssdpSock bindToPort:0 error:&socketError]) {
        NSLog(@"Failed binding socket: %@", [socketError localizedDescription]);
    }
    
    if(![_ssdpSock joinMulticastGroup:@"239.255.255.250" error:&socketError]){
        NSLog(@"Failed joining multicast group: %@", [socketError localizedDescription]);
    }
    
    if (![_ssdpSock enableBroadcast:TRUE error:&socketError]){
        NSLog(@"Failed enabling broadcast: %@", [socketError localizedDescription]);
    }
    
    [_ssdpSock sendData:[self.findCamerasString dataUsingEncoding:NSUTF8StringEncoding]
                 toHost:@"239.255.255.250"
                   port:1900
            withTimeout:10
                    tag:1];

    [_ssdpSock receiveWithTimeout:10 tag:2];
    [NSTimer scheduledTimerWithTimeInterval:11
                                     target:self
                                   selector:@selector(completeSearch:)
                                   userInfo:self
                                    repeats:NO];
    
    [_ssdpSock closeAfterSendingAndReceiving];
}

- (void)completeSearch:(NSTimer *)t
{
    NSLog(@"Search Time Ended.");
    [self.ssdpSock close];
    self.ssdpSock = nil;
}

- (BOOL)onUdpSocket:(AsyncUdpSocket *)sock
     didReceiveData:(NSData *)data
            withTag:(long)tag
           fromHost:(NSString *)host
               port:(UInt16)port
{
    NSString *rxString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"rxString: %@", rxString);
    
    NSArray *headers = [rxString componentsSeparatedByString:@"\n"];
    NSString *cameraURL = nil;
    
    for (NSString *header in headers) {
        NSArray *headerComponents = [header componentsSeparatedByString:@" "];
        if ([[headerComponents firstObject] isEqualToString:@"LOCATION:"]) {
            cameraURL = [headerComponents lastObject];
        }
    }
    
    cameraURL = [cameraURL stringByReplacingOccurrencesOfString:@"\r" withString:@""];
    NSLog(@"Camera URL: %@", cameraURL);
    
    [self fetchAPIEndpointForCameraURL:cameraURL];
    
    return YES;
}

- (void)fetchAPIEndpointForCameraURL:(NSString *)cameraURL
{
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    
    
    // Need a workaround for this since it's not available on iOS.
    //    manager.responseSerializer = [AFXMLDocumentResponseSerializer new];
    
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:cameraURL]];
    AFHTTPRequestOperation *op = [manager HTTPRequestOperationWithRequest:request
                                                                  success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                                                      NSLog(@"XML: %@", responseObject);
                                                                      
                                                                      self.apiEndpoint = @"http://192.168.122.1:8080/sony/camera";
                                                                      
                                                                  } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                                                      NSLog(@"Error: %@", error);
                                                                  }];
    [manager.operationQueue addOperation:op];
}


#pragma mark Public Methods

- (void)startRecMode
{
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    manager.responseSerializer = [AFJSONResponseSerializer new];
    
    NSMutableURLRequest *request = [[AFJSONRequestSerializer serializer] requestWithMethod:@"POST"
                                                                                 URLString:self.apiEndpoint
                                                                                parameters:@{@"method": @"startRecMode", @"params": @[], @"id":@1, @"version":@"1.0"}];
    
    AFHTTPRequestOperation *op = [manager HTTPRequestOperationWithRequest:request
                                                                  success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                                                      NSLog(@"Success: %@", responseObject);
                                                                      self.recModeStarted = YES;
                                                                  } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                                                      NSLog(@"Error: %@", error);
                                                                  }];
    [manager.operationQueue addOperation:op];
}


- (void)startLiveViewWithImageCallback:(PBGSonyCameraLiveViewCallback)liveViewCallback;
{    
    NSMutableURLRequest *request = [[AFJSONRequestSerializer serializer] requestWithMethod:@"POST"
                                                                                 URLString:self.apiEndpoint
                                                                                parameters:@{@"method": @"startLiveview", @"params": @[], @"id":@1, @"version":@"1.0"}];
    
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    AFHTTPRequestOperation *op = [manager HTTPRequestOperationWithRequest:request success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        NSLog(@"Success: %@", responseObject);
        self.livefeedURL = [[responseObject objectForKey:@"result"] firstObject];
        NSURLRequest *livefeedRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:self.livefeedURL]];
        self.photoData = [NSMutableData dataWithCapacity:1000];
        self.livefeedConnection = [[NSURLConnection alloc] initWithRequest:livefeedRequest delegate:self startImmediately:YES];
        self.liveViewCallback = liveViewCallback;
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
    }];
    
    [manager.operationQueue addOperation:op];
}

- (void)stopLiveView;
{
    [self.livefeedConnection cancel];
    self.liveViewCallback = nil;
    self.photoData = nil;
    self.livefeedConnection = nil;
}

- (void)takePicture;
{
    NSMutableURLRequest *request = [[AFJSONRequestSerializer serializer] requestWithMethod:@"POST"
                                                                                 URLString:self.apiEndpoint
                                                                                parameters:@{@"method": @"actTakePicture", @"params": @[], @"id":@1, @"version":@"1.0"}];
    
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    AFHTTPRequestOperation *op = [manager HTTPRequestOperationWithRequest:request success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        NSLog(@"Success: %@", responseObject);
        NSArray *imageURLs = [[responseObject objectForKey:@"result"] firstObject];
        NSLog(@"Image url: %@", [imageURLs firstObject]);
        [self saveImageAtURL:[imageURLs firstObject]];
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
    }];
    
    [manager.operationQueue addOperation:op];
}

- (void)setCaptureImageSize:(PBGSonyCameraCaptureSize)size;
{
    NSString *captureSize;
    
    switch (size) {
        case PBGSonyCameraCaptureSize2M:
            captureSize = @"2M";
            break;
        case PBGSonyCameraCaptureSizeOriginal:
            captureSize = @"Original";
            break;
        default:
            break;
    }
    
    NSMutableURLRequest *request = [[AFJSONRequestSerializer serializer] requestWithMethod:@"POST"
                                                                                 URLString:self.apiEndpoint
                                                                                parameters:@{@"method": @"setPostviewImageSize", @"params": @[captureSize], @"id":@1, @"version":@"1.0"}];
    
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    AFHTTPRequestOperation *op = [manager HTTPRequestOperationWithRequest:request success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSLog(@"Success for setPostview: %@", responseObject);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
    }];
    
    [manager.operationQueue addOperation:op];
}

#pragma mark NSURLConnectionDelegate (For Liveview Images)

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data;
{
    uint8_t buffer[1];
    [data getBytes:buffer range:NSMakeRange(0, 1)];
    NSInteger startByte = (uint8_t) buffer[0];
    BOOL removeHeaderBytes = NO;
    
    uint8_t payload[1];
    [data getBytes:payload range:NSMakeRange(1, 1)];
    NSInteger payloadInt = (uint8_t) payload[0];
    
    
    if (payloadInt == 1 && startByte == 255) {
        removeHeaderBytes = YES;
        
        uint8_t playloadHeader[4];
        [data getBytes:playloadHeader range:NSMakeRange(8, 4)];
        
        if ((playloadHeader[0] == 0x24 && playloadHeader[1] == 0x35) && (playloadHeader[2] == 0x68 && playloadHeader[3] == 0x79)) {
            uint8_t photoSize[4];
            [data getBytes:photoSize range:NSMakeRange(8 + 4, 3)];
            uint32_t photoSizeInt = OSReadLittleInt16(photoSize, 0);
            self.bytesRemaining = photoSizeInt;
            
            uint8_t paddingSize[1];
            [data getBytes:paddingSize range:NSMakeRange(8 + 4 + 3, 1)];
            uint32_t paddingSizeInt = OSReadLittleInt16(paddingSize, 0);
            self.paddingSize = paddingSizeInt;
        } else {
            removeHeaderBytes = NO;
        }
    }
    
    NSUInteger sizeOfData = 0;
    NSUInteger bytesToRead = 0;
    
    if (removeHeaderBytes) {
        sizeOfData = [data length] - 128 - 8;
    } else {
        sizeOfData = [data length];
    }
    
    bytesToRead = MIN(sizeOfData, self.bytesRemaining);
    bytesToRead = sizeOfData;
    
    uint8_t photoData[bytesToRead + 1];
    
    if (removeHeaderBytes) {
        [data getBytes:photoData range:NSMakeRange(8 + 128, bytesToRead)];
    } else {
        [data getBytes:photoData range:NSMakeRange(0, bytesToRead)];
    }
    [self.photoData appendBytes:photoData length:bytesToRead];
    
    self.bytesRemaining -= bytesToRead;
    
    if (self.bytesRemaining <= 0) {
        UIImage *image = [[UIImage alloc] initWithData:self.photoData];
        
        self.liveViewCallback(image);
        self.photoData = [NSMutableData dataWithCapacity:1000];
    }
}


#pragma mark Helper Methods

- (void)saveImageAtURL:(NSString *)imageURL
{
    NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:imageURL]];
    AFHTTPRequestOperation *postOperation = [[AFHTTPRequestOperation alloc] initWithRequest:urlRequest];
    postOperation.responseSerializer = [AFImageResponseSerializer serializer];
    [postOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, UIImage *responseObject) {
        dispatch_async(dispatch_get_main_queue(), ^{
            
            NSLog(@"Saving image: %@", responseObject);
            if (self.delegate && [self.delegate respondsToSelector:@selector(imageTaken:)]) {
                [self.delegate imageTaken:responseObject];
            }
        });
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Image error: %@", error);
    }];
    
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    [manager.operationQueue addOperation:postOperation];
}


@end
