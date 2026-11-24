// The sign-in an app built without a Firebase config carries: every ask is refused by name, so the program's failure
// route runs. An app built with the shell's firebaseConfig option compiles OrbitalSignIn.m instead.
#import <Foundation/Foundation.h>

extern void orbital_sign_in_failed(const char *kind, const char *message);
extern void orbital_sign_in_signed_out(void);

void orbital_sign_in_install(void) {}

void orbital_sign_in_start(void) {
    orbital_sign_in_failed("unavailable", "this build has no GoogleService-Info.plist");
}

void orbital_sign_in_sign_out(void) {
    orbital_sign_in_signed_out();
}
