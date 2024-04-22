###############################################################################
# Simple Json library for the F5 iRules language to parse and decode Json.
#
# This library is inspired by the Json parser from mongoose:
# https://github.com/cesanta/mongoose
#
# SPDX-License-Identifier: GPL-2.0-only
# (C) 2024 Juergen Mang <juergen.mang@sec.axians.de>
###############################################################################

###############################################################################
# Gets the index and token length for an json key defined by an JsonPath expression in dot notation.
# The token type can be easily determined by looking at the first character.
#
# @param {string} buffer Json string to parse
# @param {string} path JsonPath expression
# @param {integer} toklen_ref Variable reference to set the length of returned token
# @returns {integer} Index of found token in buffer on success, else
#                    -1: Json nesting is too deep
#                    -2: Invalid Json
#                    -3: Key not found
#                    -4: Invalid/Unsupported JsonPath expression
proc json_get { buffer path toklen_ref } {
    set JSON_TOO_DEEP -1
    set JSON_INVALID -2
    set JSON_NOT_FOUND -3
    set JSON_PATH_INVALID -4
    set JSON_MAX_DEPTH 10
    set JSON_WHITESPACES [list " " "\t" "\n" "\r"]
    set JSON_ESCAPES [list "b" "f" "n" "r" "t" "\\" "\""]

    upvar $toklen_ref toklen  ; # Saves the length of the found token
    set expecting "JSON_EXPECT_VALUE"
    set buffer_len [string length $buffer]
    set buffer_pos_max [expr {$buffer_len - 1}]
    set path_len [string length $path]
    set path_pos_max [expr {$path_len - 1}]
    set nesting ""            ; # Holds the nesting chars
    set i 0                   ; # Current offset in buffer
    set j 0                   ; # Offset in `s` we're looking for (return value)
    set depth 0               ; # Current depth (nesting level)
    set ed 0                  ; # Expected depth
    set pos 1                 ; # Current position in `path`
    set ci -1                 ; # Current index in array
    set ei -1                 ; # Expected index in array

    set toklen 0
    if { [string index $path 0] ne "$" } {
        return $JSON_INVALID
    }

    for { set i 0 } { $i < $buffer_len } { incr i } {
        set c [string index $buffer $i]  ; # Current char in buffer
        set p [string index $path $pos]  ; # Current char in path
        if { [lsearch -exact $JSON_WHITESPACES $c] > -1 } {
            continue
        }
        switch -exact -- $expecting {
            "JSON_EXPECT_VALUE" {
                #puts "\tV path:$path, pos:$pos, depth:$depth, ed:$ed, ci:$ci, ei:$ei"
                if { $depth == $ed } {
                    set j $i
                }
                if { $c eq "\{" } {
                    if { $depth > $JSON_MAX_DEPTH } {
                        return $JSON_TOO_DEEP
                    }
                    if { ($depth == $ed) && ($p eq ".") && ($ci == $ei) } {
                        incr ed
                        incr pos
                        set ci -1
                        set ei -1
                    }
                    lappend nesting $c
                    incr depth
                    set expecting "JSON_EXPECT_KEY"
                    continue
                } elseif { $c eq "\[" } {
                    if { $depth > $JSON_MAX_DEPTH } {
                        return $JSON_TOO_DEEP
                    }
                    if { ($depth == $ed) && ($p eq "\[") && ($ei == $ci) } {
                        incr ed
                        incr pos
                        set ci 0
                        # Convert string to number
                        for { set ei 0 } { ([set p [string index $path $pos]] ne "\]") && ($pos < $path_pos_max) } { incr pos } {
                            if { [string is double $p] } {
                                set ei [expr { $ei * 10 + $p }]
                            } else {
                                return $JSON_PATH_INVALID
                            }
                        }
                        if { $pos < $path_pos_max } {
                            incr pos
                        }
                    }
                    lappend nesting $c
                    incr depth
                    continue
                } elseif { ($c eq "\]") && ($depth > 0) } {
                    # Empty array
                    if { ($depth == $ed) && ($ci != $ei) } {
                        return $JSON_NOT_FOUND
                    }
                    if { [lindex $nesting [expr {$depth - 1}]] ne "\[" } {
                        return $JSON_INVALID
                    }
                    set depth [expr {$depth - 1}]
                    if { ($depth == $ed) && ($pos >= $path_pos_max) && ($ci == $ei) } {
                        set toklen [expr {$i - $j + 1}]
                        return $j
                    }
                } elseif { ($c eq "t") && ([string range $buffer $i [expr {$i + 3}]] eq "true") } {
                    set i [expr {$i + 3}]
                } elseif { ($c eq "n") && ([string range $buffer $i [expr {$i + 3}]] eq "null") } {
                    set i [expr {$i + 3}]
                } elseif { ($c eq "f") && ([string range $buffer $i [expr {$i + 4}]] eq "false") } {
                   set i [expr {$i + 4}]
                } elseif { ($c eq "-") || ([string is double $c]) } {
                    while { ($c eq "-") || ($c eq ".") || ([string is double $c]) } {
                        incr i
                        set c [string index $buffer $i]
                    }
                    set i [expr {$i - 1}]
                } elseif { $c eq "\"" } {
                    incr i
                    while { $i < $buffer_len } {
                        set c [string index $buffer $i]
                        if { $c eq "\\" } {
                            # Json escape
                            set nc [string index $buffer [expr {$i + 1}]]
                            if { [lsearch -exact $JSON_ESCAPES $nc] == -1 } {
                                return $JSON_INVALID
                            }
                            incr i
                        } elseif { $c eq "\"" } {
                            break
                        }
                        incr i
                    }
                    if { $i == $buffer_pos_max } {
                        return $JSON_INVALID
                    }
                } else {
                    return $JSON_INVALID
                }
                if { ($depth == $ed) && ($pos >= $path_pos_max) && ($ci == $ei) } {
                    set toklen [expr {$i - $j + 1}]
                    return $j
                }
                if { ($depth == $ed) && ($ei >= 0) } {
                    incr ci
                }
                set expecting "JSON_EXPECT_COMMA_OR_EOO"
            }
            "JSON_EXPECT_KEY" {
                if { $c eq "\"" } {
                    set s [expr {$i + 1}]
                    set n 0
                    while { $s < $buffer_len } {
                        set c [string index $buffer $s]
                        if { $c eq "\\" } {
                            # Json escape
                            set nc [string index $buffer [expr {$s + 1}]]
                            if { [lsearch -exact $JSON_ESCAPES $nc] == -1 } {
                                return $JSON_INVALID
                            }
                            incr s
                            incr n
                        } elseif { $c eq "\"" } {
                            break
                        }
                        incr s
                        incr n
                    }
                    if { $s == $buffer_pos_max } {
                        return $JSON_INVALID
                    }
                    unset -- s
                    if { [expr {$i + $n}] == $buffer_pos_max } {
                        return $JSON_NOT_FOUND
                    }
                    if { $depth < $ed } {
                        return $JSON_NOT_FOUND
                    }
                    if { ($depth == $ed) && ([string index $path [expr {$pos - 1}]] ne ".") } {
                        return $JSON_NOT_FOUND
                    }
                    #puts "\tK path:$path, pos:$pos, depth:$depth, n:$n, ed:$ed, ci:$ci, ei:$ei"
                    if { ($depth == $ed) && ([string index $path [expr {$pos - 1}]] eq ".") &&
                         ([string range $buffer [expr {$i + 1}] [expr {$i + $n}]] eq [string range $path $pos [expr {$pos + $n - 1}]]) &&
                         (
                            ([expr {$pos + $n}] == $path_len) ||
                            ([string index $path [expr {$pos + $n}]] eq ".") ||
                            ([string index $path [expr {$pos + $n}]] eq "\[")
                         )
                    } {
                        set pos [expr {$pos + $n}]
                    }
                    set i [expr {$i + $n + 1}]
                    set expecting "JSON_EXPECT_COLON"
                } elseif { $c eq "\}" } {
                    # Empty object
                    if { ($depth == $ed) && ($ci != $ei) } {
                        return $JSON_NOT_FOUND
                    }
                    if { [lindex $nesting [expr {$depth - 1}]] ne "\{" } {
                        return $JSON_INVALID
                    }
                    set depth [expr {$depth - 1}]
                    if { ($depth == $ed) && ($pos >= $path_pos_max) && ($ci == $ei) } {
                        set toklen [expr {$i - $j + 1}]
                        return $j
                    }
                    set expecting $S_COMMA_OR_EDO
                    if { ($depth == $ed) && ($ei >= 0) } {
                        incr ci
                    }
                } else {
                    return $JSON_INVALID
                }
            }
            "JSON_EXPECT_COLON" {
                if { $c eq ":" } {
                    set expecting "JSON_EXPECT_VALUE"
                } else {
                    return $JSON_INVALID
                }
            }
            "JSON_EXPECT_COMMA_OR_EOO" {
                if { $depth <= 0 } {
                    return $JSON_INVALID
                } elseif { $c eq "," } {
                    if { [lindex $nesting [expr {$depth - 1}]] eq "\{" } {
                        set expecting "JSON_EXPECT_KEY"
                    } else {
                        set expecting "JSON_EXPECT_VALUE"
                    }
                } elseif { ($c eq "\]") || ($c eq "\}") } {
                    if { ($depth == $ed) && ($c eq "\}") && ([string index $path [expr {$pos - 1}]] eq ".") } {
                        return $JSON_NOT_FOUND
                    }
                    if { ($depth == $ed) && ($c eq "\]") && ([string index $path [expr {$pos - 1}]] eq ",") } {
                        return $JSON_NOT_FOUND
                    }
                    if { ($depth == $ed) && ($ci != $ei) } {
                        return $JSON_NOT_FOUND
                    }
                    if { ($c eq "\]") && ([lindex $nesting [expr {$depth - 1}]] ne "\[") } {
                        return $JSON_INVALID
                    }
                    if { ($c eq "\}") && ([lindex $nesting [expr {$depth - 1}]] ne "\{") } {
                        return $JSON_INVALID
                    }
                    set depth [expr {$depth - 1}]
                    if { ($depth == $ed) && ($pos >= $path_pos_max) && ($ci == $ei) } {
                        set toklen [expr {$i - $j + 1}]
                        return $j
                    }
                    if { ($depth == $ed) && ($ei >= 0) } {
                        incr ci
                    }
                } else {
                    return $JSON_INVALID
                }
            }
        }
    }
    return $JSON_NOT_FOUND
}

###############################################################################
# Gets the token from the json string defined by path.
#
# @param {string} json Json string to extract the token
# @param {number} path JsonPath expression
# @returns {string} The extracted value or empty string on error
proc json_get_tok { json path } {
    set len -1 ; # Length of returned token
    set idx [json_get $json $path len]
    if { $idx >= 0 } {
        return [string range $json $idx [expr {$idx + $len - 1}]]
    }
    return ""
}

###############################################################################
# Gets the type of the token by looking at the first char of it.
#
# @param {*} token The token
# @returns {string} The token type on success, "invalid" on error
proc json_get_type { token } {
    switch -exact -- [string index $token 0] {
        "\"" { return "string" }
        "\[" { return "array" }
        "\{" { return "object" }
        "f"  { return "false" }
        "t"  { return "true" }
        "n"  { return "null" }
        "0" - "1" - "2" - "3" - "4" - "5" - 
        "6" - "7" - "8" - "9" - "-" - "." {
            return "number"
        }
    }
    return "invalid"
}

###############################################################################
# Decodes an Json string and removes the enclosing quotes.
#
# @param {string} token Json string to decode
# @returns {string} Decoded Json string
proc json_decode_str { token } {
    set JSON_ESCAPES [list "b" "f" "n" "r" "t" "\\" "\""]
    set JSON_ESCAPES_DECODED [list "\b" "\f" "\n" "\r" "\t" "\\" "\""]
    set len [expr {[string length $token] - 1}]
    set decoded ""
    for { set i 1 } { $i < $len } { incr i } {
        set c [string index $token $i]
        if { $c eq "\\" } {
            # Json escape
            set nc [string index $token [expr {$i + 1}]]
            if { [set idx [lsearch -exact $JSON_ESCAPES $nc]] > -1 } {
                append decoded [lindex $JSON_ESCAPES_DECODED $idx]
            } else {
                # Ignore invalid escape value
            }
            # Skip next char
            incr i
        } else {
            append decoded $c
        }
    }
    return $decoded
}

###############################################################################
# Tests

###############################################################################
# Simple json_get test function
#
# @param {string} json Json string to parse
# @param {string} path JsonPath expression
# @param {string} expected Expected value
# @returns {number} 0 on success, else 1
proc test_json_get { json path expected } {
    puts "- path: $path"
    set token [json_get_tok $json $path]
    if { ($token eq "") || ($token ne $expected && $expected ne "") } {
        puts "  ERROR: found: $token, expected: $expected"
        return 1
    }
    puts "  OK: found: $token, expected: $expected"
    return 0
}

###############################################################################
# Simple json decode test function
#
# @param {string} token Json string to decode
# @param {string} expected Expected value
# @returns {number} 0 on success, else 1
proc test_json_decode { token expected } {
    puts "- decode: $token"
    set decoded [json_decode_str "\"test\"test\""]
    if { $decoded eq "test\"test" } {
        puts "  OK: decoded $decoded, expected: $expected"
        return 0
    }
    puts "  ERROR: decoded $decoded, expected: $expected"
    return 1
}

puts "\nTest 1"
set json "{\"text1\":\"string1\",\"object1\":{\"text2\":\"string2\",\"array\":\[\"mem1\",\"mem2\"\],\"bool1\":false},\"num1\":1,\"bool2\":true}"
puts "$json"
test_json_get $json "$.text1" "\"string1\""
test_json_get $json "$.object1.text2" "\"string2\""
test_json_get $json "$.object1.bool1" "false"
test_json_get $json "$.num1" "1"
test_json_get $json "$.bool2" "true"
test_json_get $json "$.object1" ""
test_json_get $json "$.object1.array" ""
test_json_get $json "$.object1.array\[0\]" "\"mem1\""
test_json_get $json "$.object1.array\[1\]" "\"mem2\""

puts "\nTest 2"
set json "{\"text1\":\"string1\",\"object1\":{\"text2\":\"string2\",\"array1\":\[\"mem1\",\"mem2\"\]},\"num1\":1,\"bool2\":true}"
puts "$json"
test_json_get $json "$.num1" "1"

puts "\nTest 3"
set json "{\"object1\": {\"array1\":\[{\"v1\":\"mem1\",\"v2\":\"mem2\"},{\"v3\":\"mem3\"}\],\"num1\":1},\"bool2\":true}"
puts "$json"
test_json_get $json "$.object1.num1" "1"
test_json_get $json "$.object1.array1" ""
test_json_get $json "$.object1.array1\[0\].v1" "\"mem1\""
test_json_get $json "$.object1.array1\[0\].v2" "\"mem2\""
test_json_get $json "$.object1.array1\[1\].v3" "\"mem3\""
test_json_get $json "$.bool2" "true"

puts "\nTest 4"
set json "{\"key1\":\"val\\\"ue1\",\"key\\n2\":\"value2\"}"
puts "$json"
test_json_get $json "$.key1" "\"val\\\"ue1\""
test_json_get $json "$.key\\n2" "\"value2\""

puts "\nTest 5"
test_json_decode "\"test\"test\"" "test\"test"
