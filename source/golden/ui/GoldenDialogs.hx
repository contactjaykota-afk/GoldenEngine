package golden.ui;

import flixel.FlxSprite;
import flixel.text.FlxInputText;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import golden.audio.UISound;
import golden.modding.ModOps;
import golden.ui.GoldenUI.GoldenButton;

/**
 * Yes/No confirmation dialog. Keyboard: Left/Right + Enter, Y/N, Esc = No. Mouse: click a button.
 * Controller: same as keyboard through FNF's control bindings.
 */
class GoldenConfirmSubState extends GoldenSubState
{
  var message:String;
  var onYes:Void->Void;
  var choice:Int = 1; // 0 = yes, 1 = no (safe default)
  var yesBtn:GoldenButton;
  var noBtn:GoldenButton;

  public function new(message:String, onYes:Void->Void)
  {
    super(0x99000000);
    this.message = message;
    this.onYes = onYes;
  }

  override function create():Void
  {
    super.create();
    var w = 640, h = 220;
    var x = (FlxG.width - w) / 2, y = (FlxG.height - h) / 2;
    add(GoldenUI.panel(x - 2, y - 2, w + 4, h + 4, GoldenUI.GOLD));
    add(GoldenUI.panel(x, y, w, h, 0xFF1A1420));
    add(GoldenUI.text(x + 24, y + 24, w - 48, message, 18));
    yesBtn = new GoldenButton(x + w / 2 - 170, y + h - 64, 150, 40, 'Yes (Y)', confirm);
    noBtn = new GoldenButton(x + w / 2 + 20, y + h - 64, 150, 40, 'No (N)', cancel);
    add(yesBtn);
    add(noBtn);
    UISound.play(Open);
    refreshButtons();
  }

  function refreshButtons():Void
  {
    yesBtn.alpha = choice == 0 ? 1 : 0.6;
    noBtn.alpha = choice == 1 ? 1 : 0.6;
  }

  function confirm():Void
  {
    UISound.play(Select);
    close();
    onYes();
  }

  function cancel():Void
  {
    UISound.play(Back);
    close();
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);
    if (inputBlocked()) return;
    if (controls.UI_LEFT_P || controls.UI_RIGHT_P)
    {
      choice = 1 - choice;
      UISound.play(Scroll);
      refreshButtons();
    }
    if (FlxG.keys.justPressed.Y) confirm();
    else if (FlxG.keys.justPressed.N || controls.BACK_P) cancel();
    else if (controls.ACCEPT_P) choice == 0 ? confirm() : cancel();
  }
}

/** A message box with a single OK button (used for errors and results). */
class GoldenMessageSubState extends GoldenSubState
{
  var title:String;
  var message:String;
  var isError:Bool;

  public function new(title:String, message:String, isError:Bool = false)
  {
    super(0x99000000);
    this.title = title;
    this.message = message;
    this.isError = isError;
  }

  override function create():Void
  {
    super.create();
    var w = 760, h = 300;
    var x = (FlxG.width - w) / 2, y = (FlxG.height - h) / 2;
    add(GoldenUI.panel(x - 2, y - 2, w + 4, h + 4, isError ? GoldenUI.BAD : GoldenUI.GOLD));
    add(GoldenUI.panel(x, y, w, h, 0xFF1A1420));
    add(GoldenUI.text(x + 24, y + 18, w - 48, title, 24, isError ? GoldenUI.BAD : GoldenUI.GOLD));
    add(GoldenUI.text(x + 24, y + 60, w - 48, message, 16));
    add(new GoldenButton(x + (w - 150) / 2, y + h - 58, 150, 40, 'OK (Enter)', ok));
    UISound.play(isError ? Error : Open);
  }

  function ok():Void
  {
    UISound.play(Close);
    close();
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);
    if (inputBlocked()) return;
    if (controls.ACCEPT_P || controls.BACK_P) ok();
  }
}

/**
 * Create Mod wizard: title, folder id (auto-filled from the title until edited), author, version,
 * description. Validates before creating; creation copies the packaged starter template and writes
 * a `_polymod_meta.json` for the running game's API version.
 */
class GoldenCreateModSubState extends GoldenSubState
{
  var fields:Array<FlxInputText> = [];
  var labels:Array<String> = ['Title', 'Folder name', 'Author', 'Version', 'Description'];
  var focusIndex:Int = 0;
  var folderEdited:Bool = false;
  var errorText:FlxText;
  var onCreated:String->Void;

  public function new(onCreated:String->Void)
  {
    super(0xAA000000);
    this.onCreated = onCreated;
  }

  override function create():Void
  {
    super.create();
    var w = 760, h = 470;
    var x = (FlxG.width - w) / 2, y = (FlxG.height - h) / 2;
    add(GoldenUI.panel(x - 2, y - 2, w + 4, h + 4, GoldenUI.GOLD));
    add(GoldenUI.panel(x, y, w, h, 0xFF1A1420));
    add(GoldenUI.text(x + 24, y + 16, w - 48, 'CREATE NEW MOD', 26, GoldenUI.GOLD));
    add(GoldenUI.text(x + 24, y + 50, w - 48, 'Tab / Up / Down: next field   Enter: create   Esc: cancel', 14, GoldenUI.MUTED));

    var defaults = ['My Mod', 'my-mod', '', '1.0.0', ''];
    for (i in 0...labels.length)
    {
      var fy = y + 86 + i * 58;
      add(GoldenUI.text(x + 24, fy + 6, 180, labels[i], 16));
      var input = new FlxInputText(x + 210, fy, w - 240, defaults[i], 16, FlxColor.WHITE, 0xFF2C2436);
      input.font = Paths.font('vcr.ttf');
      input.fieldBorderColor = GoldenUI.GOLD_DARK;
      input.fieldBorderThickness = 2;
      input.caretColor = GoldenUI.GOLD;
      input.maxChars = i == 4 ? 200 : 64;
      input.scrollFactor.set();
      if (i == 1) input.filterMode = REG(~/[^a-z0-9_-]/g);
      if (i == 3) input.filterMode = REG(~/[^0-9.a-zA-Z+-]/g);
      final idx = i;
      input.onFocusChange.add(function(f:Bool) if (f) focusIndex = idx);
      input.onTextChange.add(function(t:String, _) onFieldChanged(idx, t));
      fields.push(input);
      add(input);
    }
    errorText = GoldenUI.text(x + 24, y + h - 100, w - 48, '', 15, GoldenUI.BAD);
    add(errorText);
    add(new GoldenButton(x + w - 360, y + h - 56, 160, 40, 'Create (Enter)', submit));
    add(new GoldenButton(x + w - 184, y + h - 56, 160, 40, 'Cancel (Esc)', cancel));
    UISound.play(Open);
    focus(0);
  }

  function onFieldChanged(idx:Int, t:String):Void
  {
    if (idx == 0 && !folderEdited) fields[1].text = ModOps.slugify(t);
    if (idx == 1) folderEdited = true;
    errorText.text = '';
  }

  function focus(i:Int):Void
  {
    focusIndex = (i + fields.length) % fields.length;
    fields[focusIndex].startFocus();
    fields[focusIndex].setSelection(0, fields[focusIndex].text.length);
  }

  function submit():Void
  {
    var info:NewModInfo = {
      title: fields[0].text,
      folder: fields[1].text,
      author: fields[2].text,
      modVersion: fields[3].text,
      description: fields[4].text
    };
    var err = ModOps.createMod(info);
    if (err != null)
    {
      errorText.text = err;
      UISound.play(Error);
      trace('[GOLDEN] Create mod failed: $err');
      return;
    }
    trace('[GOLDEN] Created mod "${info.folder}"');
    UISound.play(Select);
    for (f in fields)
      f.endFocus();
    close();
    onCreated(info.folder);
  }

  function cancel():Void
  {
    for (f in fields)
      f.endFocus();
    UISound.play(Back);
    close();
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);
    if (inputBlocked()) return;
    if (FlxG.keys.justPressed.ESCAPE) cancel();
    else if (FlxG.keys.justPressed.ENTER) submit();
    else if (FlxG.keys.justPressed.TAB) focus(focusIndex + (FlxG.keys.pressed.SHIFT ? -1 : 1));
    else if (FlxG.keys.justPressed.DOWN) focus(focusIndex + 1);
    else if (FlxG.keys.justPressed.UP) focus(focusIndex - 1);
  }
}

/** Single-line text prompt (Enter = OK, Esc = cancel). */
class GoldenPromptSubState extends GoldenSubState
{
  var message:String;
  var initial:String;
  var onOk:String->Void;
  var input:FlxInputText;

  public function new(message:String, initial:String, onOk:String->Void)
  {
    super(0xAA000000);
    this.message = message;
    this.initial = initial;
    this.onOk = onOk;
  }

  override function create():Void
  {
    super.create();
    var w = 760, h = 200;
    var x = (FlxG.width - w) / 2, y = (FlxG.height - h) / 2;
    add(GoldenUI.panel(x - 2, y - 2, w + 4, h + 4, GoldenUI.GOLD));
    add(GoldenUI.panel(x, y, w, h, 0xFF1A1420));
    add(GoldenUI.text(x + 24, y + 18, w - 48, message, 16));
    input = new FlxInputText(x + 24, y + 70, w - 48, initial, 18, FlxColor.WHITE, 0xFF2C2436);
    input.font = Paths.font('vcr.ttf');
    input.fieldBorderColor = GoldenUI.GOLD_DARK;
    input.scrollFactor.set();
    add(input);
    add(new GoldenButton(x + w - 360, y + h - 56, 160, 40, 'OK (Enter)', ok));
    add(new GoldenButton(x + w - 184, y + h - 56, 160, 40, 'Cancel (Esc)', cancel));
    input.startFocus();
    input.setSelection(0, initial.length);
    UISound.play(Open);
  }

  function ok():Void
  {
    var v = input.text;
    input.endFocus();
    UISound.play(Select);
    close();
    onOk(v);
  }

  function cancel():Void
  {
    input.endFocus();
    UISound.play(Back);
    close();
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);
    if (inputBlocked()) return;
    if (FlxG.keys.justPressed.ENTER) ok();
    else if (FlxG.keys.justPressed.ESCAPE) cancel();
  }
}
