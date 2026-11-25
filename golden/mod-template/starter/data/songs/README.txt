Song data: one folder per song, named after the song id.
  data/songs/<song-id>/<song-id>-metadata.json   (name, artist, BPM, characters, stage, difficulties)
  data/songs/<song-id>/<song-id>-chart.json      (notes + events for each difficulty)
The Chart Editor (Debug Menu -> Chart Editor) creates and saves both files.
A song only appears in Freeplay once it is listed in a week (data/levels).
