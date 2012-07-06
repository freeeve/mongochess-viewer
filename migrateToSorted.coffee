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
db.open (err, p_db) ->
  sortScores = (pos) ->
    sorted = []
    links = []
    for own k,v of pos.moves
      d = {move:k}
      d['attrSafeMove']=k.replace("+","check").replace("=","prom")
      for own k2,v2 of v
        d[k2] = v2
      depth = 1
      scoreDepth = []
      for s in d.scores
        scoreDepth.push "["+(depth++)+","+s+"]"
      d['scoreDepth'] = scoreDepth
      sorted.push d
      links.push d.link
    sorted.sort (a,b) -> if a.score < b.score then 1 else -1
    delete pos.old
    pos.moves = sorted
    console.log(pos)
    return pos
 
  p_db.collection 'positions', (err,collection) ->
    collection.findOne {old:true}, (err,pos) ->
      collection.save sortScores(pos), {safe:true}, (err, doc) ->
        console.log(err)
        p_db.close()
