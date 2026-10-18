// Every Bonfire juice shader includes this, so the instance uniforms keep the SAME slot in every
// material of a GeometryInstance3D (Godot shares one instance-parameter block per instance, indexed
// by declaration order; different orders would make one shader read another's value).
// Animate them as instance_shader_parameters/<name> on the MeshInstance3D / particles node.
instance uniform float heat = 1.0;     // fire: 1 = burning, 0 = snuffed (erodes the shapes)
instance uniform float glow = 1.0;     // lit-face glow strength (0..2)
instance uniform float ash = 1.0;      // ash dice: 0 = bone, 1 = ash
instance uniform float dissolve = 0.0; // ash dice: 0 = solid, 1 = crumbled away
instance uniform float crack = 0.0;    // Soul flask glass: 0 = intact, 1 = cracked
instance uniform float fill = 1.0;     // Soul flask liquid level 0..1
