using UnityEngine;

[ExecuteInEditMode]
public class CameraEffectApplier : MonoBehaviour
{
    public Material MangaMaterial;
    public Camera Camera;

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        Camera.depthTextureMode = DepthTextureMode.DepthNormals;
        Graphics.Blit(source, destination, MangaMaterial);
    }
}
