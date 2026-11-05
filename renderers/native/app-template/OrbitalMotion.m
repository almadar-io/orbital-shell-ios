#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <stdbool.h>

extern void orbital_native_ios_set_reduced_motion(bool reduced);

void orbital_motion_start(void) {
    orbital_native_ios_set_reduced_motion(UIAccessibilityIsReduceMotionEnabled());
    [[NSNotificationCenter defaultCenter]
        addObserverForName:UIAccessibilityReduceMotionStatusDidChangeNotification
        object:nil
        queue:[NSOperationQueue mainQueue]
        usingBlock:^(__unused NSNotification *notification) {
            orbital_native_ios_set_reduced_motion(UIAccessibilityIsReduceMotionEnabled());
        }];
}
