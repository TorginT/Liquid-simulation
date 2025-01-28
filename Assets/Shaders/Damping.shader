Shader "Custom/Damping"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _DiffusionWeights("Weights", Vector) = (.25,.25,.25,.25)
        _DiffusionRate("Diffusion Rate", Range(0,2)) = .5
        _Minimum("Minimum Flow", Range(0,.01)) = .003
        _PixelsX("Pixels", Float) = 2048
        _PixelsY("Pixels", Float) = 2048
        _DeformIntensity("_DeformIntensity", Float) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            fixed4 _DiffusionWeights;
            float _PixelsX;
            float _PixelsY;

            float _DeformIntensity;
            
            fixed _DiffusionRate;
            fixed _Minimum;

            v2f vert (appdata v)
            {
                v2f o;
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.vertex = UnityObjectToClipPos(v.vertex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float2 _Pixels = float2(_PixelsX,_PixelsY); 
                fixed2 uv = round(i.uv * _Pixels) / _Pixels;
                
                float2 step = 1/_Pixels;
                float3 currentAlpha = saturate(tex2D(_MainTex,uv).rgb);
                
                float2 changeInAlpha = (tex2D(_MainTex, uv + float2(-step.x,0)).rg);
                
                changeInAlpha += (tex2D(_MainTex,uv + float2(0,-step.y)).rg);
                changeInAlpha += (tex2D(_MainTex,uv + float2(step.x,0)).rg);
                changeInAlpha += (tex2D(_MainTex,uv + float2(0,step.y)).rg);
                
                changeInAlpha -= currentAlpha;
                changeInAlpha *= _DiffusionRate;
                
                if(changeInAlpha.r >= -_Minimum && changeInAlpha.r <= 0){
                    changeInAlpha.r = -_Minimum;
                }

                if(changeInAlpha.g >= -_Minimum && changeInAlpha.g <= 0){
                    changeInAlpha.g = -_Minimum;
                }
                
                currentAlpha.rg = saturate(currentAlpha + changeInAlpha);
                
                return float4(currentAlpha.rgb, 1);
            }
            ENDCG
        }
    }
FallBack "Hidden/InternalErrorShader"
}
