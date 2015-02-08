uint MAKEFOURCC(uint ch0, uint ch1, uint ch2, uint ch3)
{
    return ch0 | (ch1 << 8) | (ch2 << 16) | (ch3 << 24);
}


const uint D3DFMT_A8B8G8R8 = 32;
const uint D3DFMT_DXT5 = MAKEFOURCC('D', 'X', 'T', '5');
const uint D3DFMT_A8R8G8B8 = 21;

class LuxProbe : ScriptObject
{
    Vector3 ProbeRotation;
    Node@ ZoneNode;
    int ViewMask = -1;
    Vector3 BoxSize = Vector3(5,5,5);

    private Node@ camNode_;
    private Camera@ camera_;
    private Viewport@ viewport_;
    private Viewport@ viewportRT;
    private Viewport@ oldViewport_;
    private Texture2D diffCube_;
    private Zone@ zone_;
    private uint captured = 0;
    private StaticModel@ model_;
    //private TextureCube specCube;

    private Matrix4 BoxMatrix;

    void Start()
    {
        //node.enabled = false;
        cache.autoReloadResources = true;

        //graphics.SetMode(1024, 1024);
        //Setup();
        //SetBoxMatrix();
    }

    void DelayedStart()
    {
        //Setup();
        //SubscribeToEvent("BeginFrame", "HandleRenderSurfaceUpdate");
    }

    void Update(float timeStep)
    {
        if (input.keyDown[KEY_SHIFT])
        {
            node.rotation = Quaternion(0, 0, 0);
        }
        //node.rotation = node.rotation * Quaternion(0, 15 * timeStep, 0);
        SetBoxMatrix();
    }

    void PrintMatrix(Matrix4 mat)
    {
        Print(" ");
        Print(String(mat.m00) + " " + String(mat.m01) + " " + String(mat.m02) + " " + String(mat.m03));
        Print(String(mat.m10) + " " + String(mat.m11) + " " + String(mat.m12) + " " + String(mat.m13));
        Print(String(mat.m20) + " " + String(mat.m21) + " " + String(mat.m22) + " " + String(mat.m23));
        Print(String(mat.m30) + " " + String(mat.m31) + " " + String(mat.m32) + " " + String(mat.m33));
    }

    void SetBoxMatrix()
    {
//         Matrix4 S;
//         S.SetScale(1);
//         Matrix4 R;
//         R.SetRotation(node.worldRotation.RotationMatrix());
//         Matrix4 T;
//         T.SetTranslation(node.worldPosition);
//         BoxMatrix = S * R * T;
        node.scale = BoxSize * 0.5f;
        BoxMatrix = node.worldTransform.ToMatrix4();
        //PrintMatrix(BoxMatrix);
        //PrintMatrix(BoxMatrix);
        //PrintMatrix(BoxMatrix.Inverse());
        Vector3 cubemapPos = node.worldPosition;
        Matrix4 cubemapTrans = BoxMatrix;
        Matrix4 cubemapInv = BoxMatrix.Inverse();

        Array<Drawable@>@ drawables = octree.GetDrawables(BoundingBox(-BoxSize, BoxSize), DRAWABLE_GEOMETRY);
        if (drawables is null)
        {
            return;
        }

        RenderPath@ renPath = renderer.viewports[0].renderPath;
        renPath.shaderParameters["CubemapPosition"] = Variant(cubemapPos);
        renPath.shaderParameters["CubemapSize"] = Variant(BoxSize * 0.5f);
        renPath.shaderParameters["CubeMatrixTrans"] = Variant(cubemapTrans);
        renPath.shaderParameters["CubeMatrixInv"] = Variant(cubemapInv);

        for (uint i = 0; i < drawables.length; i++)
        {

            if (drawables[i] is null)
            {
                continue;
            }
            Material@ mat;
            StaticModel@ smodel = drawables[i];
            AnimatedModel@ amodel = drawables[i];
            if (smodel !is null)
            {
                int j = 0;
                mat = smodel.materials[0];
                while (mat !is null)
                {
                    mat.shaderParameters["CubemapPosition"] = Variant(cubemapPos);
                    mat.shaderParameters["CubemapSize"] = Variant(BoxSize * 0.5f);
                    mat.shaderParameters["CubeMatrixTrans"] = Variant(cubemapTrans);
                    mat.shaderParameters["CubeMatrixInv"] = Variant(cubemapInv);
                    mat = smodel.materials[j++];
                }
            }
            else if (amodel !is null)
            {
                int j = 0;
                mat = amodel.materials[0];
                while (mat !is null)
                {
                    mat.shaderParameters["CubemapPosition"] = Variant(cubemapPos);
                    mat.shaderParameters["CubemapSize"] = Variant(BoxSize * 0.5f);
                    mat.shaderParameters["CubeMatrixTrans"] = Variant(cubemapTrans);
                    mat.shaderParameters["CubeMatrixInv"] = Variant(cubemapInv);
                    mat = amodel.materials[j++];
                }
            }
            else
            {
                continue;
            }
        }
    }

    void SetRenderPath(Viewport@ viewport)
    {
        if (renderer.hdrRendering)
        {
            RenderPath@ effectRenderPath = viewport.renderPath;// .Clone();
            effectRenderPath.Append(cache.GetResource("XMLFile", "PostProcess/EncodeHDR.xml"));
            effectRenderPath.SetEnabled("EncodeHDR", true);
        }
        //viewport.renderPath = effectRenderPath;
    }

    void HandleRenderSurfaceUpdate(StringHash eventType, VariantMap& eventData)
    {
        if (captured > 14)
        {
            return;
        }
        Image@ img = Image();
        String name = "Env_" + node.name + "_";

        switch (captured++)
        {
            case 0:
                camNode_.rotation = RotationOf(FACE_POSITIVE_X);
                break;
            case 2:
                camNode_.rotation = RotationOf(FACE_POSITIVE_Y);

                //diffCube_.SaveTGA("Data/" + name + "RenderPX.tga");
                break;
            case 4:
                camNode_.rotation = RotationOf(FACE_POSITIVE_Z);

                //diffCube_.SaveTGA("Data/" + name + "RenderPY.tga");
                break;
            case 6:
                camNode_.rotation = RotationOf(FACE_NEGATIVE_X);

                //diffCube_.SaveTGA("Data/" + name + "RenderPZ.tga");
                break;
            case 8:
                camNode_.rotation = RotationOf(FACE_NEGATIVE_Y);

                //diffCube_.SaveTGA("Data/" + name + "RenderNX.tga");
                break;
            case 10:
                camNode_.rotation = RotationOf(FACE_NEGATIVE_Z);

                //diffCube_.SaveTGA("Data/" + name + "RenderNY.tga");
                break;
            case 12:
                camNode_.rotation = RotationOf(FACE_POSITIVE_X);

                //diffCube_.SaveTGA("Data/" + name + "RenderNZ.tga");
                break;
            case 14:
                //renderer.viewports[0] = oldViewport_;
                break;
        }

    }

    Quaternion RotationOf(CubeMapFace face)
    {
        Quaternion result;
        switch (face)
        {
            //  Rotate camera according to probe rotation
            case FACE_POSITIVE_X:
                result = Quaternion(0 + ProbeRotation.x, 90 + ProbeRotation.y, 0 + ProbeRotation.z);
                break;
            case FACE_NEGATIVE_X:
                result = Quaternion(0 + ProbeRotation.x, -90 + ProbeRotation.y, 0 + ProbeRotation.z);
                break;
            case FACE_POSITIVE_Y:
                result = Quaternion(-90 + ProbeRotation.x, 0 + ProbeRotation.y, 0 + ProbeRotation.z);
                break;
            case FACE_NEGATIVE_Y:
                result = Quaternion(90 + ProbeRotation.x, 0 + ProbeRotation.y, 0 + ProbeRotation.z);
                break;
            case FACE_POSITIVE_Z:
                result = Quaternion(0 + ProbeRotation.x, 0 + ProbeRotation.y, 0 + ProbeRotation.z);
                break;
            case FACE_NEGATIVE_Z:
                result = Quaternion(0 + ProbeRotation.x, 180 + ProbeRotation.y, 0 + ProbeRotation.z);
                break;
        }
        return result;
    }

    void Setup()
    {
        camNode_ = node.GetChild("Camera");
        if (camNode_ is null)
        {
            camNode_ = node.CreateChild("Camera");
        }

        if (viewport_ is null)
        {
            viewport_ = Viewport();
        }

        camera_ = camNode_.GetOrCreateComponent("Camera");
        camNode_.rotation = RotationOf(FACE_POSITIVE_X);
        camera_.fov = 90;
        camera_.viewMask = ViewMask;

        viewport_.camera = camera_;
        viewport_.scene = scene;

        if (oldViewport_ is null)
        {
            oldViewport_ = renderer.viewports[0];
        }
        log.Info("Adding Render Target");
        //renderer.viewports[0] = viewport_;

        viewportRT = Viewport(scene, camera_);
        SetRenderPath(viewportRT);
//         RenderPath@ rp = viewportRT.renderPath.Clone();
//         RenderTargetInfo rti;
//         rti.name = "viewport";
//         rti.tag = "EncodeHDR";
//         rti.format = GetFloat16Format();
//         rti.size = Vector2(1, 1);
//         rti.sizeMode = SIZE_VIEWPORTMULTIPLIER;
//         rti.sRGB = false;
//
//         rp.renderTargets[0] = rti;
//         viewportRT.renderPath = rp;

        if (diffCube_ !is null)
        {
            //diffCube_.SetSize(64, D3DFMT_A8R8G8B8, TEXTURE_RENDERTARGET);
            //RenderSurface@ rs = diffCube_.renderSurfaces[FACE_POSITIVE_X];
            diffCube_.SetSize(1024, 1024, GetRGBAFormat(), TEXTURE_RENDERTARGET);
            log.Info("RGB Format: " + String(GetRGBAFormat()));
            RenderSurface@ rs = diffCube_.renderSurface;
            if (rs !is null)
            {
                log.Info("RenderSurface created");
                rs.viewports[0] = viewportRT;
            }
            else
            {
                log.Error("Failed to create RenderSurface");
            }

            model_ = node.GetOrCreateComponent("StaticModel");
            model_.enabled = true;
            log.Info("Envprobe material set");

            Material@ mat = cache.GetResource("Material", "Materials/Mushroom.xml");
            mat = mat.Clone();
            mat.textures[TU_DIFFUSE] = diffCube_;
            model_.material = mat;

            if (ZoneNode !is null)
            {
                log.Info("ZoneNode valid");
                zone_ = ZoneNode.GetComponent("Zone");
                if (zone_ !is null)
                {
                    log.Info("Zone texture set");
                    //zone_.zoneTexture = diffCube_;
                }
                else
                {
                    log.Error("Failed to find Zone Component.");
                }
            }
            else
            {
                log.Error("No ZoneNode assigned.");
            }

        }
        else
        {
            log.Error("diffCube is null");
        }

    }
};