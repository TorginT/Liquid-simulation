Shader "Hidden/AddBrush"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Brush("Brush", 2D) = "white" {}
//        [HideInInspector]
		_PaintUV("Hit UV Position", Vector) = (0,0,0,0)
        _BrushAngle ("Rotation Angle", Float) = 0
        InBrushSize ("InBrushSize", Range(.00,1)) = .21
        OutBrushSize ("OutBrushSize", Range(.00,1)) = .2
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

            #include "UnityCG.cginc"
            
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _BrushAngle;
            
            float InBrushSize;
            float OutBrushSize;
            
            float4 _PaintUV;
            sampler2D _Brush;

            v2f vert (appdata v)
            {
                v2f o;
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.vertex = UnityObjectToClipPos(v.vertex);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float4 col = tex2D(_MainTex, i.uv);
                
                float rad = radians(_BrushAngle);
                
                float2x2 rotationMatrix = float2x2(
                    cos(rad), -sin(rad),
                    sin(rad), cos(rad)
                );
                
                float2 brushUV = mul(rotationMatrix, (_PaintUV - i.uv) / OutBrushSize) * 0.5 + 0.5;
                float2 brushUVG = mul(rotationMatrix, (_PaintUV - i.uv) / InBrushSize) * 0.5 + 0.5;
                
				float brushColor = tex2D(_Brush, brushUV).r;
                float brushColorG = tex2D(_Brush, brushUVG).g;
                float bruchColorB = tex2D(_Brush, brushUVG).b;
                
                col.r = lerp(col.r, 1, brushColor);
                col.r = lerp(col.r, 0, brushColorG);
                
                col.g = lerp(col.g, 1, brushColorG);
                
                col.b = bruchColorB;
                
                return col.rgbb;
            }
            ENDCG
        }
    }
}
