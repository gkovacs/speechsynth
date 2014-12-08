(function(){
  var mongourl, ismongo, request, express, querystring, mongo, Grid, MongoClient, speechsynthdir, path, fs, app, allowedLanguages, createDirectories, speechsynthFs, speechsynthMongo;
  mongourl = process.env.MONGOHQ_URL;
  ismongo = mongourl != null;
  console.log('mongourl is: ' + mongourl);
  request = require('request');
  express = require('express');
  querystring = require('querystring');
  if (ismongo) {
    mongo = require('mongodb');
    Grid = mongo.Grid;
    MongoClient = mongo.MongoClient;
  } else {
    speechsynthdir = __dirname + '/speechsynth/';
    path = require('path');
    fs = require('fs');
  }
  app = express();
  app.set('port', process.env.PORT || 5001);
  app.listen(app.get('port'), '0.0.0.0');
  console.log('Listening on port ' + app.get('port'));
  allowedLanguages = {
    'en': 'en',
    'vi': 'vi',
    'zh-CN': 'zh-CN',
    'ko': 'ko',
    'ja': 'ja'
  };
  createDirectories = function(){
    var lang, results$ = [];
    if (!fs.existsSync(speechsynthdir)) {
      fs.mkdirSync(speechsynthdir);
    }
    for (lang in allowedLanguages) {
      if (!fs.existsSync(speechsynthdir + lang)) {
        results$.push(fs.mkdirSync(speechsynthdir + lang));
      }
    }
    return results$;
  };
  speechsynthFs = function(req, res){
    var lang, word, outfile;
    lang = req.query.lang;
    if (allowedLanguages[lang] == null) {
      res.send('lang not allowed');
      return;
    }
    word = req.query.word;
    if (word == null || word.length === 0) {
      res.send('need word');
      return;
    }
    if (word.indexOf('/') !== -1) {
      res.send('slashes not allowed');
      return;
    }
    outfile = speechsynthdir + lang + '/' + word + '.mp3';
    if (fs.existsSync(outfile)) {
      res.sendFile(outfile);
      return;
    }
    return request.get({
      url: 'https://translate.google.com/translate_tts?' + querystring.stringify({
        ie: 'UTF-8',
        tl: lang,
        q: word
      }),
      encoding: null,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2236.0 Safari/537.36'
      }
    }, function(error, response, body){
      console.log('requested for ' + word + ' in ' + lang);
      fs.writeFileSync(outfile, body);
      res.type('audio/mpeg');
      res.send(body);
    });
  };
  speechsynthMongo = function(req, res){
    var lang, word;
    lang = req.query.lang;
    if (allowedLanguages[lang] == null) {
      res.send('lang not allowed');
      return;
    }
    word = req.query.word;
    if (word == null || word.length === 0) {
      res.send('need word');
      return;
    }
    return MongoClient.connect(mongourl, function(err, db){
      var grid, key;
      grid = Grid(db);
      key = 'gsynth|' + lang + '|' + word;
      return grid.get(key, function(err2, res2){
        if (res2 != null) {
          res.type('audio/mpeg');
          return res.send(res2);
        } else {
          return request.get({
            url: 'https://translate.google.com/translate_tts?' + querystring.stringify({
              ie: 'UTF-8',
              tl: lang,
              q: word
            }),
            encoding: null,
            headers: {
              'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2236.0 Safari/537.36'
            }
          }, function(error, response, body){
            console.log('requested ' + word + ' in ' + lang);
            return grid.put(body, {
              _id: key,
              content_type: 'audio/mpeg'
            }, function(err3, res3){
              res.type('audio/mpeg');
              return res.send(body);
            });
          });
        }
      });
    });
  };
  if (ismongo) {
    app.get('/speechsynth', speechsynthMongo);
  } else {
    createDirectories();
    app.get('/speechsynth', speechsynthFs);
  }
}).call(this);
