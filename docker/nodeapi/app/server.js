const express = require('express');
const app = express();
app.use(express.json({limit : 52428800}));
const server = require('http').createServer(app);
const EventEmitter = require('events');
const eventEmitter = new EventEmitter();
eventEmitter.setMaxListeners(500);
const fs = require('fs');
let np, np_data, np_data_coma; 
let original_timestamp = 0;
const axios = require('axios');


/////////////////////////////////
////////////CENTRIFUGO///////////
/////////////////////////////////

const centrifugoApiClient = axios.create({
  baseURL: `http://centrifugo:9998/api/publish`,
  headers: {
    'X-API-key': '111fff39-283d-1111-88ea-111fff98a98a',
    'Content-Type': 'application/json',
  },
});

function authentication(req, res, next) {
    const authheader = req.headers.authorization;
    if (!authheader) {

        res.sendStatus(500);
    }
    try {
    const auth = new Buffer.from(authheader.split(' ')[1],'base64').toString().split(':');
    const user = auth[0];
    const pass = auth[1];
    if (user == 'user' && pass == 'passwd') {
        // If Authorized user
        next();
    } else {

        res.sendStatus(500);
    }
   } catch (e) {
    console.error(e.message); 
    console.log("No auth data is supplied"); 
   }
}

app.use(authentication)

app.post('/liq', (req, res) => {

np_data = req.body;

send_post_to_centrifugo_on_track_change();
res.sendStatus(200);
});

async function send_post_to_centrifugo_on_track_change() {
  let array = np_data;    
  try {     
      if (array.now_playing.song.text !== null && array.now_playing.song.text !== original_timestamp) { 
          try {
               await centrifugoApiClient.post('', {
               channel: "station:radio",
               data: {
                np: array, 
                trigger: "track has changed"
                     },
               });
          } catch (e) {
          console.error(e.message);
          }
      original_timestamp = array.now_playing.song.text;
      }
  } catch (e) {
      return console.error(e);  
  } 
}

async function send_post_to_centrifugo() {
  try {
    await centrifugoApiClient.post('', {
        channel: "station:radio",
        data: {np: np_data},
      });
  } catch (e) {
    console.error(e.message);
  }
}

eventEmitter.on('send_post_to_centrifugo', send_post_to_centrifugo);

const np_interval_CF = setInterval(() => {
eventEmitter.emit('send_post_to_centrifugo')
}, 15000);



const port = process.env.PORT || 9999
server.listen(port, () => console.log(`Listening on ${port}`))