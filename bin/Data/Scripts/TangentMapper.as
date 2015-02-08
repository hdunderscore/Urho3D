#include "Scripts/Utilities/Sample.as"

bool takeShot = true;

void Start()
{
    // Execute the common startup for samples
    SampleStart();
    SetLogoVisible(false);

    // Create static scene content
    CreateScene();

    engine.maxFps = 15;
    cache.autoReloadResources = true;

    takeShot = true;
    SubscribeToEvent("EndFrame", "HandleUpdate");
}

void HandleUpdate(StringHash eventType, VariantMap &eventData)
{
    if (takeShot)
    {
        takeShot = false;
        Image@ screenshot = Image();
        graphics.TakeScreenShot(screenshot);
        // Here we save in the Data folder with date and time appended
        screenshot.SavePNG(fileSystem.programDir + "Data/Texture_" +
            time.timeStamp.Replaced(':', '_').Replaced('.', '_').Replaced(' ', '_') + ".png");
    }
}

void CreateScene()
{
    scene_ = Scene();
    scene_.CreateComponent("DebugRenderer");
    scene_.CreateComponent("Octree");

    LoadModel();

    // Create camera and define viewport. Camera does not necessarily have to belong to the scene
    cameraNode = Node();
    cameraNode.position = Vector3(0, 0, 5);
    cameraNode.rotation = Quaternion(0, 180, 0);
    Camera@ camera = cameraNode.CreateComponent("Camera");
    camera.farClip = 300.0f;
    Viewport@ viewport = Viewport(scene_, camera);
    renderer.viewports[0] = viewport;
}

void LoadModel()
{
    Material@ mat = cache.GetResource("Material", "Materials/Tangent.xml");
    mat.cullMode = CULL_NONE;

    Node@ modelNode = Node();
    scene_.AddChild(modelNode);
    StaticModel@ model = modelNode.CreateComponent("StaticModel");
    model.model = cache.GetResource("Model", "Models/Sphere2.mdl");
    model.material = mat;
    //model.materials[0].cullMode = CULL_NONE;

    Node@ n = scene_.CreateChild();
    n.position = Vector3(3, 3, 0);
    Light@ l = n.CreateComponent("Light");
}



// Create XML patch instructions for screen joystick layout specific to this sample app
String patchInstructions = "";