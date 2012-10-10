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
    function initWithFrame(frame: NSRect): Pointer; cdecl;
    procedure drawRect(rect: NSRect); cdecl;

    procedure takeColorFrom(sender: Pointer); cdecl;
    procedure takeRadiusFrom(sender: Pointer); cdecl;
    procedure takeStartingAngleFrom(sender: Pointer); cdecl;
    procedure takeAngularVelocityFrom(sender: Pointer); cdecl;
    procedure takeStringFrom(sender: Pointer); cdecl;
    procedure startAnimation(sender: Pointer); cdecl;
    procedure stopAnimation(sender: Pointer); cdecl;
    procedure toggleAnimation(sender: Pointer); cdecl;
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
  public { NSView }
    function initWithFrame(frame: NSRect): Pointer; cdecl;
    procedure drawRect(rect: NSRect); cdecl;
  public { CircleView }
    procedure takeColorFrom(sender: Pointer); cdecl;
    procedure takeRadiusFrom(sender: Pointer); cdecl;
    procedure takeStartingAngleFrom(sender: Pointer); cdecl;
    procedure takeAngularVelocityFrom(sender: Pointer); cdecl;
    procedure takeStringFrom(sender: Pointer); cdecl;
    procedure startAnimation(sender: Pointer); cdecl;
    procedure stopAnimation(sender: Pointer); cdecl;
    procedure toggleAnimation(sender: Pointer); cdecl;
  end;

implementation

const
  AppKitLib = '/System/Library/Frameworks/AppKit.framework/AppKit';
  M_PI_2 = PI / 2;
  NO = False;

procedure NSRectFill(const aRect: NSRect); cdecl; external AppKitLib name '_NSRectFill';

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
///TODO:  TNSColor.OCClass.whiteColor;//  [[NSColor whiteColor] set];
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

procedure TCircleView.startAnimation(sender: Pointer);
begin
end;

procedure TCircleView.stopAnimation(sender: Pointer);
begin
end;

procedure TCircleView.takeAngularVelocityFrom(sender: Pointer);
begin
end;

procedure TCircleView.takeColorFrom(sender: Pointer);
begin
end;

procedure TCircleView.takeRadiusFrom(sender: Pointer);
begin
end;

procedure TCircleView.takeStartingAngleFrom(sender: Pointer);
begin
end;

procedure TCircleView.takeStringFrom(sender: Pointer);
begin
end;

procedure TCircleView.toggleAnimation(sender: Pointer);
begin
end;

end.
