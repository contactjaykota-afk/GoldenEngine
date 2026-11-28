package golden.studio;

import funkin.data.song.SongRegistry;
import funkin.data.story.level.LevelRegistry;
import funkin.ui.transition.LoadingState;
import golden.studio.ScriptEditorState.OpenDoc;

/** What the editor needs to come back exactly as it was. */
typedef StudioSession =
{
  var modDir:String;
  var docs:Array<OpenDoc>;
  var current:Int;
  var songId:String;
  var difficulty:String;
}

/**
 * Golden Studio — Play-in-Editor.
 *
 * Play (F9 in the script editor): unsaved files are saved (validated), mods are reloaded (HScript and
 * Lua changes become live), and the chosen song starts in practice mode (no scores saved).
 * Stop (F9 anywhere while a session is active): returns to the script editor with the same tabs,
 * caret positions and any text — nothing is lost. Engine `.hx` source changes cannot be hot-loaded;
 * they need a rebuild (see ROADMAP N4).
 */
class GoldenStudio
{
  public static var session:Null<StudioSession> = null;

  /** Last song played from the editor (default for the next Play). */
  public static var lastSong:String = 'bopeebo';
  public static var lastDifficulty:String = 'normal';

  /** Start `songId` / `difficulty`. Returns an error message, or null if the song is starting. */
  public static function playSong(songId:String, difficulty:String):Null<String>
  {
    var song = SongRegistry.instance.fetchEntry(songId);
    if (song == null) return 'Song "$songId" not found (check the id, and that its mod is enabled).';
    if (song.getDifficulty(difficulty, Constants.DEFAULT_VARIATION) == null)
    {
      var diffs = song.listDifficulties(Constants.DEFAULT_VARIATION, null, true, true);
      return 'Song "$songId" has no "$difficulty" difficulty (has: ${diffs.join(', ')}).';
    }
    var levelId:Null<String> = null;
    for (id in LevelRegistry.instance.listEntryIds())
    {
      var level = LevelRegistry.instance.fetchEntry(id);
      if (level != null && level.getSongs().contains(songId))
      {
        levelId = id;
        break;
      }
    }
    if (levelId != null) Paths.setCurrentLevel(levelId);
    lastSong = songId;
    lastDifficulty = difficulty;
    trace('[GOLDEN] Play-in-Editor: starting "$songId" ($difficulty) from Studio');
    LoadingState.loadPlayState({
      targetSong: song,
      targetDifficulty: difficulty,
      practiceMode: true,
      minimalMode: false
    }, true);
    return null;
  }

  /** Called every frame by GoldenDevTools: F9 outside the editor returns to it. (F5 is upstream's asset reload.) */
  /** Set by Golden editors' "Test in gameplay": F9 during the song returns to that editor. */
  public static var editorReturn:Null<Void->Void> = null;

  public static function update():Void
  {
    if (editorReturn != null && Std.isOfType(FlxG.state, funkin.play.PlayState) && FlxG.keys.justPressed.F9)
    {
      trace('[GOLDEN] Editor test: F9, returning to the editor');
      FlxG.sound.music?.stop();
      var back = editorReturn;
      editorReturn = null;
      golden.GoldenPlayOverrides.clear();
      back();
      return;
    }
    if (editorReturn == null && (golden.GoldenPlayOverrides.player != null || golden.GoldenPlayOverrides.opponent != null))
    {
      var n = Type.getClassName(Type.getClass(FlxG.state));
      if (n.indexOf('MainMenuState') >= 0 || n.indexOf('FreeplayState') >= 0 || n.indexOf('StoryMenuState') >= 0) golden.GoldenPlayOverrides.clear();
    }
    if (session == null || session.songId == '') return;
    if (Std.isOfType(FlxG.state, ScriptEditorState)) return;
    if (FlxG.keys.justPressed.F9)
    {
      trace('[GOLDEN] Play-in-Editor: stop, returning to Studio');
      FlxG.sound.music?.stop();
      var dir = session.modDir;
      FlxG.switchState(() -> new ScriptEditorState(dir));
    }
  }
}
