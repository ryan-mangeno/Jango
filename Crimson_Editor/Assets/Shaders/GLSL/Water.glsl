#shader vertex
#version 430 core
layout (location = 0) in vec4 pos;

uniform mat4 u_ProjectionView;

void main()
{
	gl_Position = u_ProjectionView * pos;
}

#shader fragment
#version 430 core
layout (location = 0) out vec4 color;

uniform vec4 u_Color;

void main()
{
	color = u_Color;
}
