This is a chat server written in pure lua with the help of [luasocket](https://aiq0.github.io/luasocket/index.html). It is intended for use with [AO2](https://github.com/AttorneyOnline), and supports basic roleplay features.

AOCS aims to create a simplified server experience, with a focus on few but high-quality features. For a more fully-featured server, check out the previous [AOLS2](https://github.com/hatninja/AOLS2).

## Setting Up
Note that this project is still in an early state, and is not ready to be used outside of development.

#### Requirements:
You can find `lua` and `luarocks` through your distribution's package manager. Install luasocket using `luarocks install luasocket`.

#### Running:
1. Clone this repository.
2. Duplicate `default_config/` and name the new folder as "config"
3. Run by executing `run.sh`
 * Alternatively, run with lua directly on `init.lua` (Make sure the current directory is the containing folder.)

### License
This project and its included libraries are under the [MIT License](./LICENSE.md).  

[sha1.lua](https://github.com/kikito/sha1.lua)  
Copyright (c) 2013 Enrique García Cota + Eike Decker + Jeffrey Friedl  

[bitop-lua](https://github.com/AlberTajuelo/bitop-lua)  
Copyright (c) 2008-2011 David Manura.
