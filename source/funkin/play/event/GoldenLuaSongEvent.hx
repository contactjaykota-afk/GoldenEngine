package funkin.play.event;

import funkin.data.song.SongData.SongEventData;
import funkin.data.event.SongEventSchema;
import funkin.data.event.SongEventSchema.SongEventFieldType;

/**
 * Golden Engine (new file): "Lua Script" chart event. Runs `scripts/events/<script>.lua` from the
 * base game or an enabled mod, calling its `onEvent(name, value)` with the event's value string.
 * Every running gameplay Lua script also receives onEvent for every chart event (GoldenLuaModule).
 */
class GoldenLuaSongEvent extends SongEvent
{
  public function new()
  {
    super('golden-lua');
  }

  override public function handleEvent(data:SongEventData):Void
  {
    if (PlayState.instance == null) return;
    var script:String = data.getString('script') ?? '';
    if (script == '')
    {
      trace('[LUA] ERROR "Lua Script" event without a script name at ${data.time} ms');
      return;
    }
    golden.lua.GoldenLua.runEventScript(script, data.getString('value') ?? '');
  }

  override public function getTitle():String
  {
    return 'Lua Script (Golden)';
  }

  override public function getEventSchema():SongEventSchema
  {
    return new SongEventSchema([
      {
        name: 'script',
        title: 'Script (scripts/events/<name>.lua)',
        defaultValue: '',
        type: SongEventFieldType.STRING
      },
      {
        name: 'value',
        title: 'Value (passed to onEvent)',
        defaultValue: '',
        type: SongEventFieldType.STRING
      }
    ]);
  }
}
