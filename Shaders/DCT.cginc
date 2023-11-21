#define PI 3.1415972
#define SQRT2 0.70710678118
#define BLOCK_SIZE 8
#define BLOCK_SIZE_F 8.0
// sqrt(2/BLOCK_SIZE) ** 2
#define DCT_K 0.25

float DCTcoefficients(float2 k, float2 x)
{
    return cos(PI * k.x * x.x / BLOCK_SIZE_F) * cos(PI * k.y * x.y / BLOCK_SIZE_F);
}

float DCTa(uint x, uint y)
{
    return (x == 0 ? SQRT2 : 1.0) * (y == 0 ? SQRT2 : 1.0);
}

float4 UVColor(float2 uv)
{
    return tex2Dlod(_MainTex, float4(uv, 0, 0));
}

float4 PixelColor(uint2 pixelCoord)
{
    // +0.5 = center point of the pixel
    return UVColor((pixelCoord + 0.5) * _MainTex_TexelSize.xy);
}

uint2 PixelCoord(float2 uv)
{
    return uint2(uv * _MainTex_TexelSize.zw);
}

float4 enDCT(uint2 pixelCoord)
{
    uint2 subPixelCoord = pixelCoord & 7u;
    uint2 blockCoord = pixelCoord & ~7u;
    float a = DCTa(subPixelCoord.x, subPixelCoord.y);
    
    float3 val = float3(0.0, 0.0, 0.0);
    
    for (uint x = 0; x < BLOCK_SIZE; ++x)
    {
        for (uint y = 0; y < BLOCK_SIZE; ++y)
        {
            val += (PixelColor(blockCoord + uint2(x, y)).rgb) * DCTcoefficients(subPixelCoord, (float2(x, y) + 0.5)) * a;
        }
    }
        
    return float4(val * DCT_K, 1.0);
}

float4 Quantize(float4 value, float level)
{
    return round(value / BLOCK_SIZE_F * level) / level * BLOCK_SIZE_F;
}

float4 deDCT(uint2 pixelCoord)
{
    uint2 subPixelCoord = pixelCoord & 7u;
    uint2 blockCoord = pixelCoord & ~7u;
        
    float3 val = float3(0.0, 0.0, 0.0);
    for (uint x = 0; x < BLOCK_SIZE; ++x)
    {
        for (uint y = 0; y < BLOCK_SIZE; ++y)
        {
            val += PixelColor(blockCoord + uint2(x, y)).rgb * DCTcoefficients(float2(x, y), (subPixelCoord + 0.5)) * DCTa(x, y);
        }
    }
    
    return float4(val * DCT_K, 1.0);
}
