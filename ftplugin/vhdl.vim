""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Abbreviations in insert mode
"iabbr <buffer> --- 80i-<ESC>80|D<CR>--
iabbr <buffer> ,, <=
iabbr <buffer> .. =>
iabbr <buffer> dt downto
iabbr <buffer> toi to_integer
iabbr <buffer> tos to_signed
iabbr <buffer> tou to_unsigned
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Emacs call for
" * beautify
" * update sensitivity list
command! VhdlUpdateSensitivityList :w|:execute "!cp % %.bak; emacs --no-site-file -batch % -f vhdl-update-sensitivity-list-buffer -f save-buffer" | :e
command! VhdlBeautify :w|:silent! execute "!cp % %.bak; emacs --no-site-file -batch % -f vhdl-beautify-buffer -f save-buffer" | :e
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Commands to the functions defined in this package
command! VhdlCopyEntity call VhdlCopyEntityInBuffer()
command! VhdlPasteInstance call VhdlPasteAsInstance()
command! VhdlPasteSignals call VhdlPasteAsSignals()
command! VhdlInsertInstanceFromTag call VhdlInsertInstanceFromTag()
command! VhdlUpdateCtags call VhdlUpdateCtags()


let g:entity_end_regex = '\<end\>'


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Description:
" With the cursor within an entity this function searches for the start line
" and end line of the entity
function! VhdlCopyEntityInBuffer()
  let l:start_line = search('entity\s\+\w*\s\+is', "bnWz")
  let l:end_line = search(g:entity_end_regex, "nWz")
  let l:entity_by_line = getline(start_line, end_line)
  call VhdlCopyEntity(l:entity_by_line)
endfunction


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Description:
" It parses a entity provided as list of lines and extracts
"
" * the entity name
" * the generics
" * the ports
"
" The result is stored in
" * g:vhdl_entity['name']
" * g:vhdl_entity['generics']
" * g:vhdl_entity['ports']
"
function! VhdlCopyEntity(entity_by_line)
  " remove comments
  call map(a:entity_by_line, {_, val -> substitute(val,'\s*--.*$','','g')})

  " create a string containing the entity and normalize whitespaces
  let l:entity = join(a:entity_by_line)
  let l:entity = substitute(entity,'\s\{2,}',' ','g') " replace multiple whitespaces by one whitespace
  let l:entity = substitute(entity,'\s',' ','g') " replace singel whithespace character by actual ' '

  let g:vhdl_entity = {'name': '', 'generics': [], 'ports': []}
  let g:vhdl_entity['name'] = substitute(entity,'.*entity\s\+\(\w*\)\s\+is.*', '\1', 'g')

  if match(entity,  '.*generic\s*(\(.\{-}\))\s*;\s*port.*') != -1
    let l:generic = substitute(entity,  '.*generic\s*(\(.\{-}\))\s*;\s*port.*', '\1', 'g')
    let l:generic = substitute(generic, ':=', ':', 'g')
    let s:generics = split(l:generic, ';')
    let g:vhdl_entity['generics'] = map(s:generics, {_, val -> map(split(val,":"), {_,v -> trim(v)})})
  endif

  if match(entity, '.*port\s*(\(.\{-}\))\s*;\s*') != -1
    echomsg l:entity
    let l:port = substitute(entity, '.*port\s*(\(.\{-}\))\s*;\s*end\>.*', '\1', 'g')
    echomsg l:port
    let l:port = substitute(port, '\s*\(\<in\>\|\<out\>\)\s*', ' \1:', 'g')
    let l:port = substitute(port, ':=', ':', 'g')
    let s:ports = split(l:port, ';')
    let g:vhdl_entity['ports'] = map(s:ports, {_, val -> map(split(val,":"), {_,v -> trim(v)})})
  endif

  echomsg "Copied entity " . g:vhdl_entity['name']
  echomsg "Generics " . join(g:vhdl_entity['generics'])
endfunction


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Requirements:
" VhdlCopyEntity has to have been called which creates g:vhdl_entity
"
" Description:
" It inserts the signals of the parsed entity at the current position of the
" cursor.
function! VhdlPasteAsSignals()
  if exists("g:vhdl_entity")
    let format_string = "%-".printf("%ds", VhdlLenLongestStr(g:vhdl_entity['ports']))
    let l:signals = map(copy(g:vhdl_entity['ports']), {_, val -> "signal " .  printf(format_string, val[0]) . " : " .  val[2] . ";"})
    call append(line('.'),signals)
  endif
endfunction


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Given a list of strings it returns the length of the longest string
function! VhdlLenLongestStr(mylist)
  let l:max_len = 0
  for item in a:mylist
    if len(item[0]) > l:max_len
      let l:max_len = len(item[0])
    endif
  endfor
  return l:max_len
endfunction


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Requirements:
" VhdlCopyEntity has to have been called which creates g:vhdl_entity
"
" Description:
" It inserts a instance of the parsed entity at the current position of the
" cursor.
function! VhdlPasteAsInstance()
  if exists("g:vhdl_entity")
    let instantiation = ["i_" . g:vhdl_entity['name'] . " : entity work." .  g:vhdl_entity['name']]
    let format_string = "%-".printf("%ds", VhdlLenLongestStr(g:vhdl_entity['generics']))
    let generic_map = map(copy(g:vhdl_entity['generics']), {_, val -> "    " .  printf(format_string, val[0]) . " => " . val[0] . "," })
    if len(generic_map) > 0
      let generic_map[-1] = trim(generic_map[-1],',')
      let generic_map = ["  generic map("] + generic_map + [")"]
    endif
    let format_string = "%-".printf("%ds", VhdlLenLongestStr(g:vhdl_entity['ports']))
    let port_map = map(copy(g:vhdl_entity['ports']), {_, val -> "    " . printf(format_string, val[0]) . " => " . val[0] . "," })

    if len(port_map) > 0
      let port_map[-1] = trim(port_map[-1],',')
      let port_map = ["  port map("] + port_map + [");"]
    endif
    let instance = instantiation + generic_map + port_map
    call append(line('.'), instance)
  endif
endfunction


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Requirements:
" This requires ctags-exuberant to be installed
function! VhdlUpdateCtags()
    call jobstart(['ctags-exuberant','-R', '--languages=VHDL', '--fields="+Knl"', '--exclude=work_top'])
endfunction
"autocmd BufEnter,BufWritePost * call VhdlUpdateCtags()


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Description:
" This functioin takes a line that looks like this:
" <entity_name_as_string> <line nr> <filename>
function! VhdlInsertInstanceFromTagSink(line)
  let line_list = split(a:line, " ")
  let file_by_line = readfile(line_list[2])
  let entity_by_line = file_by_line[line_list[1]-1:-1]
  let end_index = match(entity_by_line, g:entity_end_regex)
  call VhdlCopyEntity(entity_by_line[0:end_index])
  call VhdlPasteAsInstance()
endfunction


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Description:
" This function does the following
" 1. fetch tags
" 2. filter for entities
" 3. creates a list of strings from the filtered tag dictionary
" 4. sorts the list
" 5. calls fzf to provide an interface to select the prefered entity
" 6. calls VhdlInsertInstanceFromTagSink wich then copies the selected entity
"    and inserts it as instance.
function! VhdlInsertInstanceFromTag()
  if exists(":FZF")
    let l:input = taglist('.*')
    let l:filtered_input = filter(input, {_, val -> val['kind'] =~ 'entity'})
    let l:stringified = map(filtered_input, {key, val -> val['name'] . ' ' . val['line'] . ' ' . val['filename'] })
    let l:sorted_stringified  = sort(l:stringified)
    call fzf#run({
          \ 'source': l:sorted_stringified,
          \ 'options': '-m -d " " --with-nth 1',
          \ 'down' : '50%',
          \ 'sink': function('VhdlInsertInstanceFromTagSink')})
  endif
endfunction


"function GetFooText()
"  return "Foo Text"
"endfunction
"
"call airline#parts#define_function('foo', 'GetFooText')
"let g:airline_section_y = airline#section#create_right(['foo'])
