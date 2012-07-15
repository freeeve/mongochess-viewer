mongodb = require 'mongodb'
ObjectId = mongodb.ObjectID
replSet = new mongodb.ReplSetServers( [
    new mongodb.Server( "mongo1.skeweredrook.com", 27017, { auto_reconnect: true } ),
    new mongodb.Server( "mongo2.skeweredrook.com", 27017, { auto_reconnect: true } )
  ],
  rs_name:"skeweredrook",
  read_secondary:true
)

db = new mongodb.Db('mongochess', replSet)
#db = new mongodb.Db('mongochess', new mongodb.Server("localhost", 27017))
db.open (err, p_db) ->
  require('zappajs') 'www3.skeweredrook.com', 8001, ->
  #require('zappajs') 'localhost', 8001, ->
    @use 'zappa'
    @use 'static'

    sortScores = (that, intro, pos) ->
      if pos.moves
        for k in pos.moves
          k['attrSafeMove']=k['move'].replace("+","check").replace("=","prom")
          depth = 1
          scoreDepth = []
          for s in k.scores
            scoreDepth.push "["+(depth++)+","+s+"]"
          k['scoreDepth'] = scoreDepth
      that.render 'index', intro:intro, pos:pos

    @get '/': ->
      that = this
      p_db.collection 'positions', (err,collection) ->
        collection.findOne {"fen":"rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"}, (err,pos) ->
          intro = "Showing pre-analyzed chess positions"
          sortScores that, intro, pos

    @get '/ulvestad-variation': ->
      that = this
      p_db.collection 'positions', (err,collection) ->
        collection.findOne {"fen":"3k3r/p1p2ppp/1r6/4P3/3P3b/1PNB1b2/P4P1P/R4RK1 b - - 2 20"}, (err,pos) ->
          intro = "Showing pre-analyzed positions starting from a particular variation of the Ulvestad-variation of the two knights defense"
          sortScores that, intro, pos

    @get '/fen/:fen': ->
      that = this
      that.params.fen = that.params.fen.replace(/\_/g,'/')
      p_db.collection 'positions', (err,collection) ->
        collection.findOne "fen":that.params.fen, (err,pos) ->
          intro = "Showing pre-analyzed chess positions"
          sortScores that, intro, pos

    @view index: ->
      @title = 'mongochess'
      script ->
        "
        $(document).ready(function() {
          var mainpgn = new PgnViewer({
            boardName: '#{@pos.fen}',
            pieceSet: 'merida',
            pieceSize: 29,
            showCoordinates: true,
            boardImagePath:'http://www3.skeweredrook.com:8001',
            dontOutputNavButtons: true,
            ignoreFlipping: true,
          });
          mainpgn.setupFromFen('#{@pos.fen}');
        });
        "
      ###
      coffeescript ->
        $(document).ready ->
          mainpgn = new PgnViewer
            boardName: @pos.fen,
            pieceSet: 'merida',
            pieceSize: 29,
            showCoordinates: true,
            dontOutputNavButtons: true,
            ignoreFlipping: true,
          mainpgn.setupFromFen @pos.fen
      ###
      h1 @title
      p "
      A chess analysis system that uses Stockfish to drill into positions deeply, using several computers. The resulting analyses are stored in MongoDB.<br/>
      "
      table ->
        tr ->
          td ->
            div id:"#{@pos.fen}-container"
          td ->
            p @intro
            p "fen: " + @pos.fen
            p "position: " +  @pos.pos
            p "bestScore: " +  @pos.bestScore
            p "maxDepth: " + @pos.maxDepth
      table id:"moveList", -> 
        thead ->
          tr ->
            td "move"
            td "score"
            td "best moves"
            td "score at depth"
            td "position after best moves"
        if @pos.moves
          for k in @pos.moves
            tr -> 
              td style:"width:100px", -> 
                if k.fen then a href: "/fen/#{k.fen.replace(/\//g, '_')}", "#{k.move}" else k.move
              td style:"width:100px", ->
                if Math.abs(k.score) > 999.0 && k.score < 0 then span "mated in #{10000 - Math.abs(k.score)} moves or less"
                else if Math.abs(k.score) > 999.0 && k.score > 0 then span "mate in #{10000 - Math.abs(k.score)} moves or less"
                else if k.forcedDraw then span "forced draw"
                else span k.score
              td style:"width:300px", ->
                div style:"width:300px", ->
                  span class:'move', mv for mv in k.bestMoves
              td style:"width:500px;", ->
                div id:"#{k.attrSafeMove}-plot",style:"width:500px;height:200px;text-align:center;"
                script ->
                  "
                  $(document).ready(function() {
                    setTimeout(function(){
                    $.plot($('##{k.attrSafeMove}-plot'),
                      [[#{k.scoreDepth}]],
                      {
                        series: {
	                  lines: {
	                    show: true
	                  }
	                },
	              yaxis: {
	              },
	              xaxis: {
	              },
	              grid : {
               	      borderWidth: 0
                      }
                    });
                    }, 1000);
                  }); 
                  "
              td style:"width:200px", ->
                div id:"#{k.attrSafeMove}-end-container"
                script ->
                  "
                  $(document).ready(function() {
                    (new PgnViewer({
                      boardName: '#{k.attrSafeMove}-end',
                      pieceSet: 'merida',
                      pieceSize: 24,
                      boardImagePath:'http://www3.skeweredrook.com:8001',
                      dontOutputNavButtons: true,
                      ignoreFlipping: true,
                    })).setupFromFen('#{k.endFen}');
                  });
                  "

    @view layout: ->
      doctype 5
      html ->
        head ->
          title @title
          script src:"/pgnyui.js"
          script src:"/pgnviewer.js"
          script src:"/zappa/jquery.js"
          script src:"/jquery.flot.js"
          link type:"text/css", rel:"stylesheet", href:"/board-min.css"
          style ->
            '''
            span.move { 
              padding: 2px;
              float:left;
            }
            table#moveList {
              width:100%;
              border-collapse: collapse;
              text-align: center;
            }
            table#moveList thead tr td {
              border: 1px solid #444;
            }
            table#moveList tr td {
              border: 1px solid #444;
            }
            body {
              background: #ccc;
            }
            '''
        body @body

