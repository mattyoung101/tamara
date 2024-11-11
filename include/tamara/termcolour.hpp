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

//! This can be set to "1" to please Americans (uses American spelling). Off by default.
#define YANK_MODE 0

#if YANK_MODE
    #define _Colour Color
    #define _colour color
    #define _termcolour termcolor
#else
    #define _Colour Colour
    #define _colour colour
    #define _termcolour termcolour
#endif

namespace _termcolour {

//! ANSI terminal colours
enum class _Colour : uint8_t {
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
inline std::string _colour(_Colour _colour) {
    if (isTTY()) {
        return "\x1b[1;" + std::to_string(static_cast<uint8_t>(_colour)) + "m";
    }
    return "";
}

//! Resets colour, unless this is not a TTY
inline std::string reset() {
    return _colour(_Colour::Reset);
}

} // namespace _termcolour
