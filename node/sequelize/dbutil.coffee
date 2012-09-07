Sequelize = require "sequelize"
sqlite3   = require "sqlite3"
path      = require "path"
fs        = require "fs"
q         = require "q"
qfs       = require "q-fs"
async     = require "async"
_         = require "underscore"

sequelize = null

jsonify = ( items ) ->
  return null if items is null
  isArray = _.isArray( items )
  items = [ items ] if !isArray
  item = items[ 0 ]
  return items if !item
  attributes = item.attributes
  
  jsonified = []
  for item in items
    jsonified.push( _.pick( item, attributes ) )
  
  return if isArray then jsonified else jsonified[ 0 ]

#
# Eagerly load associations from Sequelize models.
# 
# eager = require( 'eager' )
# Account.findAll()
#   .then( function( accounts ) {
#     // Load user assoc and nested user.address assoc
#     eager( accounts, { user: { address: true } } )
#       .then( function( accounts ) {
#         // Use my eagerly-loaded accounts
#       });
#   })
#
# @param items The result of the original [flat] query.
# @param include Which associations you want to include. If left blank, includes all.
#
eager = ( result, include ) ->
  resultIsArray = _.isArray result
  items = if resultIsArray then result else [ result ]
  jsonItems = jsonify items
  
  d = q.defer()
  
  if !jsonItems or jsonItems.length is 0
    d.resolve jsonItems
    return d.promise
  
  associations = items[ 0 ].__factory.associations
  
  async.forEachSeries( _.keys( associations ), ( key, callback ) ->
    association = associations[ key ]
    target = association.target
    identifier = association.identifier
    name = target.name
    
    if include?
      if include.hasOwnProperty( name )
        inc = include[ name ]
      else
        return callback()
    
    ids = _.without( _.uniq( _.pluck( items, identifier ) ), null )
    
    if ids and ids.length
      target.findAll( where: id: ids )
        .success ( assocItems ) ->
          eager( assocItems, inc ).then ( assocItems ) ->
            if assocItems
              table = {}
              
              for assocItem in assocItems
                table[ assocItem.id ] = assocItem
              
              for jsonItem in jsonItems
                assocId = jsonItem[ identifier ]
                jsonItem[ name ] = table[ assocId ]
            
            callback()
    else
      callback()
  , -> d.resolve( if resultIsArray then jsonItems else jsonItems[ 0 ] ) )
  
  return d.promise
  
getDatabase = ( dbFile, config = {} ) ->
  dbFile = path.resolve dbFile
  d = q.defer()
  
  resolve = ->
    sequelize = getDatabaseSync dbFile, config
    d.resolve sequelize
  
  if !path.existsSync dbFile
    #console.log "DB doesn't exist (#{ dbFile }), creating..."
    async.series [
      ( callback ) ->
        dbDir = _.initial( dbFile.split( "/" ) ).join( "/" )
        qfs.makeTree( dbDir )
          .then callback
      ( callback ) ->
        db = new sqlite3.Database dbFile, sqlite3.OPEN_READWRITE | sqlite3.OPEN_CREATE, ( err ) ->
          if err
            console.log "Failed to create DB #{ dbFile }", err
          db.close()
          resolve()
    ]
  else
    resolve()
  
  d.promise
  
getDatabaseSync = ( dbFile, config = {} ) ->
  return sequelize if sequelize
  sequelize = new Sequelize config.name, config.username, config.password,
    dialect: "sqlite"
    storage: dbFile
    logging: false

dropDatabase = ( dbFile ) ->
  sequelize = null
  d = q.defer()
  fs.unlink dbFile, -> d.resolve()
  #console.log "DB dropped at #{ dbFile }"
  d.promise

module.exports =
  jsonify: jsonify
  eager: eager
  getDatabase: getDatabase
  getDatabaseSync: getDatabaseSync
  dropDatabase: dropDatabase