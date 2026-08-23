shader_type canvas_item;

// Smooth panoramic remapping for landscape battle backgrounds.
// The source artwork keeps its natural scale around the centre of the arena.
// Only the far left/right scenery is progressively compressed to fill the
// ultrawide battle strip. This avoids both COVER zoom and visible panel seams.
uniform float warp_slope : hint_range(0.5, 3.0) = 1.8;
uniform float zoom : hint_range(1.0, 1.6) = 1.18;
uniform vec2 focus = vec2(0.5, 0.5);
uniform vec2 offset_uv = vec2(0.0, 0.0);

float panorama_warp(float t, float slope) {
    float s = max(slope, 0.05);
    float denominator = sqrt(max(0.0001, 1.0 + (s * s - 1.0) * t * t));
    return (s * t) / denominator;
}

void fragment() {
    float centred_x = UV.x * 2.0 - 1.0;
    float warped_x = panorama_warp(centred_x, warp_slope);

    vec2 source_uv;
    source_uv.x = focus.x + 0.5 * warped_x - offset_uv.x;
    source_uv.y = focus.y + (UV.y - 0.5) / zoom - offset_uv.y;
    source_uv = clamp(source_uv, vec2(0.001), vec2(0.999));

    COLOR = texture(TEXTURE, source_uv) * COLOR;
}
