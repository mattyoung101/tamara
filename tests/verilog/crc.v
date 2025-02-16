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

// CRC polynomial coefficients: x^2 + x + 1
//                              0x3 (hex)
// CRC width:                   2 bits
// CRC shift direction:         right (little endian)
// Input word width:            2 bits

module crc2 (
    input [1:0] crcIn,
    input [1:0] data,
    output [1:0] crcOut
);
    assign crcOut[0] = crcIn[1] ^ data[1];
    assign crcOut[1] = crcIn[0] ^ crcIn[1] ^ data[0] ^ data[1];
endmodule


// CRC polynomial coefficients: x^4 + x^2 + x + 1
//                              0xE (hex)
// CRC width:                   4 bits
// CRC shift direction:         right (little endian)
// Input word width:            4 bits

module crc4 (
    input [3:0] crcIn,
    input [3:0] data,
    output [3:0] crcOut
);
    assign crcOut[0] = crcIn[1] ^ crcIn[2] ^ data[1] ^ data[2];
    assign crcOut[1] = crcIn[2] ^ crcIn[3] ^ data[2] ^ data[3];
    assign crcOut[2] = crcIn[1] ^ crcIn[2] ^ crcIn[3] ^ data[1] ^ data[2] ^ data[3];
    assign crcOut[3] = crcIn[0] ^ crcIn[1] ^ crcIn[3] ^ data[0] ^ data[1] ^ data[3];
endmodule

// CRC polynomial coefficients: x^6 + x + 1
//                              0x3 (hex)
// CRC width:                   6 bits
// CRC shift direction:         left (big endian)
// Input word width:            6 bits

module crc6 (
    input [5:0] crcIn,
    input [5:0] data,
    output [5:0] crcOut
);
    assign crcOut[0] = crcIn[0] ^ crcIn[5] ^ data[0] ^ data[5];
    assign crcOut[1] = crcIn[0] ^ crcIn[1] ^ crcIn[5] ^ data[0] ^ data[1] ^ data[5];
    assign crcOut[2] = crcIn[1] ^ crcIn[2] ^ data[1] ^ data[2];
    assign crcOut[3] = crcIn[2] ^ crcIn[3] ^ data[2] ^ data[3];
    assign crcOut[4] = crcIn[3] ^ crcIn[4] ^ data[3] ^ data[4];
    assign crcOut[5] = crcIn[4] ^ crcIn[5] ^ data[4] ^ data[5];
endmodule

// CRC polynomial coefficients: x^7 + x^5 + x^4 + x^2 + x + 1
//                              0x76 (hex)
// CRC width:                   7 bits
// CRC shift direction:         right (little endian)
// Input word width:            7 bits

module crc7 (
    input [6:0] crcIn,
    input [6:0] data,
    output [6:0] crcOut
);
    assign crcOut[0] = crcIn[1] ^ crcIn[2] ^ crcIn[3] ^ crcIn[4] ^ crcIn[5] ^ data[1] ^ data[2] ^ data[3] ^ data[4] ^ data[5];
    assign crcOut[1] = crcIn[2] ^ crcIn[3] ^ crcIn[4] ^ crcIn[5] ^ crcIn[6] ^ data[2] ^ data[3] ^ data[4] ^ data[5] ^ data[6];
    assign crcOut[2] = crcIn[1] ^ crcIn[2] ^ crcIn[6] ^ data[1] ^ data[2] ^ data[6];
    assign crcOut[3] = crcIn[0] ^ crcIn[1] ^ crcIn[4] ^ crcIn[5] ^ data[0] ^ data[1] ^ data[4] ^ data[5];
    assign crcOut[4] = crcIn[0] ^ crcIn[1] ^ crcIn[2] ^ crcIn[5] ^ crcIn[6] ^ data[0] ^ data[1] ^ data[2] ^ data[5] ^ data[6];
    assign crcOut[5] = crcIn[4] ^ crcIn[5] ^ crcIn[6] ^ data[4] ^ data[5] ^ data[6];
    assign crcOut[6] = crcIn[0] ^ crcIn[1] ^ crcIn[2] ^ crcIn[3] ^ crcIn[4] ^ crcIn[6] ^ data[0] ^ data[1] ^ data[2] ^ data[3] ^ data[4] ^ data[6];
endmodule

// CRC polynomial coefficients: x^8 + x^2 + x + 1
//                              0x7 (hex)
// CRC width:                   8 bits
// CRC shift direction:         left (big endian)
// Input word width:            8 bits

module crc8 (
    input [7:0] crcIn,
    input [7:0] data,
    output [7:0] crcOut
);
    assign crcOut[0] = crcIn[0] ^ crcIn[6] ^ crcIn[7] ^ data[0] ^ data[6] ^ data[7];
    assign crcOut[1] = crcIn[0] ^ crcIn[1] ^ crcIn[6] ^ data[0] ^ data[1] ^ data[6];
    assign crcOut[2] = crcIn[0] ^ crcIn[1] ^ crcIn[2] ^ crcIn[6] ^ data[0] ^ data[1] ^ data[2] ^ data[6];
    assign crcOut[3] = crcIn[1] ^ crcIn[2] ^ crcIn[3] ^ crcIn[7] ^ data[1] ^ data[2] ^ data[3] ^ data[7];
    assign crcOut[4] = crcIn[2] ^ crcIn[3] ^ crcIn[4] ^ data[2] ^ data[3] ^ data[4];
    assign crcOut[5] = crcIn[3] ^ crcIn[4] ^ crcIn[5] ^ data[3] ^ data[4] ^ data[5];
    assign crcOut[6] = crcIn[4] ^ crcIn[5] ^ crcIn[6] ^ data[4] ^ data[5] ^ data[6];
    assign crcOut[7] = crcIn[5] ^ crcIn[6] ^ crcIn[7] ^ data[5] ^ data[6] ^ data[7];
endmodule

// CRC polynomial coefficients: x^16 + x^15 + x^2 + 1
//                              0xA001 (hex)
// CRC width:                   16 bits
// CRC shift direction:         right (little endian)
// Input word width:            16 bits

module crc16 (
    input [15:0] crcIn,
    input [15:0] data,
    output [15:0] crcOut
);
    assign crcOut[0] = crcIn[0] ^ crcIn[1] ^ crcIn[3] ^ crcIn[4] ^ crcIn[5] ^ crcIn[6] ^ crcIn[7] ^ crcIn[8] ^ crcIn[9] ^ crcIn[10] ^ crcIn[11] ^ crcIn[12] ^ crcIn[13] ^ crcIn[14] ^ crcIn[15] ^ data[0] ^ data[1] ^ data[3] ^ data[4] ^ data[5] ^ data[6] ^ data[7] ^ data[8] ^ data[9] ^ data[10] ^ data[11] ^ data[12] ^ data[13] ^ data[14] ^ data[15];
    assign crcOut[1] = crcIn[2] ^ crcIn[3] ^ data[2] ^ data[3];
    assign crcOut[2] = crcIn[3] ^ crcIn[4] ^ data[3] ^ data[4];
    assign crcOut[3] = crcIn[4] ^ crcIn[5] ^ data[4] ^ data[5];
    assign crcOut[4] = crcIn[5] ^ crcIn[6] ^ data[5] ^ data[6];
    assign crcOut[5] = crcIn[6] ^ crcIn[7] ^ data[6] ^ data[7];
    assign crcOut[6] = crcIn[7] ^ crcIn[8] ^ data[7] ^ data[8];
    assign crcOut[7] = crcIn[8] ^ crcIn[9] ^ data[8] ^ data[9];
    assign crcOut[8] = crcIn[9] ^ crcIn[10] ^ data[9] ^ data[10];
    assign crcOut[9] = crcIn[10] ^ crcIn[11] ^ data[10] ^ data[11];
    assign crcOut[10] = crcIn[11] ^ crcIn[12] ^ data[11] ^ data[12];
    assign crcOut[11] = crcIn[12] ^ crcIn[13] ^ data[12] ^ data[13];
    assign crcOut[12] = crcIn[0] ^ crcIn[13] ^ crcIn[14] ^ data[0] ^ data[13] ^ data[14];
    assign crcOut[13] = crcIn[1] ^ crcIn[14] ^ crcIn[15] ^ data[1] ^ data[14] ^ data[15];
    assign crcOut[14] = crcIn[1] ^ crcIn[2] ^ crcIn[3] ^ crcIn[4] ^ crcIn[5] ^ crcIn[6] ^ crcIn[7] ^ crcIn[8] ^ crcIn[9] ^ crcIn[10] ^ crcIn[11] ^ crcIn[12] ^ crcIn[13] ^ crcIn[14] ^ data[1] ^ data[2] ^ data[3] ^ data[4] ^ data[5] ^ data[6] ^ data[7] ^ data[8] ^ data[9] ^ data[10] ^ data[11] ^ data[12] ^ data[13] ^ data[14];
    assign crcOut[15] = crcIn[0] ^ crcIn[2] ^ crcIn[3] ^ crcIn[4] ^ crcIn[5] ^ crcIn[6] ^ crcIn[7] ^ crcIn[8] ^ crcIn[9] ^ crcIn[10] ^ crcIn[11] ^ crcIn[12] ^ crcIn[13] ^ crcIn[14] ^ crcIn[15] ^ data[0] ^ data[2] ^ data[3] ^ data[4] ^ data[5] ^ data[6] ^ data[7] ^ data[8] ^ data[9] ^ data[10] ^ data[11] ^ data[12] ^ data[13] ^ data[14] ^ data[15];
endmodule
