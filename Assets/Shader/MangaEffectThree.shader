// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Brian/MangaThree"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_HalfToneOne ("Halftone One", 2D) = "white" {}
		_HalfToneTwo ("Halftone Two", 2D) = "white" {}
		_HalfToneThree ("Halftone Two", 2D) = "white" {}
		_ThresholdOne ("Threshold One", float) = 1
		_ThresholdTwo ("Threshold Two", float) = 2
		_ThresholdThree ("Threshold Three", float) = 3
		_ThresholdFour ("Threshold Three", float) = 3
		_RepeatCount ("Hafltone Repeat Count", float) = 40
		_BlackReplace ("Black Replace", Color) = (0, 0, 0, 1)
		_BlackCloseReplace ("Black Close Replace", Color) = (0, 0, 0, 1)
		_WhiteReplace ("White Replace", Color) = (1, 1, 1, 1)
		_HalfToneBlackReplace ("Halftone Black Replace", Color) = (1, 1, 1, 1)
		_HalfToneWhiteReplace ("Halftone White Replace", Color) = (1, 1, 1, 1)
		_EdgeColor ("Edge Color", Color) = (1, 1, 1, 1)
		_BlackFadeEndDistance ("Black Fade End", float) = 1

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
			sampler2D _HalfToneThree;
			float4 _HalfToneThree_TexelSize;
			float _ThresholdOne;
			float _ThresholdTwo;
			float _ThresholdThree;
			float _ThresholdFour;
			float _RepeatCount;
			float _BlackFadeEndDistance;

			float4 _BlackReplace;
			float4 _BlackCloseReplace;
			float4 _WhiteReplace;
			float4 _HalfToneWhiteReplace;
			float4 _HalfToneBlackReplace;
			float4 _EdgeColor;

			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.screenPosition = ComputeScreenPos(o.vertex);
				float2 uv = v.uv;
				o.uv[0] = v.uv;
				o.uv[1] = uv;
				o.uv[2] = uv + float2(-_MainTex_TexelSize.x, -_MainTex_TexelSize.y);
				o.uv[3] = uv + float2(_MainTex_TexelSize.x, _MainTex_TexelSize.y);
				return o;
			}

			inline half CheckSameNormalAndDepth(half2 centerNormal, float centerDepth, half4 sample)
			{
			  // difference in normals
			  // do not bother decoding normals - there's no need here
			  half2 diff = abs(centerNormal - sample.xy);
			  half isSameNormal = (diff.x + diff.y) < 0.1;
			  // difference in depth
			  float sampleDepth = DecodeFloatRG(sample.zw);
			  float zdiff = abs(centerDepth-sampleDepth);
			  // scale the required threshold by the distance
			  half isSameDepth = zdiff < 0.2 * centerDepth;
			  // return:
			  // 1 - if normals and depth are similar enough to not need outline
			  // 0 - otherwise
			  return isSameNormal * isSameDepth;
			}

			inline half GetDepth(half2 xy, float2 uv[4])
			{
				half4 center = tex2D(_CameraDepthNormalsTexture, uv[1]);
				return DecodeFloatRG(center.zw);
			}

			inline int CheckEdge(float2 xy, float2 uv[4])
			{
				//Get camera depth samples/////////////////////////////
  				half4 center = tex2D(_CameraDepthNormalsTexture, uv[1]);
				half4 sample1 = tex2D(_CameraDepthNormalsTexture, uv[2]);
				half4 sample2 = tex2D(_CameraDepthNormalsTexture, uv[3]);

				// encoded normal
				half2 centerNormal = center.xy;
				// decoded depth
				float centerDepth = DecodeFloatRG(center.zw);

				half firstSampleDepth = CheckSameNormalAndDepth(centerNormal, centerDepth, sample1);
				firstSampleDepth *= CheckSameNormalAndDepth(centerNormal, centerDepth, sample2);
				return firstSampleDepth < 1;
				//////////////////////////////////////////////////////////
			}

			fixed4 frag (v2f i) : SV_Target
			{
				float4 original = tex2D(_MainTex, i.uv[0]);				

				//Get total luminosity
				float luminosity = original.r + original.g + original.b;

				//Get current screen position against halftone textures				
				float uvX = _ScreenParams.x * i.screenPosition.x;
				float uvY = _ScreenParams.y * i.screenPosition.y;
				//////////////////////////////////////////////////////////

				//Get Center depth
				half depth = GetDepth(float2(uvX, uvY), i.uv);
				//////////////////////////////////////////////////////////

				//Calculate color fragment at differing luminosity levels
				float4 black = lerp(_BlackCloseReplace, _BlackReplace, depth / _BlackFadeEndDistance);
				float4 halfOne = tex2D(_HalfToneOne, float2(uvX * _HalfToneOne_TexelSize.x * _RepeatCount, uvY * _HalfToneOne_TexelSize.y * _RepeatCount));
				float4 halfTwo = tex2D(_HalfToneTwo, float2(uvX * _HalfToneTwo_TexelSize.x * _RepeatCount, uvY * _HalfToneTwo_TexelSize.y * _RepeatCount));
				float4 halfThree = tex2D(_HalfToneThree, float2(uvX * _HalfToneThree_TexelSize.x * _RepeatCount, uvY * _HalfToneThree_TexelSize.y * _RepeatCount));
				float4 white = _WhiteReplace;
				//////////////////////////////////////////////////////////

				//Determine if we are an edge or if we are proximal to an edge
				// if (CheckEdge(float2(uvX, uvY), i.uv))
				// {
				// 	return _EdgeColor;
				// }
				//////////////////////////////////////////////////////////


				if (luminosity < _ThresholdFour)
				{				
					if (luminosity < _ThresholdOne) 
					{
						original = black;
						return original;
					}
					else if (luminosity < _ThresholdTwo) 
					{
						original = halfOne;
					}
					else if (luminosity < _ThresholdThree) 
					{
						original = halfTwo;
					}
					else
					{
						original = halfThree;
					}
					if (original.r == 0)
					{
						original += _HalfToneBlackReplace;
					}
					else
					{
						original *= _HalfToneWhiteReplace;
					}
					return original;
				}
				else original = white;
				    
				return original;
			}
			ENDCG
		}
	}
}
