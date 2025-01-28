using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class DrawOnPlaneWithRotation : MonoBehaviour
{
    public Material Material;
    public RenderTexture DrawTexture;
    private RenderTexture Buffer;
    public Camera mainCamera;

    [Range(0, 1)] public float DrawFrequency;
    private float NextDrawTime;

    private Vector2 lastTextureCoord;
    private bool hasLastCoord = false;
    
    void Start()
    {
        if (!mainCamera)
            mainCamera = Camera.main;

        Buffer = new RenderTexture(DrawTexture.width, DrawTexture.height, DrawTexture.depth, DrawTexture.format);

        InitializeRenderTextureToGray(DrawTexture);

        Graphics.Blit(DrawTexture, Buffer, Material);
        Graphics.Blit(Buffer, DrawTexture);
    }

    private void InitializeRenderTextureToGray(RenderTexture renderTexture)
    {
        RenderTexture previousActive = RenderTexture.active;
        RenderTexture.active = renderTexture;
        GL.Clear(false, true, Color.gray);
        RenderTexture.active = previousActive;
    }

    private void Draw(Vector2 screenPosition)
    {
        var ray = mainCamera.ScreenPointToRay(screenPosition);
        RaycastHit hitInfo;

        if (Physics.Raycast(ray, out hitInfo))
        {
            Vector2 currentTextureCoord = hitInfo.textureCoord;

            if (hasLastCoord)
            {
                Vector2 delta = currentTextureCoord - lastTextureCoord;

                if (delta.sqrMagnitude < 0.00004f)
                {
                    return;
                }

                float angle = Mathf.Atan2(-delta.y, delta.x) * Mathf.Rad2Deg;

                if (angle < 0) angle += 360;

                Material.SetFloat("_BrushAngle", angle);
            }

            lastTextureCoord = currentTextureCoord;
            hasLastCoord = true;

            Material.SetVector("_PaintUV", currentTextureCoord);

            Graphics.Blit(DrawTexture, Buffer, Material);
            Graphics.Blit(Buffer, DrawTexture);
        }
    }

    private bool lastMouseValue = false;

    void Update()
    {
        if (Input.touchCount > 0)
        {
            Touch touch = Input.GetTouch(0);

            if (touch.phase == TouchPhase.Began || touch.phase == TouchPhase.Moved ||
                touch.phase == TouchPhase.Stationary)
            {
                if (lastMouseValue && Time.time < this.NextDrawTime)
                    return;

                Draw(touch.position);
                lastMouseValue = true;
                this.NextDrawTime = Time.time + this.DrawFrequency;
            }
            else if (touch.phase == TouchPhase.Ended || touch.phase == TouchPhase.Canceled)
            {
                lastMouseValue = false;
                hasLastCoord = false;
            }
        }
        else
        {
            if (Input.GetMouseButton(0))
            {
                if (lastMouseValue && Time.time < this.NextDrawTime)
                    return;

                Draw(Input.mousePosition);
                lastMouseValue = true;
                this.NextDrawTime = Time.time + this.DrawFrequency;
            }
            else
            {
                lastMouseValue = false;
                hasLastCoord = false;
            }
        }
    }
}
