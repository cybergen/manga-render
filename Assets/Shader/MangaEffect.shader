// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Brian/Manga"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_HalfToneOne ("Halftone One", 2D) = "white" {}
		_HalfToneTwo ("Halftone Two", 2D) = "white" {}
		_ThresholdOne ("Threshold One", float) = 1
		_ThresholdTwo ("Threshold Two", float) = 2
		_ThresholdThree ("Threshold Three", float) = 3
		_RepeatCount ("Hafltone Repeat Count", float) = 40
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
			sampler2D _HalfToneOne;
			float4 _HalfToneOne_TexelSize;
			sampler2D _HalfToneTwo;
			float4 _HalfToneTwo_TexelSize;
			float _ThresholdOne;
			float _ThresholdTwo;
			float _ThresholdThree;
			float _HalftoneSideLength;
			float _RepeatCount;

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
				half4 original = tex2D(_MainTex, i.uv[0]);
				
				float uvX = _ScreenParams.x * i.screenPosition.x;
				float uvY = _ScreenParams.y * i.screenPosition.y;

				float luminosity = original.r + original.g + original.b;
				if (luminosity < _ThresholdOne) original = half4(0, 0, 0, 1);
				else if (luminosity < _ThresholdTwo) original = tex2D(_HalfToneOne, float2(uvX * _HalfToneOne_TexelSize.x * _RepeatCount, uvY * _HalfToneOne_TexelSize.y * _RepeatCount));
				else if (luminosity < _ThresholdThree) original = tex2D(_HalfToneTwo, float2(uvX * _HalfToneTwo_TexelSize.x * _RepeatCount, uvY * _HalfToneTwo_TexelSize.y * _RepeatCount));
				else original = half4(1, 1, 1, 1);
				//half4 original = half4(1, 1, 1, 1);
  
				half4 center = tex2D(_CameraDepthNormalsTexture, i.uv[1]);
				half4 sample1 = tex2D(_CameraDepthNormalsTexture, i.uv[2]);
				half4 sample2 = tex2D(_CameraDepthNormalsTexture, i.uv[3]);
				  
				// encoded normal
				half2 centerNormal = center.xy;
				// decoded depth
				float centerDepth = DecodeFloatRG (center.zw);
				  
				original *= CheckSame(centerNormal, centerDepth, sample1);
				original *= CheckSame(centerNormal, centerDepth, sample2);
				    
				return original;
			}
			ENDCG
		}
	}
}
