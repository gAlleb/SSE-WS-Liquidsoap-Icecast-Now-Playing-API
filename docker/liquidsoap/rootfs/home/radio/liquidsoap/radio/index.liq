settings.log.file := true
settings.log.file.path := "/home/radio/liquidsoap/radio/log/radio.log"
settings.log.stdout := true
settings.server.telnet := true
settings.server.telnet.port := 1234
settings.harbor.bind_addrs.set(["0.0.0.0"])
settings.encoder.metadata.export.set(["artist","title","album","song", "on_air"])
settings.request.deprecated_on_air_metadata := true 
%include "radio.liq"
