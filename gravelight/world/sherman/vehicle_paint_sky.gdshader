shader_type spatial;
render_mode fog_disabled;
// T-253: the same paint for an aircraft in the sky: the map's fog would swallow it at its distances (the sky's other
// aircraft set disable_fog for the same reason). The body is vehicle_paint.gdshaderinc.
#include "vehicle_paint.gdshaderinc"
