#ifndef VALUEIO
#define VALUEIO

// input value bit
// ex. UInt16 -> 16
#ifndef DATABITS
#define DATABITS 16
#endif
// value separate block
// must be divisor of DATABITS
// ex 2x2 -> 4
#ifndef DATABLOCK_SIZE
#define DATABLOCK_SIZE 4
#endif
// value separate block col(x) count
// 2x2 -> 2, 1x4 -> 1
#ifndef DATABLOCK_X
#define DATABLOCK_X 2
#endif
// input value count
// ex. uint4 -> 4, float3 -> 3
#ifndef COMPONENT_COUNT
#define COMPONENT_COUNT 4
#endif
// 1px contains N value components
// must be divisor of COMPONENT_COUNT
// ex. uint3/RGB => 3, uint4/RG => 2, uint4/R => 1
#ifndef COMPONENT_COUNT_PER_COMPONENTBLOCK_PIXEL
    #if COMPONENT_COUNT == 1
    #define COMPONENT_COUNT_PER_COMPONENTBLOCK_PIXEL 1
    #elif COMPONENT_COUNT == 2
    #define COMPONENT_COUNT_PER_COMPONENTBLOCK_PIXEL 2
    #elif COMPONENT_COUNT == 3
    #define COMPONENT_COUNT_PER_COMPONENTBLOCK_PIXEL 3
    #elif COMPONENT_COUNT == 4
    #define COMPONENT_COUNT_PER_COMPONENTBLOCK_PIXEL 4
    #endif
#endif
// value components separate block col(x) count
#ifndef COMPONENTBLOCK_X
#define COMPONENTBLOCK_X 1
#endif

#define DATABLOCK_Y (DATABLOCK_SIZE / DATABLOCK_X)
#define DATABLOCK uint2(DATABLOCK_X, DATABLOCK_Y)
#define BIT_PER_DATABLOCK_PIXEL (DATABITS / DATABLOCK_SIZE)
#define DATA_MAXVALUE ((2 << (DATABITS - 1)) - 1)
#define DATABLOCK_PIXEL_MAXVALUE ((2 << (BIT_PER_DATABLOCK_PIXEL - 1)) - 1)
#define COMPONENTBLOCK_SIZE (COMPONENT_COUNT / COMPONENT_COUNT_PER_COMPONENTBLOCK_PIXEL)
#define COMPONENTBLOCK_Y (COMPONENTBLOCK_SIZE / COMPONENTBLOCK_X)
#define COMPONENTBLOCK uint2(COMPONENTBLOCK_X, COMPONENTBLOCK_Y)

#if COMPONENT_COUNT == 1
#define UINTVALUE uint1
#elif COMPONENT_COUNT == 2
#define UINTVALUE uint2
#elif COMPONENT_COUNT == 3
#define UINTVALUE uint3
#elif COMPONENT_COUNT == 4
#define UINTVALUE uint4
#endif

#if COMPONENT_COUNT == 1
#define FLOATVALUE float1
#elif COMPONENT_COUNT == 2
#define FLOATVALUE float2
#elif COMPONENT_COUNT == 3
#define FLOATVALUE float3
#elif COMPONENT_COUNT == 4
#define FLOATVALUE float4
#endif

// # UVCoord: pixelCoord -> uv

// dec
float2 UVCoord(uint2 pixelCoord)
{
    // +0.5 = center point of the pixel
    return (pixelCoord + 0.5) * _MainTex_TexelSize.xy;
}

float2 ScaledUVCoord(uint2 pixelCoord, uint2 scale)
{
    // +0.5 = center point of the pixel
    return (pixelCoord + 0.5) * _MainTex_TexelSize.xy / scale;
}

// # PixelCoord: uv -> pixelCoord

uint2 PixelCoord(float2 uv)
{
    return uint2(uv * _MainTex_TexelSize.zw);
}

uint2 ScaledPixelCoord(float2 uv, uint2 scale)
{
    return uint2(uv * _MainTex_TexelSize.zw * scale);
}

// enc
uint2 DataBlockPixelCoord(float2 uv)
{
    return uint2(uv * _MainTex_TexelSize.zw * DATABLOCK);
}

// enc
uint2 ComponentBlockPixelCoord(float2 uv)
{
    return uint2(uv * _MainTex_TexelSize.zw * DATABLOCK * COMPONENTBLOCK);
}

// dec
uint2 EncodedDataBlockPixelCoord(float2 uv)
{
    return uint2(uv * _MainTex_TexelSize.zw / COMPONENTBLOCK);
}

// # BlockCoord: pixelCoord -> block begin coord

uint2 BlockCoord(uint2 pixelCoord, uint2 blockSize)
{
    return (pixelCoord / blockSize) * blockSize;
}

// dec
uint2 DataBlockCoord(uint2 pixelCoord)
{
    return uint2(pixelCoord / DATABLOCK) * DATABLOCK;
}

// dec
uint2 EncodedComponentBlockCoordFromDataBlockCoord(uint2 blockCoord)
{
    return blockCoord * COMPONENTBLOCK;
}

// # SubPixelCoord: pixelCoord -> block sub pixel coord

uint2 SubPixelCoord(uint2 pixelCoord, uint2 blockSize)
{
    return pixelCoord % blockSize;
}

// enc
uint2 DataBlockSubPixelCoord(uint2 pixelCoord)
{
    return pixelCoord % DATABLOCK;
}

// enc
uint2 ComponentBlockSubPixelCoord(uint2 outPixelBlockCoord)
{
    return outPixelBlockCoord % COMPONENTBLOCK;
}

// # UVColor: uv -> get color

// dec
float4 UVColor(float2 uv)
{
    return tex2Dlod(_MainTex, float4(uv, 0, 0));
}

// # PixelColor: pixelCoord -> get color

// dec
float4 PixelColor(uint2 pixelCoord)
{
    return UVColor(UVCoord(pixelCoord));
}

float4 ScaledPixelColor(uint2 pixelCoord, uint2 scale)
{
    return UVColor(ScaledUVCoord(pixelCoord, scale));
}

#define COMPONENT_COUNT_PER_COMPONENTBLOCK_PIXEL 1
#define COMPONENT_COUNT 3
// enc
float4 ComponentSeparatedFromBits(FLOATVALUE value, float2 uv)
{
#if COMPONENT_COUNT_PER_COMPONENTBLOCK_PIXEL == COMPONENT_COUNT
#if COMPONENT_COUNT == 1
    return float4(value, 0, 0, 1);
#elif COMPONENT_COUNT == 2
    return float4(value, 0, 1);
#elif COMPONENT_COUNT == 3
    return float4(value, 1);
#elif COMPONENT_COUNT == 4
    return value;
#endif
#else
    uint2 pixelCoord = ComponentBlockPixelCoord(uv);
    uint2 subPixelCoord = ComponentBlockSubPixelCoord(pixelCoord);
    uint pixelIndex = subPixelCoord.x + subPixelCoord.y * COMPONENTBLOCK_X;
#if COMPONENT_COUNT_PER_COMPONENTBLOCK_PIXEL == 1
    return float4(value[pixelIndex], 0, 0, 1);
#elif COMPONENT_COUNT_PER_COMPONENTBLOCK_PIXEL == 2
    return float4(value[pixelIndex * 2], value[pixelIndex * 2 + 1], 0, 1);
#endif
#endif
}

FLOATVALUE ComponentBlockPixelColor(uint2 dataBlockPixelCoord)
{
#if COMPONENT_COUNT_PER_COMPONENTBLOCK_PIXEL == COMPONENT_COUNT
#if COMPONENT_COUNT == 1
    // because always COMPONENT_BLOCK == (1,1)
    return PixelColor(dataBlockPixelCoord).r;
#elif COMPONENT_COUNT == 2
    return PixelColor(dataBlockPixelCoord).rg;
#elif COMPONENT_COUNT == 3
    return PixelColor(dataBlockPixelCoord).rgb;
#elif COMPONENT_COUNT == 4
    return PixelColor(dataBlockPixelCoord);
#endif
#else
    uint2 blockCoord = EncodedComponentBlockCoordFromDataBlockCoord(dataBlockPixelCoord);
    FLOATVALUE result = float4(0, 0, 0, 1);
    for (uint x = 0; x < COMPONENTBLOCK_X; ++x)
    {
        for (uint y = 0; y < COMPONENTBLOCK_Y; ++y)
        {
            uint2 subPixelCoord = uint2(x, y);
            uint index = x + y * COMPONENTBLOCK_X;
            float4 color = PixelColor(blockCoord + subPixelCoord);
#if COMPONENT_COUNT_PER_COMPONENTBLOCK_PIXEL == 1
            result[index] = color.r;
#elif COMPONENT_COUNT_PER_COMPONENTBLOCK_PIXEL == 2
            result[index * 2] = color.r;
            result[index * 2 + 1] = color.g;
#endif
        }
    }
    return result;
#endif
}

FLOATVALUE EncodeToBitsFromUint(UINTVALUE value, float2 uv)
{
    uint2 pixelCoord = DataBlockPixelCoord(uv);
    uint2 subPixelCoord = DataBlockSubPixelCoord(pixelCoord);
    uint bitIndex = (subPixelCoord.x + subPixelCoord.y * DATABLOCK_X) * BIT_PER_DATABLOCK_PIXEL;
    return FLOATVALUE((value >> bitIndex) & DATABLOCK_PIXEL_MAXVALUE) / DATABLOCK_PIXEL_MAXVALUE;
}

FLOATVALUE EncodeToBitsFromFloat(FLOATVALUE value, float2 uv)
{
    return EncodeToBitsFromUint(UINTVALUE(value * DATA_MAXVALUE + 0.5), uv);
}

float4 EncodeFromFloat(FLOATVALUE value, float2 uv)
{
    return ComponentSeparatedFromBits(EncodeToBitsFromFloat(value, uv), uv);
}

float4 EncodeFromUint(UINTVALUE value, float2 uv)
{
    return ComponentSeparatedFromBits(EncodeToBitsFromUint(value, uv), uv);
}

UINTVALUE DecodeToUint(float2 uv)
{
    uint2 pixelCoord = EncodedDataBlockPixelCoord(uv);
    uint2 blockCoord = DataBlockCoord(pixelCoord);
    UINTVALUE value = uint4(0, 0, 0, 0);
    for (uint x = 0; x < DATABLOCK_X; ++x)
    {
        for (uint y = 0; y < DATABLOCK_Y; ++y)
        {
            uint2 subPixelCoord = uint2(x, y);
            uint bitIndex = (x + y * DATABLOCK_X) * BIT_PER_DATABLOCK_PIXEL;
            FLOATVALUE color = ComponentBlockPixelColor(blockCoord + subPixelCoord);
            value = value | (UINTVALUE(color * DATABLOCK_PIXEL_MAXVALUE + 0.5) << bitIndex);
        }
    }
    // return uint4(pixelCoord / _MainTex_TexelSize.zw / DATABLOCK, 0, 1);
    return value;
}

FLOATVALUE DecodeToFloat(float2 uv)
{
    return FLOATVALUE(DecodeToUint(uv)) / DATA_MAXVALUE;
}

#endif
