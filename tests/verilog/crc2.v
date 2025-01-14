// THIS IS GENERATED VERILOG CODE.
// https://bues.ch/h/crcgen
//
// This code is Public Domain.
// Permission to use, copy, modify, and/or distribute this software for any
// purpose with or without fee is hereby granted.
//
// THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
// WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
// SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER
// RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
// NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE
// USE OR PERFORMANCE OF THIS SOFTWARE.

`ifndef CRC_V_
`define CRC_V_

// CRC polynomial coefficients: x^2 + x + 1
//                              0x3 (hex)
// CRC width:                   2 bits
// CRC shift direction:         right (little endian)
// Input word width:            2 bits

module crc (
    input [1:0] crcIn,
    input [1:0] data,
    output [1:0] crcOut
);
    assign crcOut[0] = crcIn[1] ^ data[1];
    assign crcOut[1] = crcIn[0] ^ crcIn[1] ^ data[0] ^ data[1];
endmodule

`endif // CRC_V_
