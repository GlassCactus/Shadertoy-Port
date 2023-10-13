# Shadertoy-Port
A renderer made from scratch in C++ using OpenGL that was created to run my ShaderToy fragment shaders. This was created to bridge the gap between learning OpenGL and learning raw GLSL with different rendering and lighting methods. This is mostly to be able to show my projects in ShaderToy until I figure out a way to do apply path tracing and ray marching to my rasterizer. Until then, this will be mainly used to display the rendering and lighting techniques I have learned.

![image](https://user-images.githubusercontent.com/86325057/212493657-8b567b9f-2997-4610-8ff6-581f32152954.png)
It currently features Ray Marching, Blinn-Phong lighting, Specular Normalization, Ambient Occlusion, Anti-aliasing "RGSS", Soft Shadows, Fresnel shading, and Reflections.

![Balls Ambient Occlusion](https://github.com/GlassCactus/Shadertoy-Port/assets/86325057/ca11ee75-bcc3-4245-903d-d30e73fb1792)
Figure 1: A raymarching implementation of Ambient Occlusion

![Anti-Aliasing Comparison](https://github.com/GlassCactus/Shadertoy-Port/assets/86325057/b99c289d-5ce9-42fb-a303-29f039aca698)
Figure 2: Comparison between the same scene with Anti-Aliasing turned OFF (top image) and turned ON (bottom image)
