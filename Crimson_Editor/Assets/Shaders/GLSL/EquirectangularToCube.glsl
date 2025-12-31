#shader vertex
#version 410 core

// Input attribute for vertex position
layout (location = 0) in vec3 a_Position;

// Output variable for the fragment shader
out vec3 v_Position;

// Uniforms
uniform mat4 u_ProjectionView; 

void main()
{
    // Pass vertex position to fragment shader
    v_Position = a_Position;

    // Apply the projection-view transformation to the vertex position
    gl_Position = u_ProjectionView * vec4(a_Position, 1.0);
}

#shader fragment
#version 410 core

// Output color for the fragment shader
layout (location = 0) out vec4 fragColor;

// Input variable from the vertex shader
in vec3 v_Position;

uniform sampler2D hdrTexture;  // High dynamic range texture

// Constants for spherical mapping
const vec2 invAtan = vec2(0.1591, 0.3183);  // Pre-calculated inverse atan for mapping

// Function to convert spherical coordinates to UV space
vec2 SampleSphericalMap(vec3 v)
{
    vec2 uv = vec2(atan(v.z, v.x), asin(v.y));  // Convert to spherical coordinates
    uv *= invAtan;  // Scale the coordinates
    uv += 0.5;  // Offset to map to [0, 1] range
    return uv;
}

void main()
{
    // Convert the position to spherical UV coordinates
    vec2 uv = SampleSphericalMap(normalize(v_Position));

    // Sample the environment map texture at the spherical coordinates
    vec3 envColor = texture(hdrTexture, uv).rgb;

    // Apply exposure correction to the environment color
    vec3 mapped = vec3(1.0) - exp(-envColor * 1.0);  // Exposure adjustment

    // Set the final color output
    fragColor = vec4(mapped, 1.0);  // Set the final color with full alpha
}