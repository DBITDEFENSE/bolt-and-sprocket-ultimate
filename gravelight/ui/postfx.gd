class_name PostFx
extends LookPost
## The film look every map scene carries (a CanvasLayer at 5, under the HUD). Since UPDATE 12 section 2 (T-208) it is
## the shared post stack, LookPost (gravelight/world/look/look_post.gd): grain, vignette, edge softness, chromatic
## aberration and the map's `post` block from data/look/<map_id>.json; a map with no grade (or `--look=off`) keeps
## the old vignette and cold shadow lift. The class stays so the map scenes and the HUD-hiding code (CinemaOverlay,
## CinemaReel skip `is PostFx`) keep working. Presentation only.
