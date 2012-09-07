_       = require "underscore"
dbutil  = require "../../util/dbutil"

module.exports =

  # dbCallback( Trade.findAll() ).respond( res )

  respond: ( res ) ->
    ( error, data ) ->
      if error
        res.send 500, error
      else if data
        res.json data
      else
        res.send 404
  
  dbCallback: ( query ) ->
    if arguments.length >= 2
      callback = _.last arguments
      
    eager = arguments.length > 2 and arguments[ 1 ]
  
    if callback
      if eager
        query
          .done ( err, data ) ->
            if err
              callback err
            else if data
              dbutil.eager( data )
                .then ( data ) ->
                  callback null, data
            else
              callback()
      else
        query.done callback
      
    respond: ( res ) ->
      callback = respond( res )
      dbCallback query, eager, callback
