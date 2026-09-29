//
//  AUParameterNode+.h
//  MUTE
//
//  Created by Kota on 7/21/R7.
//
#import<AudioUnit/AudioUnit.h>
@interface AUParameterTree (Initializer)
-(instancetype __nonnull)initWithCopy:(AUParameterTree*__nonnull const)instance;
-(instancetype __nonnull)initWithRetain:(AUParameterTree*__nonnull const)instance;
@end
@interface AUParameterGroup (Initializer)
-(instancetype __nonnull)initWithCopy:(AUParameterGroup*__nonnull const)instance;
-(instancetype __nonnull)initWithRetain:(AUParameterGroup*__nonnull const)instance;
@end
@interface AUParameter (Initializer)
-(instancetype __nonnull)initWithCopy:(AUParameter*__nonnull const)instance;
-(instancetype __nonnull)initWithRetain:(AUParameter*__nonnull const)instance;
@end
