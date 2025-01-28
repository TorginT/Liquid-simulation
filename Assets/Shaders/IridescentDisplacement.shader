Shader"Custom/PearlizedDisplacement"
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
        
        [SingleLineTexture]_Heightmap("Heightmap", 2D) = "white" {}
		_UVScale("UV Scale", Vector) = (0,0,0,0)
		_Displacement("Displacement", Range( 0 , 1)) = 0
		_Deviation("Deviation", Range( 0 , 0.02)) = 0
		_FlowIntensityV("Vertical Flow Intensity", Float) = 0
		_FlowIntensityU("Horizontal Flow Intensity", Float) = 1
		_AnimationSpeed("Animation Speed", Float) = 0
		[HideInInspector] _texcoord( "", 2D ) = "white" {}
		[HideInInspector] __dirty( "", Int ) = 1
    	
    	_TessValue( "Max Tessellation", Range( 1, 10 ) ) = 3
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        CGPROGRAM
        #pragma surface surf Standard keepalpha addshadow fullforwardshadows vertex:vertexDataFunc tessellate:tessFunction

        #pragma target 3.0

        sampler2D _MainTex;
        sampler3D _NoiseTex;
        float IridescentDistortionScale;
        float IridescentEffectStrength;
        float IridescentFresnelStrength;
        float IridescentFresnelMaskPower;
        float IridescentRange;
        float3 IridescentTint;

        uniform sampler2D _Heightmap;
		uniform float2 _UVScale;
		uniform float _AnimationSpeed;
		uniform float _FlowIntensityU;
		uniform float _FlowIntensityV;
		uniform float _Displacement;
		uniform float _Deviation;
		uniform float4 _BaseColor;
		uniform float _TessValue;
        
        float2 AnimateUV(float2 uv, float speed, float2 direction)
		{
			return uv + direction * (_Time.y + 100) * speed;
		}

		float3 ComputeFlowContribution(float2 uv)
		{
			float3 animatedUV1 = tex2Dlod(_Heightmap, float4(AnimateUV(uv, _AnimationSpeed, float2(1, 0)), 0, 0)).rgb;
			float3 animatedUV2 = tex2Dlod(_Heightmap, float4(AnimateUV(uv, - _AnimationSpeed, float2(1, 0.04)), 0, 0)).rgb;
			float3 animatedUV3 = tex2Dlod(_Heightmap, float4(AnimateUV(uv, _AnimationSpeed, float2(0, 1)), 0, 0)).rgb;
			float3 animatedUV4 = tex2Dlod(_Heightmap, float4(AnimateUV(uv, - _AnimationSpeed, float2(0.03, 1)), 0, 0)).rgb;

			return (animatedUV1 * animatedUV2) * _FlowIntensityU + (animatedUV3 * animatedUV4) * _FlowIntensityV;
		}

        float2 ComputeHeightOffsets(float2 baseUV, float deviation)
		{
			return float2(
				tex2D(_Heightmap, baseUV + float2(-deviation, 0)).r - tex2D(_Heightmap, baseUV + float2(deviation, 0)).r,
				tex2D(_Heightmap, baseUV + float2(0, -deviation)).r - tex2D(_Heightmap, baseUV + float2(0, deviation)).r
			);
		}
        
        struct Input
        {
        	float2 uv_texcoord;
            float3 viewDir;
            float3 worldNormal;
            float3 worldPos;
        	INTERNAL_DATA
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

        float4 CalculateIridescenceBasedOnHeightMap(IridescentSettings settings, sampler3D _NoiseTex, sampler2D _HeightTex, float2 uv)
        {
            float3 normals = settings.CD.PixelNormalWS;
            float fresnel_mask = Fresnel((1.0f / settings.FresnelStrength), settings.CD.ViewDirWS, normals);
            fresnel_mask = pow(fresnel_mask, IridescentFresnelMaskPower);

            float3 reflection_vector = ReflectionVector(
                settings.CD.ViewDirWS,
                normalize(settings.CD.PositionWS - settings.CD.ObjectPositionWS)
            ) * settings.DistortionStrength;

            float4 noise_sample = tex3D(_NoiseTex, reflection_vector);

        	float2 uvScaled = uv * _UVScale;
			float3 flowContribution = ComputeFlowContribution(uvScaled);
		    float noise_mask = 1 - (tex2Dlod(_Heightmap, float4(uvScaled + flowContribution, 0, 0.0)).r * (_Displacement * 1.5));

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
        
        void vertexDataFunc(inout appdata_full vertexData)
		{
			float2 uvScaled = vertexData.texcoord.xy * _UVScale;
			float3 flowContribution = ComputeFlowContribution(uvScaled);
			float3 displacedPosition = vertexData.normal.xyz * (tex2Dlod(_Heightmap, float4(uvScaled + flowContribution, 0, 0.0)).r * _Displacement);
			vertexData.vertex.xyz += displacedPosition;
			vertexData.vertex.w = 1;
		}

        float4 tessFunction( )
		{
			return _TessValue;
		}
        
        void surf (Input IN, inout SurfaceOutputStandard o)
        {
			float2 uvScaled = IN.uv_texcoord * _UVScale;
			float3 flowContribution = ComputeFlowContribution(uvScaled);
			float3 heightmapOffset = float3(uvScaled, 0) + flowContribution;
			float2 gradient = ComputeHeightOffsets(heightmapOffset.xy, _Deviation) * _Displacement * lerp(6, 2, _Displacement);
			float normalZ = sqrt(1.0 - saturate(dot(gradient, gradient)));
			float3 tangentNormal = float3(gradient, normalZ);
        	
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
                float4 iredescColor = CalculateIridescenceBasedOnHeightMap(is, _NoiseTex, _Heightmap, IN.uv_texcoord);
        		
            float3 reflectionVect = ReflectionVector(IN.viewDir, IN.worldNormal);
            float3 cubeReflection = IBLRefl(_Cube, _Detail, reflectionVect, _ReflectionExposure);
        	
            o.Albedo = lerp(iredescColor, iredescColor * cubeReflection, _ReflectionFactor);

        	o.Normal = tangentNormal;
            
            o.Metallic = _Metallic;
            o.Smoothness = _Glossiness;
            
        }
        ENDCG
    }
    FallBack "Diffuse"
}
