Shader "Toon/Basic/MultiSteps"
{
    Properties
    {
        // Colors
       [PerRendererData]_Color ("Color", Color) = (1, 1, 1, 1)
        _HColor ("Highlight Color", Color) = (0.8, 0.8, 0.8, 1.0)
        _SColor ("Shadow Color", Color) = (0.2, 0.2, 0.2, 1.0)
        
        // texture
        _MainTex ("Main Texture", 2D) = "white" { }
        
        // ramp
        _ToonSteps ("Steps of Toon", range(1, 9)) = 2
        _RampThreshold ("Ramp Threshold", Range(0.1, 1)) = 0.5
        _RampSmooth ("Ramp Smooth", Range(0, 1)) = 0.1
        
        // specular
        _SpecColor ("Specular Color", Color) = (0.5, 0.5, 0.5, 1)
        _SpecSmooth ("Specular Smooth", Range(0, 1)) = 0.1
        _Shininess ("Shininess", Range(0.001, 10)) = 0.2
        
        // rim light
        _RimColor ("Rim Color", Color) = (0.8, 0.8, 0.8, 0.6)
        _RimThreshold ("Rim Threshold", Range(0, 1)) = 0.5
        _RimSmooth ("Rim Smooth", Range(0, 1)) = 0.1

       // _DissolveTexture("Dissolve texture", 2D) = "white" {}
        _Radius("Distance", Float) = 1 //distance where we start to reveal the objects

        _NoiseTex("Dissolve Noise", 2D) = "white"{} 
        _NScale ("Noise Scale", Range(0, 10)) = 1 

        _DisLineWidth("Line Width", Range(0, 2)) = 0 
        _DisLineColor("Line Tint", Color) = (1,1,1,1)  
        _DisAmount("Noise Texture Opacity", Range(0.01, 1)) = 0       
    }
    
    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        Cull off
        LOD 200
        CGPROGRAM
        
        #pragma surface surf Toon addshadow fullforwardshadows exclude_path:deferred exclude_path:prepass
        #pragma target 3.0
        
        fixed4 _Color;
        fixed4 _HColor;
        fixed4 _SColor;
        
        sampler2D _MainTex;
        sampler2D _NoiseTexture;
        
        float _RampThreshold;
        float _RampSmooth;
        float _ToonSteps;
        
        float _SpecSmooth;
        fixed _Shininess;
        float _DisAmount;
        
        fixed4 _RimColor;
        fixed _RimThreshold;
        float _RimSmooth;

        float3 _PlayerPos; //"Global Shader Variable", contains the Player Position
		float _Radius; 
        sampler2D _DissolveTexture; 
        float _Rad; 

        sampler2D _NoiseTex;
        float _NScale;
        float _DisLineWidth;
        float4 _DisLineColor;
        
        struct Input
        {
            float2 uv_MainTex;
            float3 viewDir;
            float3 worldPos;
            float3 worldNormal;
        };
        
        float linearstep(float min, float max, float t)
        {
            return saturate((t - min) / (max - min));
        }
        
        inline fixed4 LightingToon(SurfaceOutput s, half3 lightDir, half3 viewDir, half atten)
        {
            half3 normalDir = normalize(s.Normal);
            half3 halfDir = normalize(lightDir + viewDir);
            
            float ndl = max(0, dot(normalDir, lightDir));
            float ndh = max(0, dot(normalDir, halfDir));
            float ndv = max(0, dot(normalDir, viewDir));
            
            // multi steps
            float diff = smoothstep(_RampThreshold - ndl, _RampThreshold + ndl, ndl);
            float interval = 1 / _ToonSteps;
            // float ramp = floor(diff * _ToonSteps) / _ToonSteps;
            float level = round(diff * _ToonSteps) / _ToonSteps;
            float ramp ;
            if (_RampSmooth == 1)
            {
                ramp = interval * linearstep(level - _RampSmooth * interval * 0.5, level + _RampSmooth * interval * 0.5, diff) + level - interval;
            }
            else
            {
                ramp = interval * smoothstep(level - _RampSmooth * interval * 0.5, level + _RampSmooth * interval * 0.5, diff) + level - interval;
            }
            ramp = max(0, ramp);
            ramp *= atten;
            
            _SColor = lerp(_HColor, _SColor, _SColor.a);
            float3 rampColor = lerp(_SColor.rgb, _HColor.rgb, ramp);
            
            // specular
            float spec = pow(ndh, s.Specular * 128.0) * s.Gloss;
            spec *= atten;
            spec = smoothstep(0.5 - _SpecSmooth * 0.5, 0.5 + _SpecSmooth * 0.5, spec);
            
            // rim
            float rim = (1.0 - ndv) * ndl;
            rim *= atten;
            rim = smoothstep(_RimThreshold - _RimSmooth * 0.5, _RimThreshold + _RimSmooth * 0.5, rim);
            
            fixed3 lightColor = _LightColor0.rgb;
            
            fixed4 color;
            fixed3 diffuse = s.Albedo * lightColor * rampColor;
            fixed3 specular = _SpecColor.rgb * lightColor * spec;
            fixed3 rimColor = _RimColor.rgb * lightColor * _RimColor.a * rim;
            
            color.rgb = diffuse + specular + rimColor;
            color.a = s.Alpha;
            return color;
        }
        
        void surf(Input IN, inout SurfaceOutput o)
        {

            half dissolve_value = tex2D(_NoiseTexture, IN.uv_MainTex).x;


            float3 blendNormal = saturate(pow(IN.worldNormal * 1.4,4));
            half4 nSide1 = tex2D(_NoiseTex, (IN.worldPos.xy + _Time.x) * _NScale); 
            half4 nSide2 = tex2D(_NoiseTex, (IN.worldPos.xz + _Time.x) * _NScale);
            half4 nTop = tex2D(_NoiseTex, (IN.worldPos.yz + _Time.x) * _NScale);
            
            float3 noisetexture = nSide1;
            noisetexture = lerp(noisetexture, nTop, blendNormal.x);
            noisetexture = lerp(noisetexture, nSide2, blendNormal.y);
 
            //clipping
            float dist = distance(_PlayerPos, IN.worldPos);

            float3 sphereR = 1 - saturate(dist / _Rad);

            float3 sphereRNoise = noisetexture * sphereR.r;

	        float3 DissolveLineIn = step(sphereRNoise- _DisLineWidth, _DisAmount);

            float3 NoDissolve = float3(1, 1, 1) - DissolveLineIn ;

           // clip(dissolve_value - dist/ _Rad);
            half4 c = tex2D(_MainTex, IN.uv_MainTex) * _HColor;
            c.rgb = (DissolveLineIn * _DisLineColor) + (NoDissolve * c.rgb);

            fixed4 mainTex = tex2D(_MainTex, IN.uv_MainTex);
            c.a = step(_DisAmount, sphereRNoise);

            o.Albedo = mainTex.rgb * _Color.rgb;
            // o.Albedo = c.rgb;// * _Color.rgb;
            //o.Alpha = mainTex.a * _Color.a;
            o.Alpha = c.a;
          
           // o.Specular = _Shininess;
           // o.Gloss = mainTex.a;
        }
        
        ENDCG
        
    }
    FallBack "Diffuse"
}
