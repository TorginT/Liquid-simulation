Shader "Custom/Pearlized"
{
    Properties
    {
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0
        
        _NoiseTex ("Noise Texture", 3D) = "white" {}
        
        IridescentDistortionScale ("Iridescent Distortion Scale", Float) = 0.05
        IridescentEffectStrength ("Iridescent Effect Strength", Range(0.0, 1.0)) = 1.0
        IridescentFresnelStrength ("Iridescent Fresnel Strength", Range(0.0, 1.0)) = 0.25
        IridescentFresnelMaskPower("Iridescent Fresnel Power", Range(0.0, 1.0)) = 0.2
        IridescentRange ("Iridescent Range", Range(0.0, 2.0)) = 1.0
        IridescentTint ("Iridescent Tint", Color) = (0.0, 0.178, 1.0)
        
        _Cube("Cube Map", Cube) = "" {}
        _Detail("Reflection Detail", Range(1,9)) = 1.0
		_ReflectionExposure("HDR Exposure", float) = 1.0
        _ReflectionFactor("Reflection %",Range(0,1)) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        CGPROGRAM
        #pragma surface surf Standard fullforwardshadows

        #pragma target 3.0

        sampler2D _MainTex;
        sampler3D _NoiseTex;
        float IridescentDistortionScale;
        float IridescentEffectStrength;
        float IridescentFresnelStrength;
        float IridescentFresnelMaskPower;
        float IridescentRange;
        float3 IridescentTint;

        struct Input
        {
            float2 uv_MainTex;
            float3 viewDir;
            float3 worldNormal;
            float3 worldPos;
        };

        struct CoreData
            {
                float3 PixelNormalWS;
                float3 ViewDirWS;
                float3 PositionWS;
                float3 ObjectPositionWS;
            };

        struct IridescentSettings
        {
            float FresnelStrength;
            float3 Tint;
            float Range;
            float DistortionStrength;
            float EffectStrength;
            CoreData CD;
        };
        
        float3 Lerp3(float3 a, float3 b, float3 c, float x)
        {
            float3 ab = lerp(a, b, saturate(2.0f * x));
            float3 ab_c = lerp(ab, c, saturate((2.0f * x) - 1.0f));
            return ab_c;
        }

        float3 ReflectionVector(float3 viewDir, float3 targetNormal)
        {
            return -viewDir + targetNormal * dot(targetNormal, viewDir) * 2.0f;
        }

        float Fresnel(float exponent, float3 viewDir, float3 normal)
        {
            float fresnel = 1.0f - pow(1.0f - dot(normal, viewDir), exponent);
            return saturate(fresnel);
        }

        float3 HueShift(float3 color, float shift)
        {
            float3 P = float3(0.55735.xxx) * dot(float3(0.55735.xxx), color);
            float3 U = color - P;
            float3 V = cross(float3(0.55735.xxx), U);
            color = U * cos(shift * 6.2832) + V * sin(shift * 6.2832) + P;
            return color;
        }

        float4 CalculateIridescence(IridescentSettings settings, sampler3D _NoiseTex)
        {
            float3 normals = settings.CD.PixelNormalWS;
            float fresnel_mask = Fresnel((1.0f / settings.FresnelStrength), settings.CD.ViewDirWS, normals);
            fresnel_mask = pow(fresnel_mask, IridescentFresnelMaskPower);

            float3 reflection_vector = ReflectionVector(
                settings.CD.ViewDirWS,
                normalize(settings.CD.PositionWS - settings.CD.ObjectPositionWS)
            ) * settings.DistortionStrength;

            float4 noise_sample = tex3D(_NoiseTex, reflection_vector);
            float noise_mask = noise_sample.r + (1.0f - fresnel_mask);

            float percent_a = (settings.Range * 0.33f) * -1.0f;
            float percent_b = (settings.Range * 0.33f);
            float3 hue_a = HueShift(settings.Tint, percent_a);
            float3 hue_b = HueShift(settings.Tint, percent_b);

            float3 final_tint = Lerp3(hue_a, settings.Tint, hue_b, noise_mask);

            return float4(final_tint, 1.0f);
        }


        float3 IBLRefl(samplerCUBE cubeMap, half detail, float3 worldRefl, float exposure)
        {
            float4 cubeMapCol = texCUBElod(cubeMap, float4(worldRefl, detail)).rgba;
            return cubeMapCol.rgb * (cubeMapCol.a * exposure);
        }

        half _Glossiness;
        half _Metallic;
        fixed4 _Color;
        uniform samplerCUBE _Cube;
        float _ReflectionFactor;
        half _Detail;
        float _ReflectionExposure;
        
        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            CoreData cd = (CoreData)0;
                cd.PixelNormalWS = IN.worldNormal;
                cd.ViewDirWS = IN.viewDir;
                cd.PositionWS = IN.worldPos;
                cd.ObjectPositionWS = mul(unity_ObjectToWorld , float4(0,0,0,1)).xyz;

                IridescentSettings is = (IridescentSettings)0;
                is.FresnelStrength = IridescentFresnelStrength;
                is.Tint = IridescentTint;
                is.Range = IridescentRange;
                is.DistortionStrength = IridescentDistortionScale;
                is.EffectStrength = IridescentEffectStrength;
                is.CD = cd;
                float4 iredescColor = CalculateIridescence(is, _NoiseTex);

            float3 reflectionVect = ReflectionVector(IN.viewDir, IN.worldNormal);
            float3 cubeReflection = IBLRefl(_Cube, _Detail, reflectionVect, _ReflectionExposure);

            o.Albedo = lerp(iredescColor, iredescColor * cubeReflection, _ReflectionFactor);
            
            o.Metallic = _Metallic;
            o.Smoothness = _Glossiness;
            
        }
        ENDCG
    }
    FallBack "Diffuse"
}
