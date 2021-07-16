
vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
    vec4 texturecolor = Texel(tex, texture_coords);
	 texturecolor.r = 1.0 - texturecolor.r;
	 texturecolor.g = 1.0 - texturecolor.g;
	 texturecolor.b = 1.0 - texturecolor.b;
    return texturecolor * color;
}
