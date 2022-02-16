//
//  HNYNetworkReachabilityManager.m
//  HNYNetworkReachabilityManager
//
//  Created by Young on 2022/2/15.
//

#import "HNYNetworkReachabilityManager.h"
#import <netinet/in.h>
#import <netinet6/in6.h>
#import <arpa/inet.h>
#import <ifaddrs.h>
#import <netdb.h>

NSString * const HNYNetworkReachabilityDidChangeNotification = @"HNYNetworkReachabilityDidChangeNotification";
NSString * const HNYNetworkReachabilityNotificationStatusItem = @"HNYNetworkReachabilityNotificationStatusItem";

typedef void (^HNYNetworkReachabilityStatusBlock)(HNYNetworkReachabilityStatus status);
typedef HNYNetworkReachabilityManager * (^HNYNetworkReachabilityStatusCallback)(HNYNetworkReachabilityStatus status);

static HNYNetworkReachabilityStatus HNYNetworkReachabilityStatusForFlags(SCNetworkReachabilityFlags flags) {
    BOOL isReachable = ((flags & kSCNetworkReachabilityFlagsReachable) != 0);
    BOOL needsConnection = ((flags & kSCNetworkReachabilityFlagsConnectionRequired) != 0);
    BOOL canConnectionAutomatically = (((flags & kSCNetworkReachabilityFlagsConnectionOnDemand ) != 0) || ((flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0));
    BOOL canConnectWithoutUserInteraction = (canConnectionAutomatically && (flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0);
    BOOL isNetworkReachable = (isReachable && (!needsConnection || canConnectWithoutUserInteraction));
    
    HNYNetworkReachabilityStatus status = HNYNetworkReachabilityStatusUnknown;
    if (isNetworkReachable == NO) {
        status = HNYNetworkReachabilityStatusNotReachable;
    }
#if TARGET_OS_IPHONE
    else if ((flags & kSCNetworkReachabilityFlagsIsWWAN) != 0) {
        status = HNYNetworkReachabilityStatusReachableViaWWAN;
    }
#endif
    else {
        status = HNYNetworkReachabilityStatusReachableViaWiFi;
    }
    
    return status;
}

/**
 * Queue a status change notification for the main thread.
 *
 * This is done to ensure that the notifications are received in the same order
 * as they are sent. If notifications are sent directly, it is possible that
 * a queued notification (for an earlier status condition) is processed after
 * the later update, resulting in the listener being left in the wrong state.
 */
static void HNYPostReachabilityStatusChange(SCNetworkReachabilityFlags flags, HNYNetworkReachabilityStatusCallback block) {
    HNYNetworkReachabilityStatus status = HNYNetworkReachabilityStatusForFlags(flags);
    dispatch_async(dispatch_get_main_queue(), ^{
        HNYNetworkReachabilityManager *manager = nil;
        if (block) {
            manager = block(status);
        }
        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
        NSDictionary *userInfo = @{HNYNetworkReachabilityNotificationStatusItem: @(status)};
        [notificationCenter postNotificationName:HNYNetworkReachabilityDidChangeNotification object:manager userInfo:userInfo];
    });
}

static void HNYNetworkReachabilityCallback(SCNetworkReachabilityRef __unused target, SCNetworkReachabilityFlags flags, void *info) {
    HNYPostReachabilityStatusChange(flags, (__bridge HNYNetworkReachabilityStatusCallback)info);
}


static const void * HNYNetworkReachabilityRetainCallback(const void *info) {
    return Block_copy(info);
}

static void HNYNetworkReachabilityReleaseCallback(const void *info) {
    if (info) {
        Block_release(info);
    }
}

@interface HNYNetworkReachabilityManager ()
@property (nonatomic, readonly, assign) SCNetworkReachabilityRef networkReachability;
@property (nonatomic, readwrite, assign) HNYNetworkReachabilityStatus networkReachabilityStatus;
@property (nonatomic, readwrite, copy) HNYNetworkReachabilityStatusBlock networkReachabilityStatusBlock;
@end

@implementation HNYNetworkReachabilityManager

+ (instancetype)sharedManager {
    static HNYNetworkReachabilityManager *_sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedManager = [self manager];
    });
    
    return _sharedManager;
}

+ (instancetype)managerForDomain:(NSString *)domain {
    SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithName(kCFAllocatorDefault, [domain UTF8String]);
    HNYNetworkReachabilityManager *manager = [[self alloc] initWithReachability:reachability];
    CFRelease(reachability);
    
    return manager;
}

+ (instancetype)managerForAddress:(const void *)address {
    SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr *)address);
    HNYNetworkReachabilityManager *manager = [[self alloc] initWithReachability:reachability];
    CFRelease(reachability);
    
    return manager;
}

+ (instancetype)manager {
#if (defined(__IPHONE_OS_VERSION_MIN_REQUIRED) && __IPHONE_OS_VERSION_MIN_REQUIRED >= 90000) || (defined(__MAC_OS_X_VERSION_MIN_REQUIRED) && __MAC_OS_X_VERSION_MIN_REQUIRED >= 101100)
    struct sockaddr_in6 address;
    bzero(&address, sizeof(address));
    address.sin6_len = sizeof(address);
    address.sin6_family = AF_INET6;
#else
    struct sockaddr_in address;
    bzero(&address, sizeof(address));
    address.sin_len = sizeof(address);
    address.sin_family = AF_INET;
#endif
    return [self managerForAddress:&address];
}

- (instancetype)initWithReachability:(SCNetworkReachabilityRef)reachability {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    _networkReachability = CFRetain(reachability);
    self.networkReachabilityStatus = HNYNetworkReachabilityStatusUnknown;
    
    return self;
}

- (instancetype)init {
    @throw [NSException exceptionWithName:NSGenericException
                                   reason:@"`-init` unavailable. Use `-initWithReachability:` instead"
                                 userInfo:nil];
    return nil;
}

- (void)dealloc {
    [self stopMonitoring];
    
    if (_networkReachability != NULL) {
        CFRelease(_networkReachability);
    }
}

#pragma mark -

- (BOOL)isReachable {
    return [self isReachableViaWWAN] || [self isReachableViaWiFi];
}

- (BOOL)isReachableViaWWAN {
    return self.networkReachabilityStatus == HNYNetworkReachabilityStatusReachableViaWWAN;
}

- (BOOL)isReachableViaWiFi {
    return self.networkReachabilityStatus == HNYNetworkReachabilityStatusReachableViaWiFi;
}

#pragma mark -

- (void)startMonitoring {
    [self stopMonitoring];
    
    if (!self.networkReachability) {
        return;
    }
    
    __weak __typeof(self)weakSelf = self;
    HNYNetworkReachabilityStatusCallback callback = ^(HNYNetworkReachabilityStatus status) {
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        
        strongSelf.networkReachabilityStatus = status;
        if (strongSelf.networkReachabilityStatusBlock) {
            strongSelf.networkReachabilityStatusBlock(status);
        }
        
        return strongSelf;
    };
    
    SCNetworkReachabilityContext context = {0, (__bridge void *)callback, HNYNetworkReachabilityRetainCallback, HNYNetworkReachabilityReleaseCallback, NULL};
    SCNetworkReachabilitySetCallback(self.networkReachability, HNYNetworkReachabilityCallback, &context);
    SCNetworkReachabilityScheduleWithRunLoop(self.networkReachability, CFRunLoopGetMain(), kCFRunLoopCommonModes);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),^{
        SCNetworkReachabilityFlags flags;
        if (SCNetworkReachabilityGetFlags(self.networkReachability, &flags)) {
            HNYPostReachabilityStatusChange(flags, callback);
        }
    });
}

- (void)stopMonitoring {
    if (!self.networkReachability) {
        return;
    }
    
    SCNetworkReachabilityUnscheduleFromRunLoop(self.networkReachability, CFRunLoopGetMain(), kCFRunLoopCommonModes);
}

#pragma mark -

- (void)setReachabilityStatusChangeBlock:(void (^)(HNYNetworkReachabilityStatus status))block {
    self.networkReachabilityStatusBlock = block;
}

#pragma mark - NSKeyValueObserving

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
    if ([key isEqualToString:@"reachable"] || [key isEqualToString:@"reachableViaWWAN"] || [key isEqualToString:@"reachableViaWiFi"]) {
        return [NSSet setWithObject:@"networkReachabilityStatus"];
    }
    
    return [super keyPathsForValuesAffectingValueForKey:key];
}

@end
