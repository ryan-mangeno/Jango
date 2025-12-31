#shader vertex
#version 410 core

layout (location = 0) in vec4 a_Position;  // Vertex position
layout (location = 1) in vec2 a_TexCoord;  // Texture coordinates
layout (location = 2) in vec4 a_Color;  // Vertex color
layout (location = 3) in float a_SlotIndex;  // Slot index for texture selection

// Output variables
out vec2 v_TexCoord;  // Pass texture coordinates to fragment shader
out vec4 v_Color;  // Pass vertex color to fragment shader
out float v_SlotIndex;  // Pass slot index to fragment shader

// Uniforms 
uniform mat4 u_ProjectionView;  // Projection-view matrix
uniform mat4 u_ModelTransform;  // Model transformation matrix

void main()
{
    // Assign inputs to outputs
    v_Color = a_Color;  
    v_SlotIndex = a_SlotIndex;  
    v_TexCoord = a_TexCoord;  

    // Apply projection and view transformations to vertex position
    gl_Position = u_ProjectionView * a_Position;  
}

#shader fragment
#version 410 core

layout (location = 0) out vec4 fragColor;  // Final color output

// Input variables from vertex shader
in vec4 v_Color;  // Vertex color
in float v_SlotIndex;  // Slot index for texture selection
in vec2 v_TexCoord;  // Texture coordinates

// Uniforms
uniform sampler2D u_Texture[32];  // Array of textures
uniform vec4 u_color;  // Additional color uniform (not used in this shader for now)

void main()
{
    // Convert the slot index to an integer for texture selection
    int index = int(v_SlotIndex);

    // Sample the texture and apply vertex color
    fragColor = texture(u_Texture[index], v_TexCoord) * v_Color;  
}