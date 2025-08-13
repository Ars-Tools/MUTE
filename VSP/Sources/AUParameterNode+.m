//
//  AUParameterNode+.m
//  MUTE
//
//  Created by Kota on 7/21/R7.
//
#import"AUParameterNode+.h"
@implementation AUParameterTree (Initializer)
-(instancetype __nonnull)initWithCopy:(AUParameterTree*__nonnull const)instance {
	return self = [instance copy];
}
-(instancetype __nonnull)initWithRetain:(AUParameterTree*__nonnull const)instance {
	return self = instance; // ARC
}
@end
@implementation AUParameterGroup (Initializer)
-(instancetype __nonnull)initWithCopy:(AUParameterGroup*__nonnull const)instance {
	return self = [instance copy];
}
-(instancetype __nonnull)initWithRetain:(AUParameterGroup*__nonnull const)instance {
	return self = instance; // ARC
}
@end
@implementation AUParameter (Initializer)
-(instancetype __nonnull)initWithCopy:(AUParameter*__nonnull const)instance {
	return self = [instance copy];
}
-(instancetype __nonnull)initWithRetain:(AUParameter*__nonnull const)instance {
	return self = instance; // ARC
}
@end
