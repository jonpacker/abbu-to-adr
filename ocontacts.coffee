plist = require "./vendor/node-plist/lib/plist"
spawn = require('child_process').spawn

file = "#{__dirname}/test/files/jpab.abbu/Metadata/068FA783-780F-4BAE-8A82-EC2D300CED14:ABPerson.abcdp"

xmlData = ''
plutil = spawn 'plutil', ['-convert', 'xml1', '-o', '-', file]

plutil.stdout.on 'data', (data) ->
  xmlData += data

plutil.on 'exit', ->
  plist.parseString xmlData, (err, obj) ->
    throw err if err
    console.log obj