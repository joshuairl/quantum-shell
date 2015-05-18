fs = require 'fs'
path = require 'path'
{exec} = require 'child_process'

module.exports =
    list:
        '''
        \\. : break cd continue eval exec exit export getopts hash
        pwd readonly return shift test times trap umask unset
        '''.split /\s+/

    '~pwd': (tokens) ->
        if tokens[0] is 'pwd'
            @dataStream.write @pwd
        else
            @errorStream.write "quantum-shell: pwd: internal error - expected '#{tokens[0]}' to be 'pwd'"

    '~export': (tokens) ->
        if tokens[0] is 'export'
            if tokens.length != 4
                @errorStream.write "quantum-shell: export: invalid input"
            else
                if tokens[2] is '='
                    @env[tokens[1]] = tokens[3]
                else
                    @errorStream.write "quantum-shell: export: missing '=' after environment variable name"
        else
            @errorStream.write "quantum-shell: export: internal error - expected '#{tokens[0]} to be 'export'"

    '~cd': (tokens) ->
        if tokens[0] is 'cd'
            if tokens.length is 1
                @lwd = @pwd
                @pwd = atom.config.get('quantum-shell.home')
                @input.placeholder = @promptString(atom.config.get('quantum-shell.PS'))
                fs.readdir @pwd, (error, files) =>
                    if error then return console.log "QUANTUM SHELL CD ERROR: #{error}"
                    @fileNames = {}
                    for file in files
                        @fileNames[file] = true
            else if tokens[1] is '-'
                [@pwd, @lwd] = [@lwd, @pwd]
                @input.placeholder = @promptString(atom.config.get('quantum-shell.PS'))
                fs.readdir @pwd, (error, files) =>
                    if error then return console.log "QUANTUM SHELL CD ERROR: #{error}"
                    @fileNames = {}
                    for file in files
                        @fileNames[file] = true
            else
                dir = path.resolve @pwd, tokens[1].replace '~', atom.config.get('quantum-shell.home')
                fs.stat dir, (error, stats) =>
                    if error
                        if error.code is 'ENOENT'
                            @errorStream.write "quantum-shell: cd: no such file or directory"
                        else
                            console.log "QUANTUM SHELL CD ERROR: #{error}"
                    else
                        if stats.isDirectory()
                            try
                                ls = exec "ls", cwd: dir, env: @env
                                [@lwd, @pwd] = [@pwd, dir]
                                @input.placeholder = @promptString(atom.config.get('quantum-shell.PS'))
                                fs.readdir @pwd, (error, files) =>
                                    if error then return console.log "QUANTUM SHELL CD ERROR: #{error}"
                                    @fileNames = {}
                                    for file in files
                                        @fileNames[file] = true
                            catch error
                                if error.errno is 'EACCES'
                                    @errorStream.write "quantum-shell: cd: #{tokens[1]} permission denied"
                                else
                                    console.log "QUANTUM SHELL CD ERROR: #{error}"
                        else
                            @errorStream.write "quantum-shell: cd: #{tokens[1]} is not a directory"
        else
            @errorStream.write "quantum-shell: cd: internal error - expected '#{tokens[0]}' to be 'cd'"
