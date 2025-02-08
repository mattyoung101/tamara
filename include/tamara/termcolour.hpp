// Simple terminal colouring utility
//
// Separate to the rest of the project, this particular file is available under the ISC licence.
//
// Copyright 2024 Matt Young.
//
// Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is
// hereby granted, provided that the above copyright notice and this permission notice appear in all copies.

// THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE
// INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
// ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF
// USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
// OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

#include <cstdint>
#include <string>
#include <unistd.h>

namespace termcolour {

//! ANSI terminal colours
enum class Colour : uint8_t {
    Black = 30,
    Red = 31,
    Green = 32,
    Yellow = 33,
    Blue = 34,
    Magenta = 35,
    Cyan = 36,
    White = 37,
    Reset = 0,
};

//! Returns if stdout is a TTY
inline bool isTTY() {
    return isatty(STDOUT_FILENO) != 0;
}

//! Returns a colour, unless this is not a TTY
inline std::string colour(Colour colour) {
    if (isTTY()) {
        return "\x1b[1;" + std::to_string(static_cast<uint8_t>(colour)) + "m";
    }
    return "";
}

//! Resets colour, unless this is not a TTY
inline std::string reset() {
    return colour(Colour::Reset);
}

} // namespace termcolour
