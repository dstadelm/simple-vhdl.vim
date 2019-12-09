""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" myquesta is a script that searches for the nearest vunit run.py to the
" file given as argument. Then vunit is executed with questa.
setlocal makeprg=myquesta\ %
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" The errorformat of modelsim/questa
setlocal errorformat=**\ Error:\ %f(%l):\ %m,**\ Warning:\ %f(%l):\ %m
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Abbreviations in insert mode
iabbr ,, <=
iabbr .. =>
iabbr dt downto
iabbr toi to_integer
iabbr tos to_signed
iabbr tou to_unsigned
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Emacs call for
" * beautify
" * update sensitivity list
command! VhdlUpdateSensitivityList :w|:execute "!cp % %.bak; emacs --no-site-file -batch % -f vhdl-update-sensitivity-list-buffer -f save-buffer" | :e
command! VhdlBeautify :w|:execute "!cp % %.bak; emacs --no-site-file -batch % -f vhdl-beautify-buffer -f save-buffer" | :e
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Commands to the functions defined in this package
command! VhdlCopyEntity call VhdlCopyEntityInBuffer()
command! VhdlPasteInstance call VhdlPasteAsInstance()
command! VhdlPasteSignals call VhdlPasteAsSignals()
command! VhdlInsertInstanceFromTag call VhdlInsertInstanceFromTag()
command! VhdlRunTestWithFzf call VhdlRunTestWithFzf(0)
command! VhdlRunTestWithFzfInGui call VhdlRunTestWithFzf(1)
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Key mappings
nnoremap <leader>i :VhdlInsertInstanceFromTag<CR>
nnoremap <leader>t :VhdlRunTestWithFzf<CR>
nnoremap <leader>gt :VhdlRunTestWithFzfInGui<CR>
map <F12> :VhdlUpdateSensitivityList<CR>
map <F11> :VhdlBeautify<CR>

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
    let l:port = substitute(entity, '.*port\s*(\(.\{-}\))\s*;\s*end\(\s\+entity\s*\)\?;', '\1', 'g')
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
      let generic_map = ["  generic map("] + generic_map + [");"]
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
    call jobstart(['ctags-exuberant','-R', '--languages=VHDL', '--fields="+Kn"', '--VHDL-kinds="+lfp"'])
endfunction
autocmd BufEnter,BufWritePost * call VhdlUpdateCtags()


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

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Neomake configurations only works if neomake is installed and setup
if exists(":Neomake")
  autocmd! BufWritePost,BufEnter * NeomakeProject
  call neomake#configure#automake('nrwi', 10)
  let g:neomake_vhdl_myquesta_maker = {
        \ 'exe': 'myquesta',
        \ 'args': ['%'],
        \ 'errorformat' : '**\ Error:\ %f(%l):\ %m,' . '**\ Warning:\ %f(%l):\ %m',
        \ }
  let g:neomake_vhdl_myghdl_maker = {
        \ 'exe': 'myghdl',
        \ 'args' : ['%'],
        \ 'errorformat' : '%f:%l:%c:\ %m',
        \ }
  let g:neomake_waring_sign = {
        \ 'text': 'W',
        \ 'texthl': 'WarningMsg',
        \ }
  let g:neomake_error_sign = {
        \ 'text': 'E',
        \ 'texthl' : 'ErrorMsg',
        \ }
  let g:neomake_vhdl_enabled_makers = ['myquesta', 'myghdl']
endif

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" One posiblity to run tests through vunit
" This currently is project specific maybe with more projects along the way
" this will change
function VhdlFindRootRunPy()
  if exists("*FindRootDirectory")
    let l:root = FindRootDirectory()
    let l:runpy_and_workdir = { "runpy": expand(findfile("run.py", l:root . "**")), "workdir": l:root}
    return l:runpy_and_workdir
  endif 
endfunction

let g:vunit_test_list=[]
function! s:VhdlGetTestList(job_id, data, event) dict
  if a:event == 'stdout'
    if a:data != ['']
      let g:vunit_test_list += a:data
    endif
  elseif a:event == 'stderr'
    if a:data != ['']
      echomsg "stderr " . join(a:data, "\r\r")
    endif
  else
    call sort(g:vunit_test_list)
    call uniq(g:vunit_test_list)
  endif
endfunction

function VhdlUpdateTestList()
  let l:runpy = VhdlFindRootRunPy()
  let s:opts = {
        \ 'on_stdout': function('s:VhdlGetTestList'),
        \ 'on_stderr': function('s:VhdlGetTestList'),
        \ 'on_exit'  : function('s:VhdlGetTestList'),
        \ 'cwd'      : l:runpy["workdir"]
        \}
  call jobstart(['vunit',  l:runpy["runpy"], '-l'], s:opts)
endfunction
autocmd BufEnter,BufWritePost * call VhdlUpdateTestList()

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Parameter guimode can be 0 for non gui mode or 1 for calling questa with 
" gui
function VhdlRunTestWithFzf(guimode)
  let l:list = []
  let g:vunit_gui_mode = a:guimode 
  if exists("g:vunit_test_list") 
    let l:list = g:vunit_test_list
  else
    return
  endif
  if exists(":FZF")
    call fzf#run({
          \ 'source': l:list,
          \ 'options': '-m -d " " --with-nth 1',
          \ 'down' : '50%',
          \ 'sink*': function('VhdlRunVunitTest')})
  endif
endfunction

function VhdlRunVunitTest(tests)
  let l:runpy = VhdlFindRootRunPy()
  let l:command = "export $(tmux show-env | grep DISP); vunit " . l:runpy["runpy"] . " " . join(a:tests, " ") . " -o nvim"
  if g:vunit_gui_mode == 1
    let l:command = l:command . " -g"
  endif
  " reset g:vunit_gui_mode for next call
  let g:vunit_gui_mode = 0
  bo new | resize 15 
  call termopen(l:command, {'cwd': l:runpy["workdir"]})
  call cursor(100,0)
  wincmd p
endfunction
