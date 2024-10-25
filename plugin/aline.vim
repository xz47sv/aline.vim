if get(g:, 'loaded_aline')
    finish
endif

if exists('g:aline_config') || get(g:, 'aline_autoload')
    call aline#setup()
endif
