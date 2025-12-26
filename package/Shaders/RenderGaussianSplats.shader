// SPDX-License-Identifier: MIT
Shader "Gaussian Splatting/Render Splats"
{
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }

        Pass
        {
            ZWrite Off
            Blend OneMinusDstAlpha One
            Cull Off
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma require compute
            #pragma use_dxc

            #include "GaussianSplatting.hlsl"

            StructuredBuffer<uint> _OrderBuffer;

            struct v2f
            {
                half4 col : COLOR0;
                float2 pos : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            StructuredBuffer<SplatViewData> _SplatViewData;
            ByteAddressBuffer _SplatSelectedBits;
            uint _SplatBitsValid;

            // [新增] 1. 宣告接收 GSEffects 曲線貼圖的變數
            sampler2D _ColorCurveTex;

            v2f vert (uint vtxID : SV_VertexID, uint instID : SV_InstanceID)
            {
                v2f o = (v2f)0;
                instID = _OrderBuffer[instID];
                SplatViewData view = _SplatViewData[instID];
                float4 centerClipPos = view.pos;
                bool behindCam = centerClipPos.w <= 0;
                if (behindCam)
                {
                    o.vertex = asfloat(0x7fc00000); // NaN discards the primitive
                }
                else
                {
                    // 原始顏色讀取
                    o.col.r = f16tof32(view.color.x >> 16);
                    o.col.g = f16tof32(view.color.x);
                    o.col.b = f16tof32(view.color.y >> 16);
                    o.col.a = f16tof32(view.color.y);

                    // ========================================================
                    // [新增] 2. 應用 GSEffects 顏色曲線 (Color Grading)
                    // ========================================================
                    // 原理：將原始顏色(0~1)當作 X 軸座標，去貼圖上查找對應的新亮度
                    // tex2Dlod 是必須的，因為 Vertex Shader 不支援 tex2D
                    // .r 是因為生成的貼圖格式是 RFloat (單通道)
                    
                    float r = tex2Dlod(_ColorCurveTex, float4(o.col.r, 0.5, 0, 0)).r;
                    float g = tex2Dlod(_ColorCurveTex, float4(o.col.g, 0.5, 0, 0)).r;
                    float b = tex2Dlod(_ColorCurveTex, float4(o.col.b, 0.5, 0, 0)).r;

                    // 套用新顏色
                    o.col.rgb = float3(r, g, b);
                    // ========================================================

                    uint idx = vtxID;
                    float2 quadPos = float2(idx&1, (idx>>1)&1) * 2.0 - 1.0;
                    quadPos *= 2;

                    o.pos = quadPos;

                    float2 deltaScreenPos = (quadPos.x * view.axis1 + quadPos.y * view.axis2) * 2 / _ScreenParams.xy;
                    o.vertex = centerClipPos;
                    o.vertex.xy += deltaScreenPos * centerClipPos.w;

                    // is this splat selected?
                    if (_SplatBitsValid)
                    {
                        uint wordIdx = instID / 32;
                        uint bitIdx = instID & 31;
                        uint selVal = _SplatSelectedBits.Load(wordIdx * 4);
                        if (selVal & (1 << bitIdx))
                        {
                            o.col.a = -1;                
                        }
                    }
                }
                FlipProjectionIfBackbuffer(o.vertex);
                //o.vertex.x = - o.vertex.x;
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                float power = -dot(i.pos, i.pos);
                half alpha = exp(power);
                if (i.col.a >= 0)
                {
                    alpha = saturate(alpha * i.col.a);
                }
                else
                {
                    // "selected" splat: magenta outline, increase opacity, magenta tint
                    half3 selectedColor = half3(1,0,1);
                    if (alpha > 7.0/255.0)
                    {
                        if (alpha < 10.0/255.0)
                        {
                            alpha = 1;
                            i.col.rgb = selectedColor;
                        }
                        alpha = saturate(alpha + 0.3);
                    }
                    i.col.rgb = lerp(i.col.rgb, selectedColor, 0.5);
                }
                
                if (alpha < 1.0/255.0)
                    discard;

                half4 res = half4(i.col.rgb * alpha, alpha);
                return res;
            }
            ENDCG
        }
    }
}