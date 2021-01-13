#pragma target 2.0

#include "Lighting.cginc"
#include "UnityCG.cginc"

struct v2f
{
    float4 pos: SV_POSITION;
    half4 uv: TEXCOORD0;
    float3 worldNormal: TEXCOORD1;
    float3 worldPos: TEXCOORD2;
    half3 tspace2 : TEXCOORD3; // tangent.z, bitangent.z, normal.z
    half3 binormal : TEXCOORD4;
};

fixed4 _Color;
fixed4 _Specular;
fixed4 _FurColor;
half _Shininess;

sampler2D _MainTex;
sampler2D _BumpMap;
sampler2D _FlowMap;
uniform float4 _BumpMap_ST;
uniform float _BumpDepth;
half4 _MainTex_ST;
sampler2D _FurTex;
half4 _FurTex_ST;

fixed _FurLength;
fixed _FurDensity;
fixed _FurThinness;
fixed _FurShading;
//fixed _FurShading;
half _FurShadeStep;
float _Smooth;

float4 _ForceGlobal;
float4 _ForceLocal;

fixed4 _RimColor;
half _RimPower;


v2f vert_surface(appdata_base v)
{
    v2f o;
    o.pos = UnityObjectToClipPos(v.vertex);
    o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
    o.worldNormal = UnityObjectToWorldNormal(v.normal);
    o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

    return o;
}

v2f vert_base(appdata_full v)
{
    v2f o;

    o.worldPos = normalize( mul( float4( v.normal, 0.0 ), unity_WorldToObject ).xyz );
    o.tspace2 = normalize( mul( unity_ObjectToWorld, v.tangent ).xyz );
    o.binormal = normalize( cross( o.worldPos, o.tspace2));


    float3 P = v.vertex.xyz + v.normal * _FurLength * FURSTEP;
    P += clamp(mul(unity_WorldToObject, _ForceGlobal).xyz + _ForceLocal.xyz, -1, 1) * pow(FURSTEP, 3) * _FurLength;
    o.pos = UnityObjectToClipPos(float4(P, 1.0));
    o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
    o.uv.zw = TRANSFORM_TEX(v.texcoord, _FurTex);
    o.worldNormal = UnityObjectToWorldNormal(v.normal);
    o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

    return o;
}

fixed4 frag_surface(v2f i): SV_Target
{
    
    fixed3 worldNormal = normalize(i.worldNormal);
    fixed3 worldLight = normalize(_WorldSpaceLightPos0.xyz);
    fixed3 worldView = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);
    fixed3 worldHalf = normalize(worldView + worldLight);
    
    fixed3 albedo = tex2D(_MainTex, i.uv.xy).rgb * _Color;
    fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;
    fixed3 diffuse = _LightColor0.rgb * albedo * saturate(dot(worldNormal, worldLight));
    fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(saturate(dot(worldNormal, worldHalf)), _Shininess);
    fixed3 color = ambient + diffuse + specular;
    return fixed4(color, 1);
}

fixed4 frag_base(v2f i): SV_Target
{
   //normal mapping 
    float3 viewDirection = normalize( _WorldSpaceCameraPos.xyz - i.worldNormal.xyz );
    float3 lightDirection;
    float atten;

        if( _WorldSpaceLightPos0.w == 0.0 ) { // Directional Light
            atten = 1.0;
            lightDirection = normalize( _WorldSpaceLightPos0.xyz );
        } else {
            float3 fragmentToLightSource = _WorldSpaceLightPos0.xyz - i.worldNormal.xyz;
            float distance = length( fragmentToLightSource );
            float atten = 1 / distance;
            lightDirection = normalize( fragmentToLightSource );
        }

    float4 texN = tex2D( _BumpMap, i.uv.xy * _BumpMap_ST.xy + _BumpMap_ST.zw );
    // unpackNormal Function
	float3 localCoords = float3(2.0 * texN.ag - float2(1.0,1.0), 0.0);
    localCoords.z = _BumpDepth;

      // Normal Transpose Matrix
    float3x3 local2WorldTranspose = float3x3(
        i.tspace2,
        i.binormal,
        i.worldPos
    );

    // Calculate Normal Direction
    float3 normalDirection = normalize( mul( localCoords, local2WorldTranspose ) );
    
    // Lighting
    float3 diffuseReflection = atten * _LightColor0.rgb * saturate( dot( normalDirection, lightDirection ) );
    float3 specularReflection = diffuseReflection * _Specular.rgb * pow( saturate( dot( reflect( -lightDirection, normalDirection ), viewDirection ) ), _Shininess);
    

    // Rim Lighting
    float _rim = 1 - saturate( dot( viewDirection, normalDirection ) );
    float3 rimLighting = saturate( pow( _rim, _RimPower ) * _RimColor.rgb * diffuseReflection);
    float3 lightFinal = diffuseReflection + specularReflection + rimLighting + UNITY_LIGHTMODEL_AMBIENT.rgb;
    
    float2 t = float2(0, _Time.y * .03);
    float2 disp = tex2D(_FlowMap, i.uv + t).rg * 2 - 1;
    disp *= 5;
    float n = tex2D(_FlowMap, i.uv * float2(1, .1) + t + disp).r;
    n = round(n * 5) / 5;

    //rim 
    fixed3 worldNormal = normalize(i.worldNormal);
    fixed3 worldLight = normalize(_WorldSpaceLightPos0.xyz);
    fixed3 worldView = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);
    fixed3 worldHalf = normalize(worldView + worldLight);

    fixed3 albedo = tex2D(_MainTex, i.uv.xy).rgb * _FurColor;
    albedo -= (pow(1 - FURSTEP, 3)) * _FurShading;
    half rim = 1 - saturate(dot(worldLight, worldNormal));
    albedo += fixed4(_RimColor.rgb * pow(rim, _RimPower), 1);

    fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;
    fixed3 diffuse = _LightColor0.rgb * albedo * saturate(dot(worldNormal, worldLight));
    fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(saturate(dot(worldNormal, worldHalf)), _Shininess);

    fixed3 color = ambient + diffuse + specular;//  + n;// + lightFinal * n;
    fixed3 noise = tex2D(_FurTex, i.uv.zw * _FurThinness).rgb * smoothstep(color,0,_Smooth);
    fixed alpha = clamp(noise - (FURSTEP * FURSTEP) * _FurDensity, 0, 6) * smoothstep(noise,0,_Smooth); // * n;
    return fixed4(color, alpha);
}