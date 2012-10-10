program CircleView;

{$R *.res}

uses
  System.SysUtils,
  Macapi.ObjCRuntime,
  Macapi.ObjectiveC,
  Macapi.Foundation,
  Macapi.AppKit,
  impl in 'impl.pas';

var
  AppKitModule: HMODULE;
  AutoReleasePool: NSAutoReleasePool;
  applicationObject: NSApplication;

  mainBundle: NSBundle;
  infoDictionary: NSDictionary;
  mainNibName: NSString;
  mainNib: NSNib;

begin
  AppKitModule := LoadLibrary('/System/Library/Frameworks/AppKit.framework/AppKit');
  try
    AutoReleasePool := TNSAutoReleasePool.Create;
    AutoReleasePool.init;

    applicationObject := TNSApplication.Wrap(TNSApplication.OCClass.sharedApplication);

    mainBundle := TNSBundle.Wrap(TNSBundle.OCClass.mainBundle);
    {
    infoDictionary := mainBundle.infoDictionary;
    mainNibName := TNSString.Wrap(infoDictionary.objectForKey((NSSTR('CFBundleName') as ILocalObject)
      .GetObjectID));
    }
    mainNibName := NSSTR('MainMenu.nib');
    mainNib := TNSNib.Create;
    impl.TCircleView.Create;
    mainNib := TNSNib.Wrap(mainNib.initWithNibNamed(mainNibName, mainBundle));
    mainNib.instantiateNibWithOwner(nil, nil);

    applicationObject.run();

    AutoReleasePool.release;
  finally
    FreeLibrary(AppKitModule);
  end;
end.
