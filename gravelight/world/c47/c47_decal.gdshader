shader_type spatial;
// GRAVELIGHT ONE's markings and stencils (the atlas, alpha scissor) under the same weathering as the skin (T-211).
render_mode cull_back, depth_draw_opaque;

#define C47_DECAL
#include "res://gravelight/world/c47/c47_skin.gdshaderinc"
