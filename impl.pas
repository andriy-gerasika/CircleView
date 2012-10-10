unit impl;

interface

uses
  System.TypInfo, Macapi.ObjectiveC, Macapi.CocoaTypes, Macapi.Foundation, Macapi.AppKit;

type
  TOCLocalEx<T, I: NSObject> = class abstract(TOCLocal)
  protected
    function Super: I; inline;
    function GetObjectiveCClass: PTypeInfo; override;
  public
    constructor Create;
  end;

  CircleView = interface(NSView)
    ['{DD9EF84E-A302-4009-AF48-1F72290E7D32}']
    // Standard view create/free methods
    function initWithFrame(frame: NSRect): Pointer; cdecl;
    /// procedure dealloc; cdecl;

    // Drawing
    procedure drawRect(rect: NSRect); cdecl;
    function isOpaque: Boolean; cdecl;

    // Event handling
    procedure mouseDown(event: NSEvent); cdecl;
    procedure mouseDragged(event: NSEvent); cdecl;

    // Custom methods for actions this view implements
    procedure takeColorFrom(sender: NSColorWell); cdecl;
    procedure takeRadiusFrom(sender: NSControl); cdecl;
    procedure takeStartingAngleFrom(sender: NSControl); cdecl;
    procedure takeAngularVelocityFrom(sender: NSControl); cdecl;
    procedure takeStringFrom(sender: NSControl); cdecl;
    procedure startAnimation(sender: NSControl); cdecl;
    procedure stopAnimation(sender: NSControl); cdecl;
    procedure toggleAnimation(sender: NSControl); cdecl;

    // Method invoked by timer
    procedure performAnimation(sender: NSTimer); cdecl;
  end;

  TCircleView = class(TOCLocalEx<CircleView, NSView>)
  private
    center: NSPoint;
    radius: CGFloat;
    startingAngle: CGFloat;
    angularVelocity: CGFloat;
    textStorage: NSTextStorage;
    layoutManager: NSLayoutManager;
    textContainer: NSTextContainer;
    timer: NSTimer;
    lastTime: NSTimeInterval;
  private
    // Methods to set parameters
    procedure setColor(color: NSColor);
    procedure setRadius(distance: CGFloat);
    procedure setStartingAngle(angle: CGFloat);
    procedure setAngularVelocity(velocity: CGFloat);
    procedure setString(&string: NSString);
  public { ObjectiveC }
    // Standard view create/free methods
    function initWithFrame(frame: NSRect): Pointer; cdecl;
    destructor Destroy; /// procedure dealloc; cdecl;

    // Drawing
    procedure drawRect(rect: NSRect); cdecl;
    function isOpaque: Boolean; cdecl;

    // Event handling
    procedure mouseDown(event: NSEvent); cdecl;
    procedure mouseDragged(event: NSEvent); cdecl;

    // Custom methods for actions this view implements
    procedure takeColorFrom(sender: NSColorWell); cdecl;
    procedure takeRadiusFrom(sender: NSControl); cdecl;
    procedure takeStartingAngleFrom(sender: NSControl); cdecl;
    procedure takeAngularVelocityFrom(sender: NSControl); cdecl;
    procedure takeStringFrom(sender: NSControl); cdecl;
    procedure startAnimation(sender: NSControl); cdecl;
    procedure stopAnimation(sender: NSControl); cdecl;
    procedure toggleAnimation(sender: NSControl); cdecl;

    // Method invoked by timer
    procedure performAnimation(sender: NSTimer); cdecl;
  end;

implementation

uses Macapi.ObjCRuntime;

const
  AppKitLib = '/System/Library/Frameworks/AppKit.framework/AppKit';
  M_PI_2 = PI / 2;
  YES = True;
  NO = False;

procedure NSRectFill(aRect: NSRect); cdecl; external AppKitLib name '_NSRectFill';

function NSMaxRange(const range: NSRange): NSUInteger; inline;
begin
  Result := range.location + range.length;
end;

function NSMakeRange(location: NSUInteger; length: NSUInteger): NSRange; inline;
begin
  Result.location := location;
  Result.length := length;
end;

function NSMakePoint(x: Single; y: Single): NSPoint; inline;
begin
  Result.x := x;
  Result.y := y;
end;

{ TOCLocalEx<T> }

constructor TOCLocalEx<T, I>.Create;
begin
  inherited Create;
end;

function TOCLocalEx<T, I>.GetObjectiveCClass: PTypeInfo;
begin
  Result := TypeInfo(T);
end;

function TOCLocalEx<T, I>.Super: I;
begin
  Result := I(inherited Super);
end;

{ TCircleView }

// Many of the methods here are similar to those in the simpler DotView example.
// See that example for detailed explanations; here we will discuss those
// features that are unique to CircleView.

// CircleView draws text around a circle, using Cocoa's text system for
// glyph generation and layout, then calculating the positions of glyphs
// based on that layout, and using NSLayoutManager for drawing.

function TCircleView.initWithFrame(frame: NSRect): Pointer;
begin
  if Self = nil then
  begin
    Result := TCircleView.Create.initWithFrame(frame);
  end else
  begin
    Super.initWithFrame(frame);
    Result := GetObjectID;

    // First, we set default values for the various parameters.
    center.x := frame.size.width / 2;
    center.y := frame.size.height / 2;
    radius := 115.0;
    startingAngle := M_PI_2;
    angularVelocity := M_PI_2;

    // Next, we create and initialize instances of the three
    // basic non-view components of the text system:
    // an NSTextStorage, an NSLayoutManager, and an NSTextContainer.

    textStorage := TNSTextStorage.Wrap(TNSTextStorage.Alloc.initWithString(NSSTR('Here''s to the crazy ones, the misfits, the rebels, the troublemakers, the round pegs in the square holes, the ones who see things differently.')));
    layoutManager := TNSLayoutManager.Create;
    textContainer := TNSTextContainer.Create;

    layoutManager.addTextContainer(textContainer);
    textContainer.release;	// The layoutManager will retain the textContainer
    textStorage.addLayoutManager(layoutManager);
    layoutManager.release;	// The textStorage will retain the layoutManager

    // Screen fonts are not suitable for scaled or rotated drawing.
    // Views that use NSLayoutManager directly for text drawing should
    // set this parameter appropriately.
    layoutManager.setUsesScreenFonts(NO);
  end;
end;

destructor TCircleView.Destroy; /// procedure TCircleView.dealloc;
begin
  timer.invalidate;
  timer.release;
  textStorage.release;
  inherited Destroy;
end;

var
  set_SEL: Pointer;

procedure TCircleView.drawRect(rect: NSRect);
var
  glyphIndex: NSUInteger;
  glyphRange: NSRange;
  usedRect: NSRect;

  context: NSGraphicsContext;
  lineFragmentRect: NSRect;
  viewLocation: NSPoint;
  layoutLocation: NSPoint;
  angle: CGFloat;
  distance: CGFloat;
  transform: NSAffineTransform;
begin
  if set_SEL = nil then
  begin
    set_SEL := sel_registerName('set');
  end;
  objc_msgSend(TNSColor.OCClass.whiteColor, set_SEL);
  NSRectFill(Super.bounds);

  // Note that usedRectForTextContainer: does not force layout, so it must
  // be called after glyphRangeForTextContainer:, which does force layout.
  glyphRange := layoutManager.glyphRangeForTextContainer(textContainer);
  usedRect := layoutManager.usedRectForTextContainer(textContainer);

  for glyphIndex := glyphRange.location to NSMaxRange(glyphRange) - 1 do
  begin
    context := TNSGraphicsContext.Wrap(TNSGraphicsContext.OCClass.currentContext);
    lineFragmentRect := layoutManager.lineFragmentRectForGlyphAtIndex(glyphIndex, nil);
    viewLocation := layoutManager.locationForGlyphAtIndex(glyphIndex);
    layoutLocation := viewLocation;

    transform := TNSAffineTransform.Wrap(TNSAffineTransform.OCClass.transform);

    // Here layoutLocation is the location (in container coordinates) where the glyph was laid out.
    layoutLocation.x := layoutLocation.x + lineFragmentRect.origin.x;
    layoutLocation.y := layoutLocation.y + lineFragmentRect.origin.y;

    // We then use the layoutLocation to calculate an appropriate position for the glyph
    // around the circle (by angle and distance, or viewLocation in rectangular coordinates).
    distance := radius + usedRect.size.height - layoutLocation.y;
    angle := startingAngle + layoutLocation.x / distance;

    viewLocation.x := center.x + distance * sin(angle);
    viewLocation.y := center.y + distance * cos(angle);

    // We use a different affine transform for each glyph, to position and rotate it
    // based on its calculated position around the circle.
    transform.translateXBy(viewLocation.x, viewLocation.y);
    transform.rotateByRadians(-angle);

    // We save and restore the graphics state so that the transform applies only to this glyph.
    context.saveGraphicsState();
    transform.concat();
    // drawGlyphsForGlyphRange: draws the glyph at its laid-out location in container coordinates.
    // Since we are using the transform to place the glyph, we subtract the laid-out location here.
    layoutManager.drawGlyphsForGlyphRange(NSMakeRange(glyphIndex, 1), NSMakePoint(-layoutLocation.x, -layoutLocation.y));
    context.restoreGraphicsState();
  end;
end;

function TCircleView.isOpaque: Boolean;
begin
  Result := YES;
end;

// DotView changes location on mouse up, but here we choose to do so
// on mouse down and mouse drags, so the text will follow the mouse.

procedure TCircleView.mouseDown(event: NSEvent);
var
  eventLocation: NSPoint;
begin
  eventLocation := event.locationInWindow;
  center := Super.convertPoint(eventLocation, nil);
  Super.setNeedsDisplay(YES);
end;

procedure TCircleView.mouseDragged(event: NSEvent);
var
  eventLocation: NSPoint;
begin
  eventLocation := event.locationInWindow;
  center := Super.convertPoint(eventLocation, nil);
  Super.setNeedsDisplay(YES);
end;

// DotView uses action methods to set its parameters.  Here we have
// factored each of those into a method to set each parameter directly
// and a separate action method.

procedure TCircleView.setColor(color: NSColor);
begin
  // Text drawing uses the attributes set on the text storage rather
  // than drawing context attributes like the current color.
  textStorage.addAttribute(NSForegroundColorAttributeName, (color as ILocalObject).GetObjectID, NSMakeRange(0, textStorage.length));
  Super.setNeedsDisplay(YES);
end;

procedure TCircleView.setRadius(distance: CGFloat);
begin
  radius := distance;
  Super.setNeedsDisplay(YES);
end;

procedure TCircleView.setStartingAngle(angle: CGFloat);
begin
  startingAngle := angle;
  Super.setNeedsDisplay(YES);
end;

procedure TCircleView.setAngularVelocity(velocity: CGFloat);
begin
  angularVelocity := velocity;
  Super.setNeedsDisplay(YES);
end;

procedure TCircleView.setString(&string: NSString);
begin
  textStorage.replaceCharactersInRange(NSMakeRange(0, textStorage.length), &string);
  Super.setNeedsDisplay(YES);
end;

procedure TCircleView.takeColorFrom(sender: NSColorWell);
begin
  setColor(sender.color);
end;

procedure TCircleView.takeRadiusFrom(sender: NSControl);
begin
  setRadius(sender.doubleValue);
end;

procedure TCircleView.takeStartingAngleFrom(sender: NSControl);
begin
  setStartingAngle(sender.doubleValue);
end;

procedure TCircleView.takeAngularVelocityFrom(sender: NSControl);
begin
  setAngularVelocity(sender.doubleValue);
end;

procedure TCircleView.takeStringFrom(sender: NSControl);
begin
  setString(sender.stringValue);
end;

var
  performAnimation_SEL: Pointer;

procedure TCircleView.startAnimation(sender: NSControl);
begin
  stopAnimation(sender);

  // We schedule a timer for a desired 30fps animation rate.
  // In performAnimation: we determine exactly
  // how much time has elapsed and animate accordingly.
  if performAnimation_SEL = nil then
  begin
    performAnimation_SEL := sel_registerName('performAnimation:');
  end;
  timer := TNSTimer.Wrap(TNSTimer.OCClass.scheduledTimerWithTimeInterval(1.0/30.0, GetObjectID, performAnimation_SEL, nil, Yes));
  timer.retain;

  // The next two lines make sure that animation will continue to occur
  // while modal panels are displayed and while event tracking is taking
  // place (for example, while a slider is being dragged).
  TNSRunLoop.Wrap(TNSRunLoop.OCClass.currentRunLoop).addTimer(timer, NSModalPanelRunLoopMode);
  TNSRunLoop.Wrap(TNSRunLoop.OCClass.currentRunLoop).addTimer(timer, NSEventTrackingRunLoopMode);

  lastTime := TNSDate.OCClass.timeIntervalSinceReferenceDate;
end;

procedure TCircleView.stopAnimation(sender: NSControl);
begin
  if timer <> nil then
  begin
    timer.invalidate;
    timer.release;
    timer := nil;
  end;
end;

procedure TCircleView.toggleAnimation(sender: NSControl);
begin
  if timer <> nil then
  begin
    stopAnimation(sender);
  end else
  begin
    startAnimation(sender);
  end;
end;

procedure TCircleView.performAnimation(sender: NSTimer);
var
  thisTime: NSTimeInterval;
begin
  // We determine how much time has elapsed since the last animation,
  // and we advance the angle accordingly.
  thisTime := TNSDate.OCClass.timeIntervalSinceReferenceDate;
  setStartingAngle(startingAngle + angularVelocity * (thisTime - lastTime));
  lastTime := thisTime;
end;

end.
