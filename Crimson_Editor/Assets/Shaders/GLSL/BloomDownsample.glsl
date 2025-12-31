#shader vertex
#version 410 core

// Input attributes
layout (location = 0) in vec4 a_Position;  // Vertex position
layout (location = 1) in vec4 a_TexCoord;  // Texture coordinates

// Output variables
out vec2 v_TexCoord;  // Pass texture coordinates to fragment shader
out vec4 v_Position;  // Pass vertex position to fragment shader

void main()
{
    // Set the final position of the vertex
    gl_Position = a_Position;

    // Pass texture coordinates and position to the fragment shader
    v_TexCoord = a_TexCoord.xy;
    v_Position = a_Position;
}

#shader fragment
#version 410 core

layout (location = 0) out vec4 fragColor;  // Final color output

// Input variables from the vertex shader
in vec2 v_TexCoord;  // Texture coordinates
in vec4 v_Position;  // Vertex position

// Uniforms 
uniform sampler2D inputImage;  // Input texture (image)
uniform vec3 ImageRes;  // Resolution of the image

void main()
{
    // Calculate pixel size based on image resolution
    vec2 pixelSize = 1.0 / ImageRes.xy;
    float x = pixelSize.x;
    float y = pixelSize.y;

    // Sample the surrounding pixels from the texture
    vec4 a = texture(inputImage, vec2(v_TexCoord.x - 2.0 * x, v_TexCoord.y + 2.0 * y));
    vec4 b = texture(inputImage, vec2(v_TexCoord.x, v_TexCoord.y + 2.0 * y));
    vec4 c = texture(inputImage, vec2(v_TexCoord.x + 2.0 * x, v_TexCoord.y + 2.0 * y));
       
    vec4 d = texture(inputImage, vec2(v_TexCoord.x - 2.0 * x, v_TexCoord.y));
    vec4 e = texture(inputImage, vec2(v_TexCoord.x, v_TexCoord.y));
    vec4 f = texture(inputImage, vec2(v_TexCoord.x + 2.0 * x, v_TexCoord.y));
       
    vec4 g = texture(inputImage, vec2(v_TexCoord.x - 2.0 * x, v_TexCoord.y - 2.0 * y));
    vec4 h = texture(inputImage, vec2(v_TexCoord.x, v_TexCoord.y - 2.0 * y));
    vec4 i = texture(inputImage, vec2(v_TexCoord.x + 2.0 * x, v_TexCoord.y - 2.0 * y));
       
    vec4 j = texture(inputImage, vec2(v_TexCoord.x - x, v_TexCoord.y + y));
    vec4 k = texture(inputImage, vec2(v_TexCoord.x + x, v_TexCoord.y + y));
    vec4 l = texture(inputImage, vec2(v_TexCoord.x - x, v_TexCoord.y - y));
    vec4 m = texture(inputImage, vec2(v_TexCoord.x + x, v_TexCoord.y - y));

    // Apply weighted distribution for downsampling:
    // The weights add up to 1, with more influence given to the surrounding pixels.
    // This weighted combination smooths the image and reduces aliasing.
    // 0.5 + 0.125 + 0.125 + 0.125 + 0.125 = 1
    // The following is the calculation:
    // a,b,d,e * 0.125
    // b,c,e,f * 0.125
    // d,e,g,h * 0.125
    // e,f,h,i * 0.125
    // j,k,l,m * 0.5

    vec4 calculatedColor = vec4(0.0);
    calculatedColor = e * 0.125;
    calculatedColor += (a + c + g + i) * 0.03125;  // 0.125
    calculatedColor += (b + d + f + h) * 0.0625;  // 0.25
    calculatedColor += (j + k + l + m) * 0.125;  // 0.5

    // Set the final color (ignoring the alpha channel for simplicity)
    fragColor = vec4(calculatedColor.xyz, 1.0);
}