#include <flutter/runtime_effect.glsl>
precision highp float;
uniform vec2 destination;
uniform vec2 extent;
uniform vec3 tint;
uniform float recolor;
uniform vec3 hoofTint;
uniform float hoofRecolor;
uniform vec3 headTint;
uniform float headRecolor;
uniform vec3 wingTint;
uniform float wingRecolor;
uniform sampler2D frame;
out vec4 fragColor;
float coverage(vec2 local, float plane, float alpha) {
  return clamp(texture(frame, vec2(local.x, (plane + local.y) / 5.0)).a / alpha, 0.0, 1.0);
}
vec3 apparel(vec3 rgb, vec3 color) {
  float luma = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
  vec3 shaded = clamp(color * (0.45 + 0.65 * luma), 0.0, 1.0);
  return mix(shaded, vec3(1.0), smoothstep(0.88, 1.0, luma) * 0.25);
}
void main() {
  vec2 local = (FlutterFragCoord().xy - destination) / extent;
  vec4 c = texture(frame, vec2(local.x, local.y / 5.0));
  if (c.a < 0.001) { fragColor = vec4(0.0); return; }
  vec3 rgb = c.rgb / c.a;
  float luma = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
  float targetLuma = dot(tint, vec3(0.2126, 0.7152, 0.0722));
  vec3 hair = clamp(tint * luma / max(targetLuma, 0.01), 0.0, 1.0);
  hair = mix(hair, vec3(1.0), smoothstep(0.76, 1.0, luma));
  vec3 result = rgb;
  result += (hair - rgb) * coverage(local, 1.0, c.a) * recolor;
  result += (apparel(rgb, hoofTint) - rgb) * coverage(local, 2.0, c.a) * hoofRecolor;
  result += (apparel(rgb, headTint) - rgb) * coverage(local, 3.0, c.a) * headRecolor;
  result += (apparel(rgb, wingTint) - rgb) * coverage(local, 4.0, c.a) * wingRecolor;
  fragColor = vec4(clamp(result, 0.0, 1.0) * c.a, c.a);
}
