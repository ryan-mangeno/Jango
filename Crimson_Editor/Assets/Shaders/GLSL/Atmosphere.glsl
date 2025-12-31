#shader vertex
#version 410 core

layout (location = 0) in vec4 aPos;  // Position input
layout (location = 1) in vec4 aDir;  // View direction input

out vec2 v_texCoord;
out vec3 v_viewDir;

void main()
{
    gl_Position = aPos;

    // Normalize coordinates from [-1,1] to [0,1] for texture sampling
    v_texCoord = aPos.xy * 0.5 + 0.5;

    // Pass direction to fragment shader
    v_viewDir = aDir.xyz;
}






#shader fragment
#version 410 core

// Fragment output color
layout (location = 0) out vec4 aColor;

in vec2 v_texCoord;
in vec3 v_viewDir;

// Uniforms
uniform vec3 sun_direction;
uniform sampler2DArray Sky_Gradient;

// Calculates sun highlight contribution based on angle to view
vec3 getSun(float sunViewDot)
{
    float sunSize = 0.03;
    return vec3(1.0, 0.8, 0.8) * step(1.0 - sunSize * sunSize, sunViewDot);
}

// Calculates final sky color based on sun and view positions
vec3 getSky(vec2 uv)
{
    vec3 sunDirNorm = normalize(-sun_direction);
    vec3 viewDirNorm = normalize(v_viewDir);

    float sunViewDot = dot(sunDirNorm, viewDirNorm);
    float sunZenithDot = sunDirNorm.y;
    float viewZenithDot = viewDirNorm.y;

    float sunViewDot01 = (sunViewDot + 1.0) * 0.5;
    float sunZenithDot01 = (sunZenithDot + 1.0) * 0.5;

    // Sample base sky color
    vec3 skyColor = texture(Sky_Gradient, vec3(sunZenithDot01, 0.5, 0)).rgb;

    // Add gradient for view zenith
    vec3 viewZenithColor = texture(Sky_Gradient, vec3(sunZenithDot01, 0.5, 1)).rgb;
    float vzMask = pow(clamp(1.0 - viewZenithDot, 0.0, 1.0), 8.0);

    // Add sun highlight contribution
    vec3 sunViewColor = texture(Sky_Gradient, vec3(sunZenithDot01, 0.5, 1)).rgb;
    float svMask = pow(clamp(sunViewDot, 0.0, 1.0), 256.0);

    return skyColor + getSun(sunViewDot) + vzMask * viewZenithColor + svMask * sunViewColor;
}

void main()
{
    // Compute and output final color
    aColor = vec4(getSky(v_texCoord), 1.0);
}