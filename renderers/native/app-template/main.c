extern void orbital_native_ios_main(void);
extern void orbital_motion_start(void);

int main(int argc, char **argv) {
    (void)argc;
    (void)argv;
    orbital_motion_start();
    orbital_native_ios_main();
    return 0;
}
