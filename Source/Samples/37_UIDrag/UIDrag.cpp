//
// Copyright (c) 2008-2014 the Urho3D project.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#include "UIDrag.h"

#include "Camera.h"
#include "CoreEvents.h"
#include "Engine.h"
#include "Font.h"
#include "Graphics.h"
#include "Input.h"
#include "Octree.h"
#include "Renderer.h"
#include "ResourceCache.h"
#include "Scene.h"
#include "Zone.h"
#include "Drawable2D.h"
#include "Log.h"

#include "UIEvents.h"
#include "Text.h"
#include "UIElement.h"
#include "Button.h"
#include "LineEdit.h"

#include "DebugNew.h"
#include "Log.h"

DEFINE_APPLICATION_MAIN(UIDrag)

UIDrag::UIDrag(Context* context) :
    Sample(context)
{
}

void UIDrag::Start()
{
    // Execute base class startup
    Sample::Start();

    // Create the scene content
    CreateScene();

    // Create the UI content
    CreateGUI();
    CreateInstructions();

    // Setup the viewport for displaying the scene
    SetupViewport();

    // Hook up to the frame update events
    SubscribeToEvents();
}

void UIDrag::CreateScene()
{
    scene_ = new Scene(context_);
    scene_->CreateComponent<Octree>();

    // Create camera node
    cameraNode_ = scene_->CreateChild("Camera");
    // Set camera's position
    cameraNode_->SetPosition(Vector3(0.0f, 0.0f, -10.0f));

    Camera* camera = cameraNode_->CreateComponent<Camera>();
    camera->SetOrthographic(true);

    Graphics* graphics = GetSubsystem<Graphics>();
    camera->SetOrthoSize((float)graphics->GetHeight() * PIXEL_SIZE);

    GetSubsystem<Input>()->SetMouseVisible(true);
}

void UIDrag::CreateGUI()
{
    ResourceCache* cache = GetSubsystem<ResourceCache>();
    UI* ui = GetSubsystem<UI>();

    UIElement* root = ui->GetRoot();
    // Load the style sheet from xml
    root->SetDefaultStyle(cache->GetResource<XMLFile>("UI/DefaultStyle.xml"));

    {
        LineEdit* l = new LineEdit(context_);
        root->AddChild(l);
        l->SetStyle("LineEdit");
        l->SetHorizontalAlignment(HA_CENTER);
        l->SetVerticalAlignment(VA_BOTTOM);
        l->SetSize(300, 40);
        l->SetMode(LEM_NUMERIC);
        l->SetValue(0.0f);
        l->SetDragEditIncrement(0.5f);
        // Can do a combo:
        //l->SetDragEditCombo(MOUSEB_LEFT | MOUSEB_RIGHT);
        l->SetDragEditCombo(MOUSEB_LEFT);

        SubscribeToEvent(l, E_DRAGBEGIN, HANDLER(UIDrag, HandleLineEditDragBegin));
        SubscribeToEvent(l, E_TEXTFINISHED, HANDLER(UIDrag, HandleTextFinished));
    }
    for (int i=0; i < 10; i++)
    {
        Button* b = new Button(context_);
        root->AddChild(b);
        // Reference a style from the style sheet loaded earlier:
        b->SetStyle("Button");
        b->SetSize(300, 100);
        b->SetPosition(IntVector2(50*i, 50*i));

        SubscribeToEvent(b, E_DRAGMOVE, HANDLER(UIDrag, HandleDragMove));
        SubscribeToEvent(b, E_DRAGBEGIN, HANDLER(UIDrag, HandleDragBegin));
        SubscribeToEvent(b, E_DRAGCANCEL, HANDLER(UIDrag, HandleDragCancel));
        SubscribeToEvent(b, E_DRAGEND, HANDLER(UIDrag, HandleDragEnd));

        {
            Text* t = new Text(context_);
            b->AddChild(t);
            t->SetStyle("Text");
            t->SetHorizontalAlignment(HA_CENTER);
            t->SetVerticalAlignment(VA_CENTER);
            t->SetName("Text");
        }

        {
            Text* t = new Text(context_);
            b->AddChild(t);
            t->SetStyle("Text");
            t->SetName("Event Touch");
            t->SetHorizontalAlignment(HA_CENTER);
            t->SetVerticalAlignment(VA_BOTTOM);
        }

        {
            Text* t = new Text(context_);
            b->AddChild(t);
            t->SetStyle("Text");
            t->SetName("Num Touch");
            t->SetHorizontalAlignment(HA_CENTER);
            t->SetVerticalAlignment(VA_TOP);
        }
    }

    for (int i = 0; i < 10; i++)
    {
        Text* t = new Text(context_);
        root->AddChild(t);
        t->SetStyle("Text");
        t->SetText("Touch "+ String(i));
        t->SetName("Touch "+ String(i));
        t->SetVisible(false);
    }
}

void UIDrag::CreateInstructions()
{
    ResourceCache* cache = GetSubsystem<ResourceCache>();
    UI* ui = GetSubsystem<UI>();

    // Construct new Text object, set string to display and font to use
    Text* instructionText = ui->GetRoot()->CreateChild<Text>();
    instructionText->SetText("Drag on the buttons to move them around.\nMulti- button drag also supported.");
    instructionText->SetFont(cache->GetResource<Font>("Fonts/Anonymous Pro.ttf"), 15);

    // Position the text relative to the screen center
    instructionText->SetHorizontalAlignment(HA_CENTER);
    instructionText->SetVerticalAlignment(VA_CENTER);
    instructionText->SetPosition(0, ui->GetRoot()->GetHeight() / 4);
}

void UIDrag::SetupViewport()
{
    Renderer* renderer = GetSubsystem<Renderer>();

    // Set up a viewport to the Renderer subsystem so that the 3D scene can be seen
    SharedPtr<Viewport> viewport(new Viewport(context_, scene_, cameraNode_->GetComponent<Camera>()));
    renderer->SetViewport(0, viewport);
}

void UIDrag::SubscribeToEvents()
{
    SubscribeToEvent(E_UPDATE, HANDLER(UIDrag, HandleUpdate));
    // Unsubscribe the SceneUpdate event from base class to prevent camera pitch and yaw in 2D sample
    UnsubscribeFromEvent(E_SCENEUPDATE);
}

void UIDrag::HandleDragBegin(StringHash eventType, VariantMap& eventData)
{
    using namespace DragBegin;
    Button* element = (Button*)eventData[P_ELEMENT].GetVoidPtr();

    int lx = eventData[P_X].GetInt();
    int ly = eventData[P_Y].GetInt();

    IntVector2 p = element->GetPosition();
    element->SetVar("STARTX", p.x_);
    element->SetVar("STARTY", p.y_);
    element->SetVar("DX", p.x_ - lx);
    element->SetVar("DY", p.y_ - ly);

    int buttons = eventData[P_BUTTONS].GetInt();
    element->SetVar("BUTTONS", buttons);

    Text* t = (Text*)element->GetChild(String("Text"));
    t->SetText(String(buttons));

    t = (Text*)element->GetChild(String("Num Touch"));
    t->SetText(String(eventData[P_NUMBUTTONS].GetInt()));
}

void UIDrag::HandleDragMove(StringHash eventType, VariantMap& eventData)
{
    using namespace DragBegin;
    Button* element = (Button*)eventData[P_ELEMENT].GetVoidPtr();
    int buttons = eventData[P_BUTTONS].GetInt();
    int X = eventData[P_X].GetInt() + element->GetVar("DX").GetInt();
    int Y = eventData[P_Y].GetInt() + element->GetVar("DY").GetInt();
    int BUTTONS = element->GetVar("BUTTONS").GetInt();

    Text* t = (Text*)element->GetChild(String("Event Touch"));
    t->SetText(String(buttons));

    if (buttons == BUTTONS)
        element->SetPosition(IntVector2(X, Y));
}

void UIDrag::HandleDragCancel(StringHash eventType, VariantMap& eventData)
{
    using namespace DragBegin;
    Button* element = (Button*)eventData[P_ELEMENT].GetVoidPtr();
    int X = element->GetVar("STARTX").GetInt();
    int Y = element->GetVar("STARTY").GetInt();
    element->SetPosition(IntVector2(X, Y));
}

void UIDrag::HandleDragEnd(StringHash eventType, VariantMap& eventData)
{
    using namespace DragBegin;
    Button* element = (Button*)eventData[P_ELEMENT].GetVoidPtr();
}

void UIDrag::HandleUpdate(StringHash eventType, VariantMap& eventData)
{
    UI* ui = GetSubsystem<UI>();
    UIElement* root = ui->GetRoot();

    Input* input = GetSubsystem<Input>();

    unsigned n = input->GetNumTouches();
    for (unsigned i = 0; i < n; i++)
    {
        Text* t = (Text*)root->GetChild("Touch " + String(i));
        TouchState* ts = input->GetTouch(i);

        IntVector2 pos = ts->position_;
        pos.y_ -= 30;

        t->SetPosition(pos);
        t->SetVisible(true);
    }

    for (unsigned i = n; i < 10; i++)
    {
        Text* t = (Text*)root->GetChild("Touch " + String(i));
        t->SetVisible(false);
    }
}

void UIDrag::HandleTextFinished(StringHash eventType, VariantMap& eventData)
{
    using namespace TextFinished;
    LOGINFO("Text finished: " + eventData[P_TEXT].GetString());
    LOGINFO("Value finished: " + String(eventData[P_VALUE].GetFloat()));
}

void UIDrag::HandleLineEditDragBegin(StringHash eventType, VariantMap& eventData)
{
    using namespace DragBegin;
    LineEdit* l = (LineEdit*)eventData[P_ELEMENT].GetVoidPtr();
    // Increment faster when the value in the LineEdit box is higher.
    l->SetDragEditIncrement(Clamp(Abs(l->GetValue() * 0.01f), 0.01f, 10.0f));
}
