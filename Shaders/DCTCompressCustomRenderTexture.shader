Shader "ShaderDCT/DCTCompressCustomRenderTexture"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Quality ("Quality", Int) = 85
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            Name "Update"

            CGPROGRAM
            #pragma fragment frag

            #include "UnityCustomRenderTexture.cginc"
            #pragma vertex CustomRenderTextureVertexShader

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _MainTex_TexelSize;
            uint _Quality;

            #include "DCT.cginc"

            float4 frag(v2f_customrendertexture i) : SV_Target
            {
                return float4(enDCT(PixelCoord(i.localTexcoord.xy), _Quality), 1.0);
            }
            ENDCG
        }
    }
}
