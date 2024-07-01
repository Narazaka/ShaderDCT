#define PI 3.1415972
#define SQRT2 0.70710678118
#define BLOCK_SIZE 8
#define BLOCK_SIZE_F 8.0
// sqrt(2/BLOCK_SIZE) ** 2
#define DCT_K 0.25
// BT.601
#define RGB_to_YCbCr float3x3(\
0.299, 0.587, 0.114,\
-0.168736, -0.331264, 0.5,\
0.5, -0.418688, -0.081312\
)
#define YCbCr_to_RGB float3x3(\
1, 0, 1.402,\
1, -0.344136, -0.714136,\
1, 1.772, 0\
)
#define CbCrOffset 0.5
#define BLOCK_PIXEL_COUNT 64
// stbi jpeg
static uint YQT[BLOCK_PIXEL_COUNT] = {16,11,10,16,24,40,51,61,12,12,14,19,26,58,60,55,14,13,16,24,40,57,69,56,14,17,22,29,51,87,80,62,18,22,
                      37,56,68,109,103,77,24,35,55,64,81,104,113,92,49,64,78,87,103,121,120,101,72,92,95,98,112,100,103,99};
static const uint UVQT[BLOCK_PIXEL_COUNT] = {17,18,24,47,99,99,99,99,18,21,26,66,99,99,99,99,24,26,56,99,99,99,99,99,47,66,99,99,99,99,99,99,
                             99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99,99};
static const uint zigzag[BLOCK_PIXEL_COUNT] = { 0,1,5,6,14,15,27,28,2,4,7,13,16,26,29,42,3,8,12,17,25,30,41,43,9,11,18,
      24,31,40,44,53,10,19,23,32,39,45,52,54,20,22,33,38,46,51,55,60,21,34,37,47,50,56,59,61,35,36,48,49,57,58,62,63 };

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

uint QuantizeFactor(uint factor, uint quality)
{
    quality =  quality < 50 ? 5000 / quality : 200 - quality * 2;
    return clamp((factor * quality + 50) / 100, 1, 255);
}

// https://henatips.com/page/25/
// stbi
float QuantizeY(float y, uint2 pixelCoord, uint quality)
{
    uint2 subPixelCoord = pixelCoord & 7u;
    uint2 blockCoord = pixelCoord & ~7u;
    uint index = subPixelCoord.y * BLOCK_SIZE + subPixelCoord.x;

    return round(y * 255.0 / QuantizeFactor(YQT[index], quality)) / 255.0;
}

float2 QuantizeCbCr(float2 cbcr, uint2 pixelCoord, uint quality)
{
    uint2 subPixelCoord = (pixelCoord & 15u) >> 1;
    uint2 blockCoord = pixelCoord & ~15u;
    uint index = subPixelCoord.y * BLOCK_SIZE + subPixelCoord.x;

    return round(cbcr * 255.0 / QuantizeFactor(UVQT[index], quality)) / 255.0;
}

float DequantizeY(float y, uint2 pixelCoord, uint quality)
{
    uint2 subPixelCoord = pixelCoord & 7u;
    uint2 blockCoord = pixelCoord & ~7u;
    uint index = subPixelCoord.y * BLOCK_SIZE + subPixelCoord.x;

    return y * QuantizeFactor(YQT[index], quality);
}

float2 DequantizeCbCr(float2 cbcr, uint2 pixelCoord, uint quality)
{
    uint2 subPixelCoord = (pixelCoord & 15u) >> 1;
    uint2 blockCoord = pixelCoord & ~15u;
    uint index = subPixelCoord.y * BLOCK_SIZE + subPixelCoord.x;

    return cbcr * QuantizeFactor(UVQT[index], quality);
}

float enDCTY(uint2 pixelCoord)
{
    uint2 subPixelCoord = pixelCoord & 7u;
    uint2 blockCoord = pixelCoord & ~7u;
    float a = DCTa(subPixelCoord.x, subPixelCoord.y);
    
    float val = 0.0;

    for (uint x = 0; x < BLOCK_SIZE; ++x)
    {
        for (uint y = 0; y < BLOCK_SIZE; ++y)
        {
            val += mul(RGB_to_YCbCr, PixelColor(blockCoord + uint2(x, y)).rgb).x * DCTcoefficients(subPixelCoord, (float2(x, y) + 0.5)) * a;
        }
    }

    return val * DCT_K;
}

float2 enDCTCbCr(uint2 pixelCoord)
{
    uint2 subPixelCoord = (pixelCoord & 15u) >> 1;
    uint2 blockCoord = pixelCoord & ~15u;
    float a = DCTa(subPixelCoord.x, subPixelCoord.y);
    
    float2 val = float2(0.0, 0.0);
    
    for (uint x = 0; x < BLOCK_SIZE; ++x)
    {
        for (uint y = 0; y < BLOCK_SIZE; ++y)
        {
            val += mul(RGB_to_YCbCr, PixelColor(blockCoord + (uint2(x, y) << 1)).rgb).yz * DCTcoefficients(subPixelCoord, (float2(x, y) + 0.5)) * a;
        }
    }

    return val * DCT_K + CbCrOffset;
}

float3 enDCTRGB(uint2 pixelCoord)
{
    uint2 subPixelCoord = pixelCoord & 7u;
    uint2 blockCoord = pixelCoord & ~7u;
    float a = DCTa(subPixelCoord.x, subPixelCoord.y);
    
    float3 val = float3(0.0, 0.0, 0.0);

    for (uint x = 0; x < BLOCK_SIZE; ++x)
    {
        for (uint y = 0; y < BLOCK_SIZE; ++y)
        {
            val += PixelColor(blockCoord + uint2(x, y)).rgb * DCTcoefficients(subPixelCoord, (float2(x, y) + 0.5)) * a;
        }
    }

    return val * DCT_K;
}

float3 enDCT(uint2 pixelCoord, uint quality)
{
    return float3(QuantizeY(enDCTY(pixelCoord), pixelCoord, quality), QuantizeCbCr(enDCTCbCr(pixelCoord), pixelCoord, quality));
}

float deDCTY(uint2 pixelCoord, uint quality)
{
    uint2 subPixelCoord = pixelCoord & 7u;
    uint2 blockCoord = pixelCoord & ~7u;
    
    float val = 0.0;
    for (uint x = 0; x < BLOCK_SIZE; ++x)
    {
        for (uint y = 0; y < BLOCK_SIZE; ++y)
        {
            val += DequantizeY(PixelColor(blockCoord + uint2(x, y)).r, pixelCoord, quality) * DCTcoefficients(float2(x, y), (subPixelCoord + 0.5)) * DCTa(x, y);
        }
    }
    
    return val * DCT_K;
}

float2 deDCTCbCr(uint2 pixelCoord, uint quality)
{
    uint2 subPixelCoord = (pixelCoord & 15u) >> 1;
    uint2 blockCoord = pixelCoord & ~15u;
    
    float2 val = float2(0.0, 0.0);
    for (uint x = 0; x < BLOCK_SIZE; ++x)
    {
        for (uint y = 0; y < BLOCK_SIZE; ++y)
        {
            val += (DequantizeCbCr(PixelColor(blockCoord + (uint2(x, y) << 1)).gb, pixelCoord, quality) - CbCrOffset) * DCTcoefficients(float2(x, y), (subPixelCoord + 0.5)) * DCTa(x, y);
        }
    }
    
    return val * DCT_K;
}

float3 deDCTRGB(uint2 pixelCoord)
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
    
    return val * DCT_K;
}

float3 deDCT(uint2 pixelCoord, uint quality)
{
    return float3(mul(YCbCr_to_RGB, float3(deDCTY(pixelCoord, quality), deDCTCbCr(pixelCoord, quality))));
}
