// A simple 'HelloWorld' GUI created purely from code.
// This sample demonstrates:
//     - Creation of controls and building a UI hierarchy
//     - Loading UI style from XML and applying it to controls
//     - Handling of global and per-control events
// For more advanced users (beginners can skip this section):
//     - Dragging UIElements
//     - Displaying tooltips
//     - Accessing available Events data (eventData)

#include "Data/Scripts/Utilities/Sample.as"

Window@ window;
IntVector2 dragBeginPosition = IntVector2(0, 0);

void Start()
{
    // Execute the common startup for samples
    SampleStart();

    // Enable OS cursor
    input.mouseVisible = true;

    // Load XML file containing default UI style sheet
    XMLFile@ style = cache.GetResource("XMLFile", "UI/DefaultStyle.xml");

    // Set the loaded style as default style
    ui.root.defaultStyle = style;
    ui.root.dragDropMode = DD_TARGET;

    Cursor@ cursor = Cursor("Cursor");
    cursor.SetStyleAuto();
    cursor.useSystemShapes = false;
    ui.cursor = cursor;
    if (GetPlatform() == "Android" || GetPlatform() == "iOS")
        ui.cursor.visible = false;

    // Initialize background
    InitWindowBackground();

    // Initialize Window
    InitWindowDockable();
    InitWindowDockR();
    InitWindowDockL();

    SubscribeToEvent("DragDropFinish", "HandleDragDropFinish");
    SubscribeToEvent("DragDropTest", "HandleDragDropTest");
	
	engine.maxFps = 20;
}

void InitWindowBackground()
{
    // Create the Window and add it to the UI's root node
    window = Window();
    ui.root.AddChild(window);

    // Set Window size and layout settings
    //window.SetLayout(LM_VERTICAL, 6, IntRect(6, 6, 6, 6));
    //window.SetAlignment(HA_CENTER, VA_CENTER);
    window.name = "Background";
    window.dragDropMode = DD_TARGET;
    window.priority = -1000;

    // Apply styles
    window.SetStyleAuto();

    window.SetMinSize(graphics.width, graphics.height);
}

void InitWindowDockable()
{
    // Create the Window and add it to the UI's root node
    Window@ wnd = Window();
    window.AddChild(wnd);

    // Set Window size and layout settings
    wnd.SetLayout(LM_VERTICAL, 6, IntRect(6, 6, 6, 6));
    wnd.SetAlignment(HA_CENTER, VA_CENTER);
    wnd.name = "Window";
    wnd.dragDropMode = DD_SOURCE;

    // Create Window 'titlebar' container
    UIElement@ titleBar = UIElement();
    titleBar.SetMinSize(0, 24);
    titleBar.verticalAlignment = VA_TOP;
    titleBar.layoutMode = LM_HORIZONTAL;

    // Create the Window title Text
    Text@ wndTitle = Text();
    wndTitle.name = "WindowTitle";
    wndTitle.text = "Dockable!";

    // Add the controls to the title bar
    titleBar.AddChild(wndTitle);

    // Add the title bar to the Window
    wnd.AddChild(titleBar);

    // Apply styles
    wnd.SetStyleAuto();
    wndTitle.SetStyleAuto();

    wnd.SetMinSize(3, 150);

    SubscribeToEvent(wnd, "DragBegin", "HandleDragBegin");
    SubscribeToEvent(wnd, "DragMove", "HandleDragMove");
    SubscribeToEvent(wnd, "DragEnd", "HandleDragEnd");
    SubscribeToEvent(wnd, "DragCancel", "HandleDragCancel");
}

void InitWindowDockR()
{
    // Create the wnd and add it to the UI's root node
    Window@ wnd = Window();
    window.AddChild(wnd);

    // Set wnd size and layout settings
    wnd.SetLayout(LM_VERTICAL, 6, IntRect(20, 6, 6, 6));
    wnd.SetAlignment(HA_RIGHT, VA_CENTER);
    wnd.name = "wnd";
    wnd.dragDropMode = DD_TARGET;
    wnd.priority = 1000;
	
	for (int i = 0; i < 5; i++)
	{
		// Create wnd 'titlebar' container
		Window@ titleBar = Window();
		titleBar.SetMinSize(0, 24);
		titleBar.verticalAlignment = VA_TOP;
		titleBar.SetLayout(LM_HORIZONTAL, 6, IntRect(6, 6, 6, 6));
        titleBar.dragDropMode = DD_SOURCE_AND_TARGET;

		// Create the wnd title Text
		Text@ wndTitle = Text();
		wndTitle.name = "wndTitle";
		wndTitle.text = "Dock! " + String(i);

		// Add the controls to the title bar
		titleBar.AddChild(wndTitle);
		
		// Add the title bar to the wnd
		wnd.AddChild(titleBar);
		titleBar.SetStyleAuto();
		wndTitle.SetStyleAuto();

		log.Info(String(titleBar.screenPosition.y));
	}

    log.Info(String(wnd.numChildren));

    // Apply styles
    wnd.SetStyleAuto();

    wnd.SetMinSize(384, 192);
	
	wnd.UpdateLayout();
}

void InitWindowDockL()
{
    // Create the Window and add it to the UI's root node
    Window@ wnd = Window();
    window.AddChild(wnd);

    // Set Window size and layout settings
    wnd.SetLayout(LM_VERTICAL, 6, IntRect(6, 6, 6, 6));
    wnd.SetAlignment(HA_LEFT, VA_CENTER);
    wnd.name = "Window";
    wnd.dragDropMode = DD_TARGET;

    // Create Window 'titlebar' container
    UIElement@ titleBar = UIElement();
    titleBar.SetMinSize(0, 24);
    titleBar.verticalAlignment = VA_TOP;
    titleBar.layoutMode = LM_HORIZONTAL;

    // Create the Window title Text
    Text@ wndTitle = Text();
    wndTitle.name = "WindowTitle";
    wndTitle.text = "Dock!";

    // Add the controls to the title bar
    titleBar.AddChild(wndTitle);

    // Add the title bar to the Window
    wnd.AddChild(titleBar);

    // Apply styles
    wnd.SetStyleAuto();
    wndTitle.SetStyleAuto();

    wnd.SetMinSize(384, 192);
}

IntVector2 startPos;
IntVector2 offset;

void HandleDragBegin(StringHash eventType, VariantMap& eventData)
{
    //log.Info("HandleDragBegin()");
    ui.cursor.position = input.mousePosition;
    ui.cursor.visible = true;

    UIElement@ element = eventData["Element"].GetPtr();
    startPos.x = eventData["X"].GetInt();
    startPos.y = eventData["Y"].GetInt();
    offset = element.position - startPos;
}

void HandleDragMove(StringHash eventType, VariantMap& eventData)
{
    UIElement@ element = eventData["Element"].GetPtr();
    IntVector2 pos;
    pos.x = eventData["X"].GetInt();
    pos.y = eventData["Y"].GetInt();
    //element.position = pos + offset;
}

void HandleDragEnd(StringHash eventType, VariantMap& eventData)
{
    //log.Info("HandleDragEnd()");
     UIElement@ element = eventData["Element"].GetPtr();
     element.color = Color(1,1,1);
}

void HandleDragCancel(StringHash eventType, VariantMap& eventData)
{
    UIElement@ element = eventData["Element"].GetPtr();
    element.position = startPos;
    element.color = Color(1,1,1);
}

void HandleDragDropTest(StringHash eventType, VariantMap& eventData)
{
    //log.Info("HandleDragDropFinish()");
    UIElement@ source = eventData["Source"].GetPtr();
    UIElement@ target = eventData["Target"].GetPtr();
    bool accept = eventData["Accept"].GetBool();

	if (accept && !IsChild(source, target))
	{
        source.color = Color(0,1,0);

        if (target.layoutMode == LM_FREE)
        {
            ui.root.AddChild(source);
            target.AddChild(source);
            // Currently staggers due to element blocking in UI design. can be fixed with element masking.
            source.position = input.mousePosition + offset;
        }
        else
        {
            uint index = GetIndexOfElementAt(input.mousePosition, target, source);

            if (index != lastIndex || target !is lastParent)
            {
                // Have to 'unset' element before inserting to new location
                ui.root.AddChild(source);
                //if (target is lastParent && index > lastIndex)
                //    index--;
                target.InsertChild(index, source);

                log.Info(outLog);
                lastParent = target;
                lastIndex = index;

                // Re-adjust style:
                //source.SetPosition(0,0);
                //source.SetAlignment(HA_CENTER, VA_CENTER);
                //source.SetSize(0,0);
                target.UpdateLayout();
            }
        }
	}
}

UIElement@ GetElementAtFiltered(IntVector2 pos)
{
    //log.Info("GetElementAtFiltered()");
	Array<UIElement@>@ children = ui.root.GetChildren(true);

    //log.Info(String(children.length));
    //log.Info("Pos: (" + String(pos.x) + ", " + String(pos.y) + ")");

    UIElement@ e = null;
	for (int i = 0; i < children.length; i++)
	{
		UIElement@ child = children[i];
        //log.Info(String(i) + " " + child.name + " " + String(child.numChildren));

		if (child.dragDropMode != DD_TARGET && child.dragDropMode != DD_SOURCE_AND_TARGET)
			continue;

        //log.Info("+ (" + String(child.screenPosition.x) +", " + String(child.screenPosition.y) + ") (" + String(child.width) + " " + String(child.height) + ")");

		if (child.IsInside(pos, true))
        {
            //log.Info("* " + String(child.priority));
            if (e is null || child.priority >= e.priority)
                e = child;
        }
	}
	return e;
}


bool IsChild(UIElement@ parent, UIElement@ element)
{
	Array<UIElement@>@ children = parent.GetChildren(true);

    UIElement@ e = null;
	for (int i = 0; i < children.length; i++)
	{
		if (children[i] is element)
            return true;
	}

	return false;
}

String outLog;

uint GetIndexOfElementAt(IntVector2 pos, UIElement@ target, UIElement@ ignoreElement)
{
	//target = GetElementAtFiltered(pos);
	if (target is null)
		return 0;

    log.Info(target.name);

	Array<UIElement@>@ children = target.GetChildren(false);

    LayoutMode lm = target.layoutMode;
	uint index = target.numChildren;
	float d = 9999;
	outLog = "\nNum Children: " + String(target.numChildren) + "\n";
	for (uint i = 0; i < target.numChildren; i++)
	{
		UIElement@ child = children[i];
		//if (child is ignoreElement)
		//	continue;
            
		IntVector2 p = child.screenPosition;
		float dc;
        if (lm == LM_HORIZONTAL)
            dc = (p.x + child.width / 2) - pos.x;
        else if (lm == LM_VERTICAL)
            dc = (p.y + child.height / 2) - pos.y;
        else
        {
            dc = 9999;
            log.Info("???????????");
        }

		if (Abs(dc) <= d)
		{
			outLog += "{index: " + String(i) +
						", distance: " + String(dc) + "}\n";
            if (dc < 0)
                index = i;
            else
                index = i - 1;
			d = Abs(dc);
		}
		log.Info(String(i) + " " + String(p.y));
	}
	//log.Info(outLog);
	/*log.Info(String(index)+
		" (" +
			String(children[index].screenPosition.y) +
		") vs [" +
			String(pos.y) + 
		"]");*/
	return Clamp(index, 0, target.numChildren);
}

UIElement@ lastParent;
uint lastIndex = 0;

void HandleDragDropFinish(StringHash eventType, VariantMap& eventData)
{
    
}

// Create XML patch instructions for screen joystick layout specific to this sample app
String patchInstructions =
        "<patch>" +
        "    <add sel=\"/element/element[./attribute[@name='Name' and @value='Hat0']]\">" +
        "        <attribute name=\"Is Visible\" value=\"false\" />" +
        "    </add>" +
        "</patch>";
