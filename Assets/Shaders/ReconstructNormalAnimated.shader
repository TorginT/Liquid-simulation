Shader "Custom/ReconstructNormalAnimated"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _Heightmap("Heightmap", 2D) = "white" {}
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0
        _DeformIntensityTop("_DeformIntensityTop", Float) = 1
        _Deviation("Deviation", Range(0, 0.02)) = 0
        _TessValue( "Max Tessellation", Range( 1, 32 ) ) = 3
        
        waveFrequency("Wave Frequency", Float) = 40
        waveAmplitude("Wave Amplitude", Float) = 2
        waveSpeed("Wave Speed", Float) = 0.5
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        CGPROGRAM
        
        #pragma surface surf Standard keepalpha addshadow fullforwardshadows vertex:vert tessellate:tessFunction
        
        #pragma target 3.0

        sampler2D _MainTex;
        sampler2D _Heightmap;
        float _DeformIntensityTop;
        uniform float _Deviation;
        uniform float _TessValue;

        float waveFrequency;
        float waveAmplitude;
        float waveSpeed;
        
        float4 tessFunction( )
		{
			return _TessValue;
		}

        struct Input
        {
            float2 uv_MainTex;
        };

        half _Glossiness;
        half _Metallic;
        float4 _Color;
        
        void vert(inout appdata_full data)
        {
			float3 vertexNormal = data.normal.xyz;
            float2 uv = data.texcoord;
            float heightValueTop = tex2Dlod(_Heightmap, float4(uv, 0, 0.0)).r;
            float heightmask = tex2Dlod(_Heightmap, float4(uv, 0, 0.0)).g;

            float dampingMask = tex2Dlod(_Heightmap, float4(uv, 0, 0.0)).b;
            
            float time = _Time.y; 
            
            float waveValue = sin((data.vertex.y + time * waveSpeed) * waveFrequency) * waveAmplitude;
            
            dampingMask = lerp(0, heightmask, saturate(1 - dampingMask * 1.1));
            waveValue = lerp(_DeformIntensityTop, waveValue, dampingMask);
            
            data.vertex.xyz += vertexNormal * lerp(0.25, heightValueTop * _DeformIntensityTop, heightValueTop * waveValue);
            
            float deviation = _Deviation;
            
            float left = tex2Dlod(_Heightmap, float4(uv + float2(-deviation, 0.0), 0, 0.0)).r;
            float down = tex2Dlod(_Heightmap, float4(uv + float2(0.0, -deviation), 0, 0.0)).r;
            float right = tex2Dlod(_Heightmap, float4(uv + float2(deviation, 0.0), 0, 0.0)).r;
            float up = tex2Dlod(_Heightmap, float4(uv + float2(0.0, deviation), 0, 0.0)).r;
            
            float2 gradient = (float2(left, down) - float2(right, up)) * lerp(0.25, _DeformIntensityTop, heightmask * waveValue) * lerp(6, 2 , lerp(0.25, _DeformIntensityTop, heightmask * waveValue));
            float dotValue = dot(gradient, gradient);
            float3 reconstructedNormal = float3(gradient, sqrt(1.0 - saturate(dotValue)));
            
            float3 finalNormal = reconstructedNormal;
            float4 tangent = data.tangent;
            float3 bitangent = cross(vertexNormal, tangent.xyz) * tangent.w;
            float3x3 TBN = float3x3(tangent.xyz, bitangent, vertexNormal);
            data.normal = mul(finalNormal, TBN);
        }

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
            o.Albedo = c.rgb;
            o.Metallic = _Metallic;
            o.Smoothness = _Glossiness;
            o.Alpha = c.a;
        }
        ENDCG
    }
    FallBack "Hidden/InternalErrorShader"
}
