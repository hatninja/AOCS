# AOS3
This is a Attorney Online 2 server written in pure lua, making use of .

AOS3 is an experimental iteration in a series of AO2 lua servers. Check out [AOLS2](https://github.com/hatninja/AOLS2) for a more standard and freely configurable server.  

It focus on minimal set-up and a bare-bone experience.

## Set-up
Note that this project is in an early state, and is not ready to be used outside of development.

__Requirements:__
- [Lua version 5.1 or above](https://www.lua.org/about.html)
 - `lua`
- [luasocket](https://aiq0.github.io/luasocket/index.html)
 - `luarocks install luasocket`

The requirements listed above are commonly found as packages in many package managers. Windows users may find it easier to use this [prebuilt luasocket release](http://files.luaforge.net/releases/luasocket/luasocket/luasocket-2.0.2).

__Running:__
1. Clone the source to any location.
2. Run using the shell script `run.sh`, or alternatively with lua directly via `run.lua`

## License

This project is under the MIT License. See [LICENSE.md](./LICENSE.md) for detail.  

The following libraries are included:  

[sha1.lua](https://github.com/kikito/sha1.lua)  
Copyright (c) 2013 Enrique García Cota + Eike Decker + Jeffrey Friedl  

[bitop-lua](https://github.com/AlberTajuelo/bitop-lua)  
Copyright (c) 2008-2011 David Manura.  
