// C ABI header for orbital-canvas.
//
// Matches the #[no_mangle] extern "C" symbols in
// crates/orbital-canvas/src/c_api.rs.  iOS projects link the static lib
// built by `cargo build --target aarch64-apple-ios --release` and include this
// header via OrbitalCanvas.modulemap.
//
// Swift consumers use @_silgen_name instead of importing this header directly
// (see OrbitalGameBridge.swift).

#pragma once
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct OrbitalCanvas OrbitalCanvas;

OrbitalCanvas *orbital_canvas_init(
    void *raw_surface,
    uint32_t width,
    uint32_t height,
    const char *resource_base_url
);

void orbital_canvas_destroy(OrbitalCanvas *renderer);

void orbital_canvas_submit(
    OrbitalCanvas *renderer,
    const char *json_packet
);

int32_t orbital_canvas_set_scene(
    OrbitalCanvas *renderer,
    const char *scene_json
);

char *orbital_canvas_last_error(OrbitalCanvas *renderer);

void orbital_canvas_render(OrbitalCanvas *renderer);

void orbital_canvas_resize(
    OrbitalCanvas *renderer,
    uint32_t width,
    uint32_t height
);

int32_t orbital_canvas_set_scale(
    OrbitalCanvas *renderer,
    float scale
);

void orbital_canvas_set_clock(
    OrbitalCanvas *renderer,
    double ms
);

void orbital_canvas_set_motion(
    OrbitalCanvas *renderer,
    int32_t enabled
);

int32_t orbital_canvas_wants_frames(
    OrbitalCanvas *renderer
);

int32_t orbital_canvas_input(
    OrbitalCanvas *renderer,
    const char *event_type,
    float x,
    float y,
    int32_t button,
    const char *key
);

char *orbital_canvas_take_events(OrbitalCanvas *renderer);

char *orbital_canvas_take_missing_scripts(void);

uint64_t orbital_canvas_asset_generation(void);

void orbital_canvas_zoom(OrbitalCanvas *renderer, float factor, float x, float y);

int32_t orbital_canvas_view_command(OrbitalCanvas *renderer, const char *command);

int32_t orbital_canvas_add_font(
    const char *script,
    const uint8_t *bytes,
    size_t len,
    uint32_t index
);

int32_t orbital_canvas_scene_size(
    const char *scene_json,
    float *out_w,
    float *out_h
);

int32_t orbital_canvas_render_scene_rgba(
    const char *scene_json,
    uint32_t width,
    uint32_t height,
    float scale,
    uint8_t **out_pixels,
    size_t *out_len
);

int32_t orbital_canvas_render_to_rgba(
    OrbitalCanvas *renderer,
    uint8_t **out_pixels,
    size_t *out_len
);

void orbital_canvas_free_rgba(uint8_t *pixels, size_t len);
void orbital_canvas_free_string(char *s);

#ifdef __cplusplus
}
#endif
