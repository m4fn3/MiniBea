#import "Tweak.h"

%hook PAGDeviceHelper
+ (BOOL)bu_isJailBroken {
	return NO;
}
%end

%hook STKDevice
+ (BOOL)containsJailbrokenFiles {
	return NO;
}

+ (BOOL)containsJailbrokenPermissions {
	return NO;
}

+ (BOOL)isJailbroken {
	return NO;
}
%end

%hook HomeViewController
- (void)viewDidLoad {
	%orig;

	UIStackView *stackView = (UIStackView *)[[self ibNavBarLogoImageView] superview];
	stackView.axis = UILayoutConstraintAxisHorizontal;
	stackView.alignment = UIStackViewAlignmentCenter;
	
	UIImageView *plusImage = [[UIImageView alloc] init];
	plusImage.image = [UIImage systemImageNamed:@"plus.app"];
	plusImage.translatesAutoresizingMaskIntoConstraints = NO;

	[stackView addArrangedSubview:plusImage];

	UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
	[stackView addGestureRecognizer:tapGestureRecognizer];
	[stackView setUserInteractionEnabled:YES];
}

%new
- (void)handleTap:(UITapGestureRecognizer *)gestureRecognizer {
	if (![[BeaTokenManager sharedInstance] BRAccessToken]) return;

	BeaUploadViewController *beaUploadViewController = [[BeaUploadViewController alloc] init];
	beaUploadViewController.modalPresentationStyle = UIModalPresentationFullScreen;
	[self presentViewController:beaUploadViewController animated:YES completion:nil];
}
%end

%hook NSMutableURLRequest
-(void)setAllHTTPHeaderFields:(NSDictionary *)arg1 {
	%orig;

	if ([[arg1 allKeys] containsObject:@"Authorization"] && [[arg1 allKeys] containsObject:@"bereal-device-id"] && !headers) {
		if ([arg1[@"Authorization"] length] > 0) {
			headers = (NSDictionary *)arg1;
			[[BeaTokenManager sharedInstance] setHeaders:headers];
		}
	} 
}
%end

%hook CAFilter
-(void)setValue:(id)arg1 forKey:(id)arg2 {
    // remove the blur that gets applied to the BeReals
	// this is kind of a fallback if the normal unblur function somehow fails (BeReal 2.0+)

	if (([arg1 isEqual:@(13)] || [arg1 isEqual:@(8)]) && [self.name isEqual:@"gaussianBlur"]) {
		return %orig(0, arg2);
	}
    %orig;
}
%end

%hook MediaView
%property (nonatomic, strong) BeaButton *downloadButton;

- (void)drawRect:(CGRect)rect {
	%orig;

	// Check if we need to remove subviews other than the main image (to keep the reaction&comment button)
	// 1. Not posted yet & 2. Not tagged in that post (especially to keep the reshare button)
	if ([NSStringFromClass([[self subviews].lastObject class]) isEqualToString:@"_TtCOCV7SwiftUI11DisplayList11ViewUpdater8Platform13CGDrawingView"] && [[self subviews] count] > 5) { 
		for (int i = 1; i < [[self subviews] count]; i++) {
			[[self subviews][i] setHidden:YES];
		}
	}

	// Every time we swich images it resets the user interaction stat, so we set the identifier and track it in the hook
	[self subviews][0].accessibilityIdentifier = @"Beaw";

	BeaButton *downloadButton = [BeaButton downloadButton];
	downloadButton.layer.zPosition = 99;

    [self setDownloadButton:downloadButton];
    [self addSubview:downloadButton];

	[NSLayoutConstraint activateConstraints:@[
		[[[self downloadButton] trailingAnchor] constraintEqualToAnchor:[self trailingAnchor] constant:-11.6],
		[[[self downloadButton] bottomAnchor] constraintEqualToAnchor:[self topAnchor] constant:47.333]
	]];
}
%end

%hook DoubleMediaView
- (BOOL)isUserInteractionEnabled {
	// This prevent us from using the reaction&comment button if we always return yes (although it allows us to switch images when not posted yet)
	// so only apply it to the desired element
	if ([[self accessibilityIdentifier] isEqualToString:@"Beaw"]){
		return YES;
	}
	return %orig;
}
%end

%hook UIViewController
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
	// BeReal somehow shows an error alert when using this tweak (at least on my device), so remove it
    if ([viewControllerToPresent isKindOfClass:[UIAlertController class]]) {
        UIAlertController *alert = (UIAlertController *)viewControllerToPresent;
        if ([alert.message isEqualToString:@"[\"Unable to load contents\"]"]) {
            return;
        }
    }
    %orig;
}
%end

BOOL isBlockedPath(const char *path) {
    if (!path) return NO;
    
    NSString *pathStr = @(path);
    
    if ([pathStr hasPrefix:@"/var/jb/"] || 
        [pathStr hasPrefix:@"/private/preboot/"] || 
        [pathStr hasPrefix:@"/private/var/jb"] ||
        [pathStr hasPrefix:@"/private/var/lib/apt"] ||
        [pathStr hasPrefix:@"/private/var/lib/cydia"] ||
        [pathStr hasPrefix:@"/private/var/stash"] ||
        [pathStr hasPrefix:@"/private/var/tmp/cydia"]) {
        return YES;
    }
    
    NSArray *jbPaths = @[
        @"/Applications/Cydia.app",
        @"/Library/MobileSubstrate/MobileSubstrate.dylib",
        @"/System/Library/LaunchDaemons/com.ikey.bbot.plist",
        @"/System/Library/LaunchDaemons/com.saurik.Cydia.Startup.plist",
        @"/bin/bash",
        @"/etc/apt",
        @"/usr/bin/sshd",
        @"/usr/libexec/sftp-server",
        @"/usr/sbin/sshd"
    ];

    for (NSString *jbPath in jbPaths) {
        if ([pathStr isEqualToString:jbPath]) {
            return YES;
        }
    }
    
    return NO;
}

%hook NSFileManager
- (BOOL)fileExistsAtPath:(NSString *)path {
    if (isBlockedPath([path UTF8String])) {
        return NO;
    }
    return %orig;
}
%end

%hook AdvertsDataNativeViewContainer
- (void)didMoveToSuperview {
    [self removeFromSuperview];
}

- (CGSize)sizeThatFits:(CGSize)size {
    return CGSizeZero;
}

- (CGSize)intrinsicContentSize {
    return CGSizeZero;
}
%end

%ctor {
	%init(
	  MediaView = objc_getClass("_TtGC7SwiftUI14_UIHostingViewVS_14_ViewList_View_"),
	  DoubleMediaView = objc_getClass("_TtC7SwiftUIP33_A34643117F00277B93DEBAB70EC0697116_UIInheritedView"),
      HomeViewController = objc_getClass("BeReal.HomeViewController"),
	  AdvertsDataNativeViewContainer = objc_getClass("AdvertsData.AdvertNativeViewContainer")
	);
}