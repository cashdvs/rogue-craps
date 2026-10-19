// Every Hearth shader includes this, so the instance uniforms keep the SAME slot in every material
// of a GeometryInstance3D (Godot shares one instance-parameter block per instance, indexed by
// declaration order). The prop scripts (scripts/*.gd) set them; animate the script properties.
instance uniform float heat = 1.0;   // fire / glow alive: 1 = burning, 0 = snuffed (a wisp / dark)
instance uniform float level = 0.0;  // eyes 0-3, brazier coal step 0-4, cauldron fill 0-1, seam idle 0-1
instance uniform float pulse = 0.0;  // ember seam pulse 0-1 (seam_pulse clip), flare boost on cards
