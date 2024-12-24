#### So this is very very basic hobby radio setup with WS and SSE (via Centrifugo) for folks who're trying out `liquidsoap` and `icecast` and want to have `nowplaying` info on their websites or to try at local home environment. All you need is Docker.

#### It illustrates:

- How Liquidsoap can send `nowplaying` info to your website or homepage using `Server Sent Events` or `Websocket`. 
- It urges you to stop fetching our `tired` `status-json.xsl` :) Because you may want to stop using `Icecast` at all and look into `HLS`.
- Liquidsoap doesn't send data directly to `Centrifugo` (although it can) because it's more fancy to have an API where data is collected and sent further enabling "on_track_change" notifications and tunable intervals.

#### What we have inside:

- Liquidsoap v2.3.0 - https://github.com/savonet/liquidsoap (With `entrypoint` script from @vitoucepi)
- Icecast KH icecast-2.4.0-kh22 - https://github.com/karlheyes/icecast-kh
- Centrifugo latest - https://github.com/centrifugal/centrifugo
- Node.js API

#### To setup

- Download the repo
- Change `- /path/to/music:/home/radio/music` in the `docker-compose.yaml` file. `/path/to/music` -> `/your/real/path/to/music`
- RUN: `docker compose up -d`
- It's nice to run under 1000 user acoount.

#### Of course you can edit and tune everything inside `docker folder` and scale it to be a real radio station on the internet. 

<hr/>

### After installation you'll have following endpoints:

- http://localhost:8000/stream - your Icecast stream with music
- http://localhost:8007/skipQueue?queueType=default - skips default queue
- http://localhost:8007/skipQueue - skips interrupting queue
- http://localhost:8007/queuePlaylist?track_sensitive=true&playlist_name=/path/to/playlist - queues playlist to default queue
- http://localhost:8007/queuePlaylist?playlist_name=/path/to/playlist - queues playlist to interrupting queue
- http://localhost:8007/queueFile?track_sensitive=true&file=/path/to/file - queues file to default queue
- http://localhost:8007/queueFile?file=/path/to/file - queues file to interrupting queue
- http://localhost:8007/metadata - all metadata endpoint
- http://localhost:8007/skip - skip endpoint 
- http://localhost:8007/nowplaying - nowplaying info endpoint
Will give us a json with nowplaying and song history (10 tracks):

```json
{"station":
{"name":"Radio","shortcode":"radio","timezone":"Europe/London"},
"now_playing":
{"played_at":1735060884.4,
"played_at_timestamp_old":"1735060884.39",
"played_at_date_time_old":"2024/12/24 17:21:24",
"duration":250.494943311,
"elapsed":57.38,
"remaining":193.114943311,
"playlist":"",
"filename":"/home/radio/music/Various Artists - BIRP! Best of 2020/041 - Kowloon - Come Over.mp3",
"song":
{"text":"Kowloon - Come Over",
"artist":"Kowloon",
"title":"Come Over",
"album":"Come Over - Single",
"genre":"Alternative"}},
"song_history":
[{"played_at":1735060884.4,"played_at_timestamp_old":"1735060884.39","played_at_timestamp":1735060884.4,"played_at_date_time_old":"2024/12/24 17:21:24","played_at_date_time":"2024/12/24 17:21:24","playlist":"","filename":"/home/radio/music/Various Artists - BIRP! Best of 2020/041 - Kowloon - Come Over.mp3","song":{"text":"Kowloon - Come Over","artist":"Kowloon","title":"Come Over","album":"Come Over - Single","genre":"Alternative"}}]}

```

Don't fetch it :) cause we got SSE and WS :) :

#### Endpoint to get SSE (WS) events

- wss://localhost:9998/connection/ws
- http://localhost:9998/connection/sse

To get our station data we connect to: 

- http://localhost:9998/connection/sse?cf_connect={%22subs%22:{%22station:radio%22:{%22recover%22:true}}}

Basic `js` implementations (Just like `AzuraCast` ones): 

```js
const sseBaseUri = "http://localhost:9998/connection/sse";
const sseUriParams = new URLSearchParams({
  "cf_connect": JSON.stringify({
    "subs": {
      "station:radio": {"recover": true}
    }
  })
});
const sseUri = sseBaseUri+"?"+sseUriParams.toString();
const sse = new EventSource(sseUri);

let nowplaying = {};
let currentTime = 0;

// This is a now-playing event from a station. Update your now-playing data accordingly.
function handleSseData(ssePayload, useTime = true) {
  const jsonData = ssePayload.data;

  if (useTime && 'current_time' in jsonData) {
    currentTime = jsonData.current_time;
  }

  nowplaying = jsonData.np;
}

sse.onmessage = (e) => {
  const jsonData = JSON.parse(e.data);

  if ('connect' in jsonData) {
    const connectData = jsonData.connect;

    if ('data' in connectData) {
      // Legacy SSE data
      connectData.data.forEach(
        (initialRow) => handleSseData(initialRow)
      );
    } else {
      // New Centrifugo time format
      if ('time' in connectData) {
        currentTime = Math.floor(connectData.time / 1000);
      }

      // New Centrifugo cached NowPlaying initial push.
      for (const subName in connectData.subs) {
        const sub = connectData.subs[subName];
        if ('publications' in sub && sub.publications.length > 0) {
          sub.publications.forEach((initialRow) => handleSseData(initialRow, false));
        }
      }
    }
  } else if ('pub' in jsonData) {
    handleSseData(jsonData.pub);
  }
};
```

WS:

```js
let socket = new WebSocket("wss://localhost:9998/connection/ws);

socket.onopen = function(e) {
  socket.send(JSON.stringify({
    "subs": {
      "station:radio": {"recover": true}
    }
  });
};

let nowplaying = {};
let currentTime = 0;

// Handle a now-playing event from a station. Update your now-playing data accordingly.
function handleSseData(ssePayload, useTime = true) {
  const jsonData = ssePayload.data;

  if (useTime && 'current_time' in jsonData) {
    currentTime = jsonData.current_time;
  }

  nowplaying = jsonData.np;
}

socket.onmessage = function(e) {
  const jsonData = JSON.parse(e.data);

  if ('connect' in jsonData) {
    const connectData = jsonData.connect;

    if ('data' in connectData) {
      // Legacy SSE data
      connectData.data.forEach(
        (initialRow) => handleSseData(initialRow)
      );
    } else {
      // New Centrifugo time format
      if ('time' in connectData) {
        currentTime = Math.floor(connectData.time / 1000);
      }

      // New Centrifugo cached NowPlaying initial push.
      for (const subName in connectData.subs) {
        const sub = connectData.subs[subName];
        if ('publications' in sub && sub.publications.length > 0) {
          sub.publications.forEach((initialRow) => handleSseData(initialRow, false));
        }
      }
    }
  } else if ('pub' in jsonData) {
    handleSseData(jsonData.pub);
  }
};
```

Example of incoming data:

```json
data: {"connect":
{"client":"4fe1-9386-2ef1ede3f0fa","version":"5.4.9",
"subs":{"station:radio":
{"recoverable":true,"epoch":"kCIB",
"publications":
[{"data":{"np":{"station":
{"name":"Station","shortcode":"radio","timezone":"Europe/London"},
"now_playing":
{"played_at":1735060884.4,"played_at_timestamp_old":"1735060884.39","played_at_timestamp":1735060884.4,"played_at_date_time_old":"2024/12/24 17:21:24","played_at_date_time":"2024/12/24 17:21:24","duration":250.494943311,"elapsed":12.66,"remaining":237.834943311,"playlist":"","filename":"/home/radio/music/Various Artists - BIRP! Best of 2020/041 - Kowloon - Come Over.mp3","song":{"text":"Kowloon - Come Over","artist":"Kowloon","title":"Come Over","album":"Come Over - Single","genre":"Alternative"}},
"song_history":
[{"played_at":1735060884.4,"played_at_timestamp_old":"1735060884.39","played_at_timestamp":1735060884.4,"played_at_date_time_old":"2024/12/24 17:21:24","played_at_date_time":"2024/12/24 17:21:24","playlist":"","filename":"/home/radio/music/Various Artists - BIRP! Best of 2020/041 - Kowloon - Come Over.mp3","song":{"text":"Kowloon - Come Over","artist":"Kowloon","title":"Come Over","album":"Come Over - Single","genre":"Alternative"}}]}},"offset":3}],"recovered":true,"positioned":true,"was_recovering":true}},"ping":25,"session":"043b7d46-ab47","time":1735060899380}}
```

<hr />

#### Of course it's all highly customizable. And even icecast server info can be fetched from inside of Liquidsoap and then added to `nowplaying`:

```
...

icecast_source_name = ref("")
icecast_source_listeners = ref("")
icecast_source_start = ref("")
icecast_server_start = ref("")
icecast_source_description = ref("")

def icecast_stats()
  api_url = "http://localhost:8000/status-json.xsl?mount=/stream"  
  http_response = http.get(api_url)

  if http_response.status_code != 200 then
      log.important("Request to #{string.quote(api_url)} failed with status \
                     #{http_response.status_code}. Status message: \
                     #{string.quote(http_response.status_message)}.")
      null()
  else
    try
     let json.parse ({
        icestats
      } : {
        icestats: {
	  server_start: string,
          source: {
            genre: string,
            listener_peak: int,
            listeners: int,
            listenurl: string,
            server_description: string,
            server_name: string,
            server_type: string,
            stream_start: string,
          }
        }
      }) = http_response
      icecast_source_name := icestats.source.server_name
      icecast_source_listeners := string(icestats.source.listeners)
      icecast_source_start := icestats.source.stream_start
      icecast_server_start := icestats.server_start
      icecast_source_description := icestats.server_description
    catch _ do
      log.important("Unable to parse api response.")
      null()
    end

  end

  print("icecast_source_name: #{icecast_source_name()}")
  print("icecast_source_listeners: #{icecast_source_listeners()}")
  print("icecast_source_start: #{icecast_source_start()}")
  print("icecast_server_start: #{icecast_server_start()}")

end
thread.run(icecast_stats, every=60.)

...
```
