# F5 iRule Json parser

Simple Json library for the F5 iRules language to parse and decode Json.

This library is inspired by the Json parser from mongoose:
https://github.com/cesanta/mongoose

## Usage

Save the `json.irule` file as an iRule named `json`.

```tcl
# Json to parse
set json "{\"object1\": {\"key\":\"value\",\"array1\":\[{\"v1\":\"mem1\",\"v2\":\"mem2\"},{\"v3\":\"mem3\"}\],\"num1\":1},\"bool2\":true}"

# Set the JsonPath expression
set path "$.object1.key"

# Get the index and length of a token described by path
set len -1
set idx [call json::json_get { $json $path len }]

# Get the token described by path
set token [call json::json_get_tok { $json $path }]

# Get the type of the token
set type [call json::json_get_type { $token }]

# Decodes string token
set decoded [call json::json_decode_str { $token }]
```

## Test

Attach the `test.irule` to a Virtual Server with an associated http profile and send a http request to it.

## License

(C) 2024 Juergen Mang <juergen.mang@sec.axians.de>

SPDX-License-Identifier: GPL-2.0-only
