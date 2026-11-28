package golden;

/** Golden Engine's own version (independent of the FNF base version shown next to it). */
class GoldenVersion
{
  public static inline var VERSION:String = '0.2.0-alpha';
  public static inline var NAME:String = 'Golden Engine';

  /** "Golden Engine 0.1.0-alpha (FNF v0.8.7)" */
  public static function label():String
    return '$NAME $VERSION (FNF ${Constants.VERSION})';
}
