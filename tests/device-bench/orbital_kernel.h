#include <stdint.h>

typedef struct OrbitalKernelHandle OrbitalKernelHandle;

OrbitalKernelHandle *orbital_kernel_init(const char *resolved_schema_json, const char *client_id);
void orbital_kernel_destroy(OrbitalKernelHandle *handle);
char *orbital_kernel_dispatch(OrbitalKernelHandle *handle, const char *trait_name, const char *entity_id, const char *event, const char *payload_json);
char *orbital_kernel_frame(OrbitalKernelHandle *handle, uint64_t now_ms);
int32_t orbital_kernel_tick_count(OrbitalKernelHandle *handle);
void orbital_kernel_free_string(char *s);
int64_t orbital_kernel_outstanding_strings(void);
