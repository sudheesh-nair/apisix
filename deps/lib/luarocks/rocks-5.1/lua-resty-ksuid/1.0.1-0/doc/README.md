# lua-resty-ksuid

lua-resty-ksuid is a Lua implementation of **KSUID (K-Sortable Unique Identifier)**, a globally unique identifier that is **time-sortable** and **highly collision-resistant**. This module leverages **OpenResty's OpenSSL bindings** to generate **cryptographically secure random bytes** for uniqueness.

## Features
- Generates **20-byte KSUIDs** encoded in **Base62**
- Uses **OpenSSL** for **secure random number generation**
- KSUIDs are **sortable by creation time**
- Supports **Lua 5.1+** and OpenResty environments

## Installation
Install via **LuaRocks**:
```sh
luarocks install lua-resty-ksuid
```

Or manually clone the repository and include `ksuid.lua` in your project.

## Usage
```lua
local ksuid = require("ksuid")

-- Generate a new KSUID
local id = ksuid.generate()
print(id) -- Example output: 2sPQPCQ9YM5Kfg1ygeKHux397hh
```

## Dependencies
- **lua-resty-openssl** (for cryptographic randomness)
- **luabitop** (for bitwise operations)

## Why KSUID?
KSUIDs are designed to be **sortable by time** while still being **highly unique**. Unlike UUIDs, which are randomly distributed, KSUIDs allow efficient **ordering and indexing** in databases.

## License
This project is licensed under the **MIT License**. See the `LICENSE` file for details.

## Author
Developed by Túlio Santiago Duarte.

## Contributing
Pull requests are welcome! If you encounter any issues, feel free to open an issue in the repository.

## References
- [Segment's KSUID](https://github.com/segmentio/ksuid)
- [LuaRocks](https://luarocks.org)