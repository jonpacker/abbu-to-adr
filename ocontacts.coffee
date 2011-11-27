parsePlist = require('plist').parseString
spawn = require('child_process').spawn
argv = require('optimist').argv
path = require 'path'
fs = require 'fs'

contactsDir = path.join argv.i or argv._[0], 'Metadata'
output = argv.o or argv._[1]

# Check if a file should be excluded
excluded = (fileName) ->
  return not fileName.match /:ABPerson\.abcdp/

    

fs.readdir contactsDir, (err, files) ->
  throw 'Malformed .abbu bundle (couldn\'t find Metadata directory)' if err
  
  parseFiles files, (err, contacts) ->
    console.log contacts
      
# Parse files
parseFiles = (files, callback) ->
  currentIndex = -1
  contacts = []

  do parse = -> 
    return callback null, contacts if ++currentIndex >= files.length
    
    file = files[currentIndex]
    return do parse if excluded file

    filePath = path.join contactsDir, file
    parseFile filePath, (err, contact) ->
      callback err, null if err
      contacts.push contact
      do parse

# Parse file
parseFile = (file, callback) ->
  xml = ''
  plutil = spawn 'plutil', ['-convert', 'xml1', '-o', '-', file]
  plutil.stdout.on 'data', (data) -> xml += data
  plutil.on 'exit', ->
    parsePlist xml, (err, plist) ->
      callback err, null if err
      callback null, readAbcdp plist[0]

# Convert a .abcdp contact (in plist format) to a generic contact format
readAbcdp = (abcdp) ->
  emails = abcdp.Email?.values 
  [company, firstName, lastName] = [abcdp.Organization, abcdp.First, abcdp.Last]
  emails: emails, company: company, firstName: firstName, lastName: lastName

