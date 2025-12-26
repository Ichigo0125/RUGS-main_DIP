using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;


namespace GaussianSplatting.Runtime
{
	[CustomEditor(typeof(GSEffects))]
	public class GSEffectsEditor : Editor
	{
		public override void OnInspectorGUI()
		{
			DrawDefaultInspector();

			GSEffects captureScript = (GSEffects)target;

			if (GUILayout.Button("Update"))
			{
				captureScript.ManualUpdate();
			}
		}
	}

	public class GSEffects : MonoBehaviour
	{
		public AnimationCurve colorCurve = AnimationCurve.Linear(0, 0, 1, 1);
		[HideInInspector] public Texture colorCurveTex;

		public AnimationCurve roughnessCurve = AnimationCurve.Linear(0, 0, 1, 1);
		[HideInInspector] public Texture roughnessCurveTex;

		public AnimationCurve metallicCurve = AnimationCurve.Linear(0, 0, 1, 1);
		[HideInInspector] public Texture metallicCurveTex;

		Texture2D GenerateCurveTexture(AnimationCurve curve)
		{
			// 1. 改用 RGBAHalf (或是 RGBAFloat)
			Texture2D tex = new Texture2D(256, 1, TextureFormat.RGBAHalf, false, true);
			tex.wrapMode = TextureWrapMode.Clamp;
			
			Color[] cols = new Color[256];
			for (int i = 0; i < 256; i++)
			{
				float input = i / 255f;
				float value = Mathf.Clamp01(curve.Evaluate(input));
				
				// 2. 關鍵修正：(value, value, value, 1) 
				// 讓 RGB 都是同一個亮度，這樣才會是正常的色彩濾鏡
				cols[i] = new Color(value, value, value, 1f); 
			}
			tex.SetPixels(cols);
			tex.Apply();
			return tex;
		}

		public void ManualUpdate()
		{
			colorCurveTex = GenerateCurveTexture(colorCurve);
			roughnessCurveTex = GenerateCurveTexture(roughnessCurve);
			metallicCurveTex = GenerateCurveTexture(metallicCurve);
		}

        private void OnValidate()
        {
            ManualUpdate();
        }

		void OnEnable()
		{
			ManualUpdate();
		}
	}
}
