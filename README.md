# F5 iRule Json parser

Simple Json library for the F5 iRules language to parse and decode Json.

This library is a rewrite of the Json parser from [mongoose](https://github.com/cesanta/mongoose).

It can fetch Json tokens from any valid Json by [JsonPath expressions](https://github.com/json-path/JsonPath).

## Supported JsonPath operators

Only the dot-notation and a subset of operators are supported.

| Operator | Description |
| -------- | ----------- |
| `$` | The root element to query. This starts all path expressions. |
| `.<name>` | Dot-notated child. |
| `[<number>]` | Array index. |

## Usage

Save the `json.irule` file as an iRule named `json`. Do not attach it to any virtual server. It defines only some procs that can be called by other iRules.

```tcl
# Json to parse
set json "{\"object1\": {\"key\":\"value\",\"array1\":\[{\"v1\":\"mem1\",\"v2\":\"mem2\"},{\"v3\":\"mem3\"}\],\"num1\":1},\"bool2\":true}"

# Set the JsonPath expression
set path "$.object1.key"

# Get the index and length of a token described by path.
# A positive return value represents the found index, a negative value describes an error:
#   -1: Json nesting is too deep
#   -2: Invalid Json
#   -3: Key not found
#   -4: Invalid/Unsupported JsonPath expression
set len -1 ; # This variable is populated with the length of the found token.
set idx [call json::json_get { $json $path len }]

# Get the token described by path.
# - String tokens are enclosed by quotes.
# - Array tokens are enclosed by square braces.
# - Object tokens are enclosed by curly braces.
set token [call json::json_get_tok { $json $path }]

# Get the type of the token.
# This is a simply lookup of the first char of the token.
# Type can be: string, array, object, false, true, null, number or invalid
set type [call json::json_get_type { $token }]

# Decodes a string token
set decoded [call json::json_decode_str { $token }]
```

## Test

Attach the `test.irule` to a Virtual Server with an associated http profile and send a http request to it.

## License

(C) 2024 Juergen Mang <juergen.mang@sec.axians.de>

SPDX-License-Identifier: GPL-2.0-only
