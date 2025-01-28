using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class TextureProcessor : MonoBehaviour
{

    public Texture InitialTexture;
    public Material material;
    
    public RenderTexture texture;
    public float updateInterval = 0.1f; 
    private RenderTexture buffer;
    
    
    private float nextUpdateTime = 0;
    void Start()
    {
        Graphics.Blit(InitialTexture,texture);
        buffer = new RenderTexture(texture.width,texture.height,texture.depth,texture.format);
        nextUpdateTime = 0;
    }
    
    void Update()
    {
        if(Time.time > nextUpdateTime){
            UpdateTexture();
            nextUpdateTime = Time.time + updateInterval;
        }
    }

    private void UpdateTexture()
    {
        Graphics.Blit(texture,buffer,material);
        Graphics.Blit(buffer,texture);
    }
}
