s = playlist("/home/radio/music")

default_queue = request.queue()

interrupting_queue = request.queue()	
		
s = fallback(track_sensitive=true, [default_queue, s])

s = fallback(track_sensitive=false, [interrupting_queue, s])

def play(request)
 fname = request.query["file"]
 option = request.query["track_sensitive"]

 log.important("Serving file #{fname}. track_sensitive=true")

   if file.exists(fname) then

    if option == "true" then
      default_queue.push.uri("#{fname}")
      http.response(data="Request pushed to default queue.")
    else
      interrupting_queue.push.uri("#{fname}")
      http.response(data="Request pushed to interrupting queue.")
    end
   else
    http.response(status_code=404, data="Invalid file.")
   end
end

harbor.http.register.simple("/queueFile", play, port=8007, method="GET")

def play_playlist(request)
 playlist_name = request.query["playlist_name"]
 option = request.query["track_sensitive"]
 if file.exists(playlist_name) then
 
 if option == "true" then

  tracks = list.iter(fun (x) -> begin
       let (_, uri) = x
       default_queue.push.uri(uri)
     end, playlist.parse("#{playlist_name}"))

  q = default_queue.queue()

          http.response(content_type="application/json; charset=UTF-8", status_code=200, 
          data=json.stringify({
          status = "success", message = "Pushed to default queue: #{playlist_name}.", 
          remaining_tracks_in_queue = list.length(q), 
          files_pushed = playlist.files(playlist_name)
          }))
 else

  tracks = list.iter(fun (x) -> begin
       let (_, uri) = x
       interrupting_queue.push.uri(uri)
     end, playlist.parse("#{playlist_name}"))

  q = interrupting_queue.queue()

          http.response(content_type="application/json; charset=UTF-8", status_code=200, 
          data=json.stringify({
          status = "success", message = "Pushed to interrupting queue: #{playlist_name}.", 
          remaining_tracks_in_queue = list.length(q), 
          files_pushed = playlist.files(playlist_name)
          }))

 end
 
  else
    http.response(status_code=404, data="Invalid playlist file.")
  end

 end

harbor.http.register.simple("/queuePlaylist", play_playlist, port=8007, method="GET")

def flush_and_skip_queue(r)

 option = r.query["queueType"]

 if option == "default" then
  q = default_queue.queue()
  default_queue.set_queue([])
  default_queue.skip()
  list.iter(request.destroy, q)
  http.response(data="default_queue is emptied.")
 else 
  q = interrupting_queue.queue()
  interrupting_queue.set_queue([])
  interrupting_queue.skip()
  list.iter(request.destroy, q)
  http.response(data="interrupting_queue is emptied.")
 end

end

harbor.http.register.simple("/skipQueue", flush_and_skip_queue, port=8007)

songHistory = ref([])
np_timestamp = ref(0.0)
np_on_air = ref("")

def save_history(m, ~last=10)
  def null_list(key, _list)
    list.assoc.mem(key, _list) ? list.assoc(key, _list) : ""
  end
  def null_float(f)
    f == infinity ? null() : f
  end
  
  pre_artist = null_list("artist", m)
  
  pre_title = null_list("title", m)

def get_cover_base64(~coverart_mime=null(), ~base64=true, m) =
  c = metadata.cover(coverart_mime=coverart_mime, m)
    if
      null.defined(c)
    then
      c = null.get(c)
      string.data_uri.encode(base64=base64, mime=c.mime, c)
    else
     ""
    end
end
 
  default_stream_title = "Default"
  stream_title =
  if pre_title == "" then
    default_stream_title
  elsif pre_artist == "" then
    pre_title
  else
    "#{pre_artist} - #{pre_title}"
  end

  artist = ref("")
  title = ref("")

     if pre_artist == "" then
        if string.contains(substring=" - ", m["title"]) then
            let (a, t) = string.split.first(separator=" - ", m["title"])
       	    title := t
            artist := a
        end
     else
            title := pre_title
            artist := pre_artist
     end

     np_timestamp := time()
     np_on_air := time.string("%Y/%m/%d %H:%M:%S")

if (m["jingle_mode"] != "true") then
  sh = {

      played_at = np_timestamp(),
      played_at_timestamp_old = null_list("on_air_timestamp", m),
      played_at_timestamp = np_timestamp(),
      played_at_date_time_old = null_list("on_air", m),
      played_at_date_time = np_on_air(),
      playlist = null_list("playlist", m),
      filename = null_list("filename", m),

      song = {
		text = stream_title,
		artist = artist(),
    title = title(),
		album = null_list("album", m),
 	 	genre = null_list("genre", m),
		#cover = get_cover_base64(m)

	   }
  }
  songHistory := sh::songHistory()
 
  if list.length(songHistory()) > last then
    songHistory := list.prefix(last,songHistory())
  end  

  data = json.stringify(songHistory(), compact=true)
  ignore(file.write(data=data, append=false, "/home/radio/liquidsoap/radio/log/song_history.json"))

end 

end
s.on_metadata(save_history)

def send_mq_event(payload)


  def handle_http_error(error)
    log.important(
      "Unable to send mq event. #{error.message}",
      label="http"
    )
  end
  
  def handle_http_response(result)
    if result.status_code != 200 then
      log.important(
        "Unable to send mq event. #{result.status_code} #{result.status_message} \
         #{string.quote(result)}",
        label="http"
      )
    end
  end

auth = string.base64.encode("user:passwd")

data = payload

 response = 
 try

    http.post(
    "http://nodeapi:9999/liq",
    data=data,
    headers=[
      ("Content-Type", "application/json"),
      ("Authorization", "Basic #{auth}"),
    ],
    )
 catch error do
 handle_http_error(error)
 null()
 end
ignore(null.map(handle_http_response, response))
()
end

def write_json_nowplaying(s)

  def write_data()

  def null_float(f)
    f == infinity ? null() : f
  end

  def null_list(key, _list)
    list.assoc.mem(key, _list) ? list.assoc(key, _list) : ""
  end

  m = s.last_metadata() ?? []
 
  pre_artist = null_list("artist", m)
  
  pre_title = null_list("title", m)

def get_cover_base64(~coverart_mime=null(), ~base64=true, m) =
  c = metadata.cover(coverart_mime=coverart_mime, m)
    if
      null.defined(c)
    then
      c = null.get(c)
      string.data_uri.encode(base64=base64, mime=c.mime, c)
    else
     ""
    end
end
  
  default_stream_title = "Radio"
  stream_title =
  if pre_title == "" then
    default_stream_title
  elsif pre_artist == "" then
    pre_title
  else
    "#{pre_artist} - #{pre_title}"
  end

  artist = ref("")
  title = ref("")

      if pre_artist == "" then
        if string.contains(substring=" - ", m["title"]) then
            let (a, t) = string.split.first(separator=" - ", m["title"])
       	    title := t
            artist := a
        end
     else
            title := pre_title
            artist := pre_artist
     end


  np = {

    station = {
      name = "Station",
      shortcode = "radio",
      timezone = "Europe/London"

    },
    now_playing = {
      played_at = np_timestamp(),
      played_at_timestamp_old = null_list("on_air_timestamp", m),
      played_at_timestamp = np_timestamp(),
      played_at_date_time_old = null_list("on_air", m),
      played_at_date_time = np_on_air(),
      duration = null_float(source.duration(s)),
      elapsed = null_float(source.elapsed(s)),
      remaining = null_float(source.remaining(s)),
      playlist = null_list("playlist", m),
      filename = null_list("filename", m),

      song = { 
           	text = stream_title,
     	  	  artist = artist(),
           	title = title(),
          	album = null_list("album", m),
 	 	        genre = null_list("genre", m),
		        #cover = get_cover_base64(m)
	     }     
       },

    song_history = songHistory()
  
  }


if (m["jingle_mode"] != "true") then
send_mq_event(json.stringify(np, compact=true))
end

 end

  thread.run(write_data, every=1.0, fast=false)

end
write_json_nowplaying(s)

last_metadata = ref([])
def handle_jingle_mode(m) =
    if (m["jingle_mode"] == "true") then
        last_metadata()
    else
        last_metadata.set(m)
        m
    end
end

s = metadata.map(update=false, strip=true, handle_jingle_mode, s)

def get_metadata(_)

  def null_float(f)
    f == infinity ? null() : f
  end

  def null_list(key, _list)
    list.assoc.mem(key, _list) ? list.assoc(key, _list) : ""
  end

  m = s.last_metadata() ?? []

  pre_artist = null_list("artist", m)
  
  pre_title = null_list("title", m)

def get_cover_base64(~coverart_mime=null(), ~base64=true, m) =
  c = metadata.cover(coverart_mime=coverart_mime, m)
    if
      null.defined(c)
    then
      c = null.get(c)
      string.data_uri.encode(base64=base64, mime=c.mime, c)
    else
     ""
    end
end
  
  default_stream_title = "Default" # null()
  stream_title =
  if pre_title == "" then
    default_stream_title
  elsif pre_artist == "" then
    pre_title
  else
    "#{pre_artist} - #{pre_title}"
  end

  artist = ref("")
  title = ref("")

     if pre_artist == "" then
        if string.contains(substring=" - ", m["title"]) then
            let (a, t) = string.split.first(separator=" - ", m["title"])
       	    title := t
            artist := a
        end
     else
            title := pre_title
            artist := pre_artist
     end

  data = {

    station = {
      name = "Radio",
      shortcode = "radio",
      timezone = "Europe/London"

    },
    now_playing = {
      played_at = np_timestamp(),
      played_at_timestamp_old = null_list("on_air_timestamp", m),
      #played_at_timestamp = np_timestamp(),
      played_at_date_time_old = null_list("on_air", m),
      #played_at_date_time = np_on_air(),
      duration = null_float(source.duration(s)),
      elapsed = null_float(source.elapsed(s)),
      remaining = null_float(source.remaining(s)),
      playlist = null_list("playlist", m),
      filename = null_list("filename", m),

      song = { 
           	text = stream_title,
     	  	  artist = artist(),
          	title = title(),
          	album = null_list("album", m),
 	 	        genre = null_list("genre", m),
		        #cover = get_cover_base64(m)
	     }
     
     },

    song_history = songHistory()
  
  }
 try

  http.response(
    status_code=200,
    headers=[
                ("Content-Type", "application/json"),
                ("Access-Control-Allow-Origin","*")
            ],
    content_type="application/json; charset=UTF-8",
    data=json.stringify(data, compact=true)
  )

 catch error do

  log.severe(error.message, label="http")
  http.response(
    status_code=500,
    content_type="application/json; charset=UTF-8",
    data='{"status":"error","message":"Failed to serialize response data"}' ^ "\n"
  )

  end
end

harbor.http.register.simple("/nowplaying", get_metadata, port=8007, method="GET")

def get_cover(_)


  m = s.last_metadata() ?? []


def get_cover_base64(~coverart_mime=null(), ~base64=true, m) =
  c = metadata.cover(coverart_mime=coverart_mime, m)
    if
      null.defined(c)
    then
      c = null.get(c)
      string.data_uri.encode(base64=base64, mime=c.mime, c)
    else
     ""
    end
end
  

  data = {

		cover = get_cover_base64(m)
  
          }
 try

  http.response(
    status_code=200,
    content_type="text/html",
    data='<html><body><center><img height=500 width=500 src="#{get_cover_base64(m)}" /></center></body></html>'
)
  

 catch error do

  log.severe(error.message, label="http")
  http.response(
    status_code=500,
    content_type="application/json; charset=UTF-8",
    data='{"status":"error","message":"Failed to serialize response data"}' ^ "\n"
  )

  end
end

harbor.http.register.simple("/cover", get_cover, port=8007, method="GET")

meta = ref([])
s.on_metadata(fun (m) -> meta := m)
def get_all_meta(_, response) =
  response.json(meta())
end
harbor.http.register(port=8007, method="GET", "/metadata", get_all_meta)

s = amplify(1.,override="liq_amplify",s)

s = mksafe(s)
 
%include "output.liq"

def skipper(_)
s.skip()
http.response(data="The current song was skipped!")
end
harbor.http.register.simple(port=8007, "/skip", skipper)
