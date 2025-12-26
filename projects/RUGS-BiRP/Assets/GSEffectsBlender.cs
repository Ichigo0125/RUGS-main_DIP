using UnityEngine;
using GaussianSplatting.Runtime;

[ExecuteAlways] // 讓你在編輯器不用按 Play 也能預覽效果
public class GSEffectsBlender : MonoBehaviour
{
    [Header("目標組件")]
    public GSEffects targetEffects; // 拖曳你的 GSEffects_Manager 物件

    [Header("狀態設定")]
    [Tooltip("動畫開始時的曲線 (調整前)")]
    public AnimationCurve startCurve = AnimationCurve.Linear(0, 0, 1, 1);

    [Tooltip("動畫結束時的曲線 (調整後)")]
    public AnimationCurve endCurve = AnimationCurve.Linear(0, 0, 1, 1);

    [Header("動畫控制")]
    [Range(0f, 1f)]
    [Tooltip("0 = 使用開始曲線, 1 = 使用結束曲線")]
    public float transition = 0f;

    private void Update()
    {
        if (targetEffects == null) return;

        // 即時計算混合
        BlendAndApply();
    }

    void BlendAndApply()
    {
        // 確保貼圖存在
        if (targetEffects.colorCurveTex == null)
        {
            targetEffects.ManualUpdate(); // 強制初始化
        }

        Texture2D tex = targetEffects.colorCurveTex as Texture2D;
        if (tex == null) return;

        // 逐像素混合兩條曲線
        for (int i = 0; i < 256; i++)
        {
            float t = i / 255f;

            // 取樣兩條曲線
            float valueStart = Mathf.Clamp01(startCurve.Evaluate(t));
            float valueEnd = Mathf.Clamp01(endCurve.Evaluate(t));

            // 線性插值 (Lerp)
            float finalValue = Mathf.Lerp(valueStart, valueEnd, transition);

            tex.SetPixel(i, 0, new Color(finalValue, 0, 0, 1));
        }
        tex.Apply();
    }
}