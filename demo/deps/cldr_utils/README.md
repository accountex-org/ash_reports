# Cldr Utils

![Build status](https://github.com/elixir-cldr/cldr_utils/actions/workflows/ci.yml/badge.svg)
[![Hex.pm](https://img.shields.io/hexpm/v/cldr_utils.svg)](https://hex.pm/packages/cldr_utils)
[![Hex.pm](https://img.shields.io/hexpm/dw/cldr_utils.svg?)](https://hex.pm/packages/cldr_utils)
[![Hex.pm](https://img.shields.io/hexpm/dt/cldr_utils.svg?)](https://hex.pm/packages/cldr_utils)
[![Hex.pm](https://img.shields.io/hexpm/l/cldr_utils.svg)](https://hex.pm/packages/ex_cldr)

Utility functions extracted from [Cldr](https://github.com/elixir-cldr/cldr).

* Map functions for deep mapping, deep merging, transforming keys
* Math functions including `mod/2` that works on floored division
* Number functions for working with the number of digits, the fraction as an integer, ...
* String function for underscoring (converting CamelCase to snake case)
* Cldr.Json.decode!/1 to wrap OTP 27's `:json` module
* Various macros

## Installation

The package can be installed by adding `:cldr_utils` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:cldr_utils, "~> 2.0"}
  ]
end
```

## Copyright and License

Copyright (c) 2017-2024 Kip Cole

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at [http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
