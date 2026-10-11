// C ABI header for orbital-game-renderer.
//
// Matches the #[no_mangle] extern "C" symbols in
// crates/orbital-game-renderer/src/c_api.rs.  iOS projects link the static lib
// built by `cargo build --target aarch64-apple-ios --release` and include this
// header via OrbitalGameRenderer.modulemap.
//
// Swift consumers use @_silgen_name instead of importing this header directly
// (see OrbitalGameBridge.swift).

#pragma once
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct OrbitalGameRenderer OrbitalGameRenderer;

OrbitalGameRenderer *orbital_game_renderer_init(
    void *raw_surface,
    uint32_t width,
    uint32_t height,
    const char *resource_base_url
);

void orbital_game_renderer_destroy(OrbitalGameRenderer *renderer);

void orbital_game_renderer_submit(
    OrbitalGameRenderer *renderer,
    const char *json_packet
);

int32_t orbital_game_renderer_set_scene(
    OrbitalGameRenderer *renderer,
    const char *scene_json
);

char *orbital_game_renderer_last_error(OrbitalGameRenderer *renderer);

void orbital_game_renderer_render(OrbitalGameRenderer *renderer);

void orbital_game_renderer_resize(
    OrbitalGameRenderer *renderer,
    uint32_t width,
    uint32_t height
);

int32_t orbital_game_renderer_set_scale(
    OrbitalGameRenderer *renderer,
    float scale
);

void orbital_game_renderer_set_clock(
    OrbitalGameRenderer *renderer,
    double ms
);

void orbital_game_renderer_set_motion(
    OrbitalGameRenderer *renderer,
    int32_t enabled
);

int32_t orbital_game_renderer_wants_frames(
    OrbitalGameRenderer *renderer
);

int32_t orbital_game_renderer_input(
    OrbitalGameRenderer *renderer,
    const char *event_type,
    float x,
    float y,
    int32_t button,
    const char *key
);

char *orbital_game_renderer_take_events(OrbitalGameRenderer *renderer);

char *orbital_game_renderer_take_missing_scripts(void);

uint64_t orbital_game_renderer_asset_generation(void);

void orbital_game_renderer_zoom(OrbitalGameRenderer *renderer, float factor, float x, float y);

int32_t orbital_game_renderer_view_command(OrbitalGameRenderer *renderer, const char *command);

int32_t orbital_game_renderer_add_font(
    const char *script,
    const uint8_t *bytes,
    size_t len,
    uint32_t index
);

int32_t orbital_game_renderer_scene_size(
    const char *scene_json,
    float *out_w,
    float *out_h
);

int32_t orbital_game_renderer_render_scene_rgba(
    const char *scene_json,
    uint32_t width,
    uint32_t height,
    float scale,
    uint8_t **out_pixels,
    size_t *out_len
);

int32_t orbital_game_renderer_render_to_rgba(
    OrbitalGameRenderer *renderer,
    uint8_t **out_pixels,
    size_t *out_len
);

void orbital_game_renderer_free_rgba(uint8_t *pixels, size_t len);
void orbital_game_renderer_free_string(char *s);

#ifdef __cplusplus
}
#endif
