parsePlist = require('plist').parseString
spawn = require('child_process').spawn
argv = require('optimist').argv
sqlite3 = require 'sqlite3'
path = require 'path'
fs = require 'fs'

mrTableName = "ZABCDMAILRECENT"
migrationr = /^Migration.*\.abbu\.tbz$/

abbu = path.normalize argv.i or argv._[0]
contactsDir = path.join abbu, 'Metadata'
mailrecents = path.join abbu, 'MailRecents-v4.abcdmr'
output = argv.o or argv._[1]


# Parse Mail Recents
getMailRecents = (file, callback) ->
  db = new sqlite3.Database file, (err) ->
    return callback err if err

    people = []
    readRow = (err, row) ->
      return if err or row['ZPERSONUNIQUEID']
      people.push readAbcdmr row

    sql = "SELECT * FROM #{mrTableName}"
    db.each sql, readRow, -> 
      callback null, people

# Check if a file should be excluded
excluded = (fileName) ->
  return not fileName.match /:ABPerson\.abcdp/

getSavedContacts = (dir, callback, hasUntarred) -> 
  fs.readdir dir, (err, files) ->
    throw 'Malformed .abbu bundle (couldn\'t find Metadata directory)' if err
  
    parsedir = ->
      parseFiles files, (err, contacts) ->
        callback err, contacts 
    
    return do parsedir if files.length > 3 or hasUntarred

    # Otherwise we need to untar the archive.
    untarMetadata (err) ->
      throw err if err
      getSavedContacts dir, callback, true
    
untarMetadata = (callback) ->
  calledback = no
  untar = (file) ->
    calledback = yes
    file = path.join abbu, file
    tar = spawn 'tar', ['-C', abbu, '-xf', file]
    tar.on 'exit', ->
      callback null

  # Need to find the file first
  fs.readdir abbu, (err, files) ->
    throw err if err
    untar file for file in files when file.match migrationr
    callback "Couldn't find migration" if not calledback
      
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
      console.log plist[0].First, file
      callback null, readAbcdp plist[0]

# Convert a .abcdp contact (in plist format) to a generic contact format
readAbcdp = (abcdp) ->
  c = {}
  c.emails = abcdp.Email.values if abcdp.Email
  c.phones = abcdp.Phone.values if abcdp.Phone
  c.company = abcdp.Organization if abcdp.Organization
  c.firstName = abcdp.First if abcdp.First
  c.lastName = abcdp.Last if abcdp.Last
  return c

# Convert an abcdmr row to a generic contact format
readAbcdmr = (abcdmr) ->
  c = {}
  c.emails = [ abcdmr['ZEMAIL'] ]
  c.firstName = abcdmr['ZFIRSTNAME'] if abcdmr['ZFIRSTNAME']
  c.lastName = abcdmr['ZLASTNAME'] if abcdmr['ZLASTNAME']
  return c

# Create an 'Opera Hotlist' formatted string out of the supplied contacts
makeHotlist = (contacts, startingId = 321) ->
  hl = "Opera Hotlist version 2.0\nOptions: encoding = utf8, version=3\n\n"

  writeContact = (contact) ->
    hl += """
          #CONTACT
            ID=#{startingId++}
            NAME=#{contact.firstName or contact.emails?[0] or ""} #{contact.lastName or ""}
            URL=
            CREATED=
            DESCRIPTION=
            EMAIL=#{ contact.emails?.join(" ") or "" }
            PHONE=#{ contact.phones?.join(" ") or "" }
            FAX=
            POSTALADDRESS=
            PICTUREURL=
            ICON=Contact0
          

          """

  writeContact contact for contact in contacts
  return hl

getSavedContacts contactsDir, (err, contacts) ->
  getMailRecents mailrecents, (err, mrecents) ->
    throw err if err
    contacts = contacts.concat mrecents
    console.log makeHotlist contacts

