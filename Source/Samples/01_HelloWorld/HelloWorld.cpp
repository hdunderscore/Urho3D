//
// Copyright (c) 2008-2017 the Urho3D project.
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

#include <Urho3D/Core/CoreEvents.h>
#include <Urho3D/Core/ProcessUtils.h>
#include <Urho3D/Input/Input.h>
#include <Urho3D/UI/Font.h>
#include <Urho3D/UI/Text.h>
#include <Urho3D/UI/UI.h>

#include "HelloWorld.h"

#include <Urho3D/DebugNew.h>

// Expands to this example's entry-point
URHO3D_DEFINE_APPLICATION_MAIN(HelloWorld)

String GetMatch(String& text, String& lowerText, unsigned& i, String command);

HelloWorld::HelloWorld(Context* context) :
    Sample(context)
{
}

void HelloWorld::Start()
{
    // Execute base class startup
    Sample::Start();

    // Create "Hello World" Text
    CreateText();

    // Finally subscribe to the update event. Note that by subscribing events at this point we have already missed some events
    // like the ScreenMode event sent by the Graphics subsystem when opening the application window. To catch those as well we
    // could subscribe in the constructor instead.
    SubscribeToEvents();

    // Set the mouse mode to use in the sample
    Sample::InitMouseMode(MM_FREE);
}

void HelloWorld::CreateText()
{
    ResourceCache* cache = GetSubsystem<ResourceCache>();

    // Construct new Text object
    helloText = new Text(context_);

    // Set String to display
    String parsedText = ParseText("Hello [color=C_RED]World[color=DEFAULT] from Urho3D!");
    helloText->SetText(parsedText);

    // Set font and text color
    helloText->SetFont(cache->GetResource<Font>("Fonts/Anonymous Pro.ttf"), 30);
    helloText->SetColor(Color(0.0f, 1.0f, 0.0f));

    // Align Text center-screen
    helloText->SetHorizontalAlignment(HA_CENTER);
    helloText->SetVerticalAlignment(VA_CENTER);

    Vector<Color> colors;

    for (unsigned i = 0; i < helloText->GetText().Length() + 10; ++i)
    {
        colors.Push(Color(0.0f, 0.0f, 0.0f, 1.0f - i / 10.0f));
    }

    for (unsigned i = 0; i < 20; ++i)
    {
        colors.Push(Color(0.0f, 1.0f, 0.0f, 1.0f - i / 20.0f));
    }

    PODVector<unsigned> colorIndices;
    for (unsigned i = 0; i < helloText->GetText().Length(); ++i)
    {
        colorIndices.Push(i % colors.Size());
    }

    //helloText->SetColors(colors, colorIndices);

    // Add Text instance to the UI root element
    GetSubsystem<UI>()->GetRoot()->AddChild(helloText);
}

void HelloWorld::SubscribeToEvents()
{
    // Subscribe HandleUpdate() function for processing update events
    SubscribeToEvent(E_UPDATE, URHO3D_HANDLER(HelloWorld, HandleUpdate));
}

void HelloWorld::HandleUpdate(StringHash eventType, VariantMap& eventData)
{
    // Do nothing for now, could be extended to eg. animate the display

    using namespace Update;
    float timeStep = eventData[P_TIMESTEP].GetFloat();
    timeAccum_ += timeStep * 10.0f;

    PODVector<unsigned> colorIndices;
    const Vector<Color>& colors(helloText->GetColors());

    for (unsigned i = helloText->GetText().Length(); i < unsigned(-1); --i)
    {
        colorIndices.Push((unsigned(timeAccum_) + i) % colors.Size());
    }

    //helloText->SetColors(colors, colorIndices);
}

String HelloWorld::ParseText(String text)
{
    Vector<Color> colors;
    colors.Push(Color::WHITE);//TODO: default color

    PODVector<unsigned> colorIndices;

    unsigned colorIndex = 0;
    String lowerText = text.ToLower();

    for (unsigned i = 0; i < text.Length(); ++i)
    {
        if (text[i] == '\\')
        {
            continue;//?
        }

        if (text[i] == '[')
        {
            String colorMatch = GetMatch(text, lowerText, i, "color");
            if (colorMatch != "")
            {
                if (colorMatch == "c_red")
                {
                    colors.Push(Color::RED);
                    colorIndex = colors.Size() - 1;
                }
                else if (colorMatch == "default")
                {
                    URHO3D_LOGINFO("ASD");
                    colorIndex = 0;
                }
            }
        }

        colorIndices.Push(colorIndex);
    }

    helloText->SetColors(colors, colorIndices);

    return text;
}

String GetMatch(String& text, String& lowerText, unsigned& i, String command)
{
    unsigned startI = i;
    unsigned match = 0;
    bool matched = false;
    String argument;

    for (; i < lowerText.Length(); ++i)
    {
        if (!matched)
        {
            if (lowerText[i] == command[match])
                match++;
            if (match == command.Length() && lowerText[i] == '=')
                matched = true;
        }
        else
        {
            if (lowerText[i] == ']')
            {
                text.Erase(startI, i - startI + 1);
                lowerText = text.ToLower();
                i = startI;
                return argument;
            }
            if ((lowerText[i] >= 'a' && lowerText[i] <= 'z') || (lowerText[i] >= '0' && lowerText[i] <= '9') || (lowerText[i] == '_'))
            {
                argument += lowerText[i];
            }
        }
    }

    i = startI;
    return "";
}