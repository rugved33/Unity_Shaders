//1. Transparent
//2. Rim
//3. Intersection Highlight
Shader "Custom/ForceField"
{
	Properties
	{
		_MainColor("Main Color", Color) = (1,1,1,1)
		_MainTex ("Texture", 2D) = "white" { }
		_RimPower("Rim Power", Range(0, 2)) = 1
		_IntersectionPower("Intersect Power", Range(0, 2)) = 0
        _BackGround("backGround", Color) = (1,1,1,1)
		_ScrollSpeed("Scoll Speed", Range(0, 100)) = 1
	}
	SubShader
	{
		Tags { "Queue"="Transparent" "RenderType"="Transparent" }

		Pass
		{
            //Cull Off
			ZWrite Off
			Blend SrcAlpha OneMinusSrcAlpha

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float3 normal : NORMAL;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float3 worldNormal : TEXCOORD0;
				float3 worldViewDir : TEXCOORD1;
				float4 screenPos : TEXCOORD2;
				float eyeZ : TEXCOORD3;
				float2 uv : TEXCOORD4;
			};

			sampler2D _CameraDepthTexture;
			fixed4 _MainColor;
			float _RimPower;
			float _IntersectionPower;

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				float4 worldPos = mul(unity_ObjectToWorld, v.vertex);
				o.worldNormal = UnityObjectToWorldDir(v.normal);
				o.worldViewDir = UnityWorldSpaceViewDir(worldPos);
				o.screenPos = ComputeScreenPos(o.vertex);
				COMPUTE_EYEDEPTH(o.eyeZ);
				o.uv = v.uv;
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				float3 worldNormal = normalize(i.worldNormal);
				float3 worldViewDir = normalize(i.worldViewDir);
				float rim = 1 - saturate(dot(worldNormal, worldViewDir)) * _RimPower;

				float screenZ = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(i.screenPos)));	
				float intersect = (1 - (screenZ - i.eyeZ)) * _IntersectionPower;
				float v = max (rim, intersect);

				return _MainColor * v;
			}
			ENDCG
		}

        Pass {

          
            Cull Front
      
         
            Blend SrcAlpha OneMinusSrcAlpha
			//Blend One One

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float3 normal : NORMAL;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float3 worldNormal : TEXCOORD0;
				float3 worldViewDir : TEXCOORD1;
				float4 screenPos : TEXCOORD2;
				float eyeZ : TEXCOORD3;
				float2 uv : TEXCOORD4;
			};

			sampler2D _CameraDepthTexture;
			sampler2D _MainTex;
			fixed4 _MainColor;
            fixed4 _BackGround;
			float _RimPower;
			float _ScrollSpeed;
			float _IntersectionPower;

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				float4 worldPos = mul(unity_ObjectToWorld, v.vertex);
				o.worldNormal = UnityObjectToWorldDir(v.normal);
				o.worldViewDir = UnityWorldSpaceViewDir(worldPos);
				o.screenPos = ComputeScreenPos(o.vertex);
				COMPUTE_EYEDEPTH(o.eyeZ);
				o.uv = v.uv;
				o.uv.y += _Time.x * _ScrollSpeed;
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				fixed4 albedo = tex2D(_MainTex, i.uv);
				float3 worldNormal = normalize(i.worldNormal);
				float3 worldViewDir = normalize(i.worldViewDir);
				float rim = 1 - saturate(dot(worldNormal, worldViewDir)) * _RimPower;

				float screenZ = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(i.screenPos)));	
				float intersect = (1 - (screenZ - i.eyeZ)) * _IntersectionPower;
				float v = max (rim, intersect);
				fixed4 col = _BackGround * albedo;

				return col * v ;
			}
			ENDCG
       }
	}
}
