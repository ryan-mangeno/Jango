#shader vertex
#version 410 core

// Vertex attribute inputs
layout (location = 0) in vec4 aPos;        
layout (location = 1) in vec4 aTexCoord; 

out vec2 v_texCoord;   
out vec4 v_pos;        

void main()
{
    gl_Position = aPos;

    // Pass values to the fragment shader
    v_texCoord = aTexCoord.xy;
    v_pos = aPos;
}



#shader fragment
#version 410 core

layout (location = 0) out vec4 aColor;

in vec2 v_texCoord;
in vec4 v_pos;

// Uniforms 
uniform sampler2D inputImage;     // Masked HDR bloom texture
uniform sampler2D OriginalImage;  // Original scene
uniform float exposure;           // Exposure setting
uniform float BloomAmount;        // Bloom intensity factor

// ACES tone mapping curve (approximation)
vec3 ACESFilm(vec3 x)
{
    float a = 2.51;
    float b = 0.03;
    float c = 2.43;
    float d = 0.59;
    float e = 0.14;

    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

void main()
{
    const float gamma = 0.8;

    // Sample HDR (bloom) and original scene color
    vec3 hdrColor = texture(inputImage, v_texCoord).rgb;
    vec3 originalColor = texture(OriginalImage, v_texCoord).rgb;

    // Simple Reinhard tone mapping on bloom
    hdrColor *= exposure / (1.0 + hdrColor / exposure);

    // Add bloom to original scene
    originalColor = mix(originalColor, originalColor + hdrColor * BloomAmount, hdrColor.xyz);

    // Apply filmic tone mapping and gamma correction
    originalColor = ACESFilm(originalColor);
    originalColor = pow(originalColor, vec3(1.0 / 2.2));

    // Output the final color
    aColor = vec4(originalColor, 1.0);
}