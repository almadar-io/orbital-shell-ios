// The iOS native-gpu host's sign-in (owner 2026-11-23): Google through GoogleSignIn, then Firebase Auth, so the ID
// token the server verifies is the one the web host sends. The Rust host asks with orbital_sign_in_start and
// orbital_sign_in_sign_out; every outcome and every token refresh comes back through the orbital_sign_in_* callbacks.
// The token goes to the transport's bearer slot and never to the program. Compiled only into an app built with a
// GoogleService-Info.plist (the shell's firebaseConfig option); others compile OrbitalSignInOff.m.
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
@import FirebaseCore;
@import FirebaseAuth;
@import GoogleSignIn;

extern void orbital_sign_in_token(const char *id_token);
extern void orbital_sign_in_signed_in(const char *uid, const char *email, const char *display_name, const char *id_token);
extern void orbital_sign_in_failed(const char *kind, const char *message);
extern void orbital_sign_in_signed_out(void);

static void orbital_send_token(FIRUser *user) {
    if (user == nil) {
        orbital_sign_in_token(NULL);
        return;
    }
    [user getIDTokenForcingRefresh:NO completion:^(NSString *token, NSError *error) {
        if (token != nil) orbital_sign_in_token(token.UTF8String);
    }];
}

void orbital_sign_in_install(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([FIRApp defaultApp] == nil) [FIRApp configure];
        [[FIRAuth auth] addIDTokenDidChangeListener:^(FIRAuth *auth, FIRUser *user) { orbital_send_token(user); }];
    });
}

static UIViewController *orbital_presenter(void) {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.isKeyWindow && window.rootViewController != nil) return window.rootViewController;
        }
    }
    return nil;
}

void orbital_sign_in_start(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *clientID = [FIRApp defaultApp].options.clientID;
        UIViewController *presenter = orbital_presenter();
        if (clientID.length == 0 || presenter == nil) {
            orbital_sign_in_failed("unavailable", clientID.length == 0 ? "the app's Firebase config names no client id" : "no window to present sign-in from");
            return;
        }
        GIDSignIn.sharedInstance.configuration = [[GIDConfiguration alloc] initWithClientID:clientID];
        [GIDSignIn.sharedInstance signInWithPresentingViewController:presenter completion:^(GIDSignInResult *result, NSError *error) {
            if (error != nil || result == nil) {
                const char *kind = error.code == kGIDSignInErrorCodeCanceled ? "cancelled" : "unavailable";
                orbital_sign_in_failed(kind, (error.localizedDescription ?: @"Google sign-in did not finish").UTF8String);
                return;
            }
            NSString *googleToken = result.user.idToken.tokenString;
            FIRAuthCredential *credential = [FIRGoogleAuthProvider credentialWithIDToken:googleToken accessToken:result.user.accessToken.tokenString];
            [[FIRAuth auth] signInWithCredential:credential completion:^(FIRAuthDataResult *signed, NSError *signError) {
                FIRUser *user = signed.user;
                if (signError != nil || user == nil) {
                    orbital_sign_in_failed("denied", (signError.localizedDescription ?: @"Firebase refused the sign-in").UTF8String);
                    return;
                }
                [user getIDTokenForcingRefresh:NO completion:^(NSString *token, NSError *tokenError) {
                    if (token == nil) {
                        orbital_sign_in_failed("unavailable", "no ID token for the signed-in user");
                        return;
                    }
                    orbital_sign_in_signed_in(user.uid.UTF8String, user.email.UTF8String, user.displayName.UTF8String, token.UTF8String);
                }];
            }];
        }];
    });
}

void orbital_sign_in_sign_out(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[FIRAuth auth] signOut:nil];
        [GIDSignIn.sharedInstance signOut];
        orbital_sign_in_signed_out();
    });
}
