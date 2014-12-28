mongohq = process.env.MONGOHQ_URL
mongolab = process.env.MONGOLAB_URI
mongosoup = process.env.MONGOSOUP_URL

mongourl = mongohq ? mongolab ? mongosoup
# export MONGOHQ_URL='mongodb://localhost:27017/default'
ismongo = mongourl?

console.log 'mongourl is: ' + mongourl

require! {
  'request'
  'express'
  'querystring'
}

if ismongo
  mongo = require 'mongodb'
  mc = require('memjs').Client.create()
  Grid = mongo.Grid
  MongoClient = mongo.MongoClient
else
  speechsynthdir = __dirname + '/speechsynth/'
  require! {
    'path'
    'fs'
  }

app = express()

# app.use bodyParser.json()
# app.use express.static(path.join(__dirname, ''))

app.set 'port', (process.env.PORT || 5001)

app.locals.pretty = true

#app.use (req, res, next) ->
#  app.locals.pretty = true
#  next()

app.listen app.get('port'), '0.0.0.0'
console.log 'Listening on port ' + app.get('port')

allowed-languages = {
  'en'
  'vi'
  'zh-CN'
  'ko'
  'ja'
  'fr'
  'es'
  'pt'
  'de'
  'nl'
  'ru'
}

create-directories = ->
  if not fs.existsSync(speechsynthdir)
    fs.mkdirSync(speechsynthdir)
  for lang of allowed-languages
    if not fs.existsSync(speechsynthdir + lang)
      fs.mkdirSync(speechsynthdir + lang)

speechsynth-fs = (req, res) ->
  #console.log 'foobar'
  lang = req.query.lang
  if not allowed-languages[lang]?
    res.send 'lang not allowed'
    return
  word = req.query.word
  if not word? or word.length == 0
    res.send 'need word'
    return
  if word.indexOf('/') != -1
    res.send 'slashes not allowed'
    return
  outfile = speechsynthdir + lang + '/' + word + '.mp3'
  if fs.existsSync(outfile)
    res.send-file outfile
    return
  request.get {url: 'https://translate.google.com/translate_tts?' + querystring.stringify({ie: 'UTF-8', tl: lang, q: word}), encoding: null, headers: { 'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2236.0 Safari/537.36'} }, (error, response, body) ->
    console.log 'requested for ' + word + ' in ' + lang
    #console.log response
    fs.writeFileSync outfile, body
    #res.set-header 'Content-type', 'audio/mpeg'
    res.type 'audio/mpeg'
    res.send body
    #res.send body
    #res.send-file outfile
    return

speechsynth-mongo = (req, res) ->
  lang = req.query.lang
  if not allowed-languages[lang]?
    res.send 'lang not allowed'
    return
  word = req.query.word
  if not word? or word.length == 0
    res.send 'need word'
    return
  #res.send 'todo not yet implemented'
  #return
  key = 'gsynth|' + lang + '|' + word
  mc.get key, (err0, res0) ->
    if val0?
      res.type 'audio/mpeg'
      res.send res0
    else
      MongoClient.connect mongourl, (err, db) ->
        grid = Grid db
        grid.get key, (err2, res2) ->
          if res2? #
            res.type 'audio/mpeg'
            res.send res2
            db.close()
            mc.set key, res2
          else
            request.get {url: 'https://translate.google.com/translate_tts?' + querystring.stringify({ie: 'UTF-8', tl: lang, q: word}), encoding: null, headers: { 'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2236.0 Safari/537.36'} }, (error, response, body) ->
              console.log 'requested ' + word + ' in ' + lang
              mc.set key, body
              grid.put body, {_id: key, content_type: 'audio/mpeg'}, (err3, res3) ->
                res.type 'audio/mpeg'
                res.send body
                db.close()


if ismongo
  app.get '/speechsynth', speechsynth-mongo
else
  create-directories()
  app.get '/speechsynth', speechsynth-fs

