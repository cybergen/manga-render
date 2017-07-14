// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Brian/HalftoneStrip"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_HalfToneStrip ("Halftone Strip", 2D) = "white" {}
		_LowThreshold ("Low Threshold", float) = 1
		_HighThreshold ("High Threshold", float) = 2
		_RepeatCount ("Hafltone Repeat Count", float) = 40
		_LowColor ("Low Color", Color) = (0, 0, 0, 1)
		_HighColor ("High Color", Color) = (1, 1, 1, 1)
	}
	SubShader
	{
		// No culling or depth
		Cull Off ZWrite Off ZTest Always

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
				float2 uv[4] : TEXCOORD0;
				float4 vertex : SV_POSITION;
				float4 screenPosition : TEXCOORD5;
			};
			
			sampler2D _MainTex;
			sampler2D _CameraDepthNormalsTexture;
			float4 _MainTex_TexelSize;

			sampler2D _HalfToneStrip;
			float4 _HalfToneStrip_TexelSize;

			float _LowThreshold;
			float _HighThreshold;
			float _RepeatCount;

			float4 _LowColor;
			float4 _HighColor;

			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.screenPosition = ComputeScreenPos(o.vertex);
				float2 uv = v.uv;
				o.uv[0] = v.uv;
				o.uv[1] = uv;
				o.uv[2] = uv + float2(-_MainTex_TexelSize.x, -_MainTex_TexelSize.y);
				o.uv[3] = uv + float2(_MainTex_TexelSize.x, - _MainTex_TexelSize.y);
				return o;
			}

			inline half CheckSame (half2 centerNormal, float centerDepth, half4 sample)
			{
			  // difference in normals
			  // do not bother decoding normals - there's no need here
			  half2 diff = abs(centerNormal - sample.xy);
			  half isSameNormal = (diff.x + diff.y) < 0.1;
			  // difference in depth
			  float sampleDepth = DecodeFloatRG(sample.zw);
			  float zdiff = abs(centerDepth-sampleDepth);
			  // scale the required threshold by the distance
			  half isSameDepth = zdiff < 0.09 * centerDepth;
			  // return:
			  // 1 - if normals and depth are similar enough
			  // 0 - otherwise
			  return isSameNormal * isSameDepth;
			}

			fixed4 frag (v2f i) : SV_Target
			{
				float4 original = tex2D(_MainTex, i.uv[0]);
				
				//Get adjusted screenspace uv/////////////////////////////
				//float uvX = _ScreenParams.x * i.screenPosition.x;
				float uvY = _ScreenParams.y * i.screenPosition.y;
				//////////////////////////////////////////////////////////

				//Get camera depth samples/////////////////////////////
  				half4 center = tex2D(_CameraDepthNormalsTexture, i.uv[1]);
				half4 sample1 = tex2D(_CameraDepthNormalsTexture, i.uv[2]);
				half4 sample2 = tex2D(_CameraDepthNormalsTexture, i.uv[3]);

				// encoded normal
				half2 centerNormal = center.xy;
				// decoded depth
				float centerDepth = DecodeFloatRG(center.zw);

				half firstSampleDepth = CheckSame(centerNormal, centerDepth, sample1);
				half secondSampleDepth = CheckSame(centerNormal, centerDepth, sample2);
				//////////////////////////////////////////////////////////

				//Get total luminosity
				float luminosity = original.r + original.g + original.b;

				//Calculate color fragment at differing luminosity levels
				float uvX = smoothstep(_LowThreshold, _HighThreshold, luminosity);
				//uvX = _ScreenParams.x * i.screenPosition.x * _HalfToneStrip_TexelSize.x * _RepeatCount;
				float4 halfStrip = tex2D(_HalfToneStrip, float2(uvX, uvY * _HalfToneStrip_TexelSize.y * _RepeatCount));
				//////////////////////////////////////////////////////////

				if (luminosity < _LowThreshold) 
				{
					original = _LowColor;
					if (firstSampleDepth < 1 || secondSampleDepth < 1)
					{
						original = _HighColor;
					}
					return original;
				}
				else if (luminosity < _HighThreshold)
				{
					original = halfStrip;
				}				
				else original = _HighColor;
				  		
				if (firstSampleDepth < 1 || secondSampleDepth < 1)
				{
					original = _LowColor;
				}
				    
				return original;
			}
			ENDCG
		}
	}
}
