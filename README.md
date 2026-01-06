# 🐍 Snake for ZX Spectrum

A classic Snake game for the ZX Spectrum, written in both **Z80 Assembly** and **C**.

![ZX Spectrum Snake](https://img.shields.io/badge/Platform-ZX%20Spectrum-blue)
![Language](https://img.shields.io/badge/Language-Z80%20Assembly%20%7C%20C-green)

## 🎮 Play Online

The game runs in a web-based ZX Spectrum emulator (JSSpeccy). Simply open `index.html` in a browser or host it on any web server.

## 🕹️ Controls

| Key | Action |
|-----|--------|
| **Q** | Move Up |
| **A** | Move Down |
| **O** | Move Left |
| **P** | Move Right |

## ✨ Features

- 🟡 Yellow head, 🟢 green body
- 🔴 Red food pellets
- 🌈 Rainbow-colored border
- 💥 Wall and self-collision detection
- 🔄 Auto-restart on game over

## 🛠️ Building from Source

### C Version (Recommended)

Requires [z88dk](https://z88dk.org/) compiler. Easiest via Docker:

```bash
docker run --rm -v $(pwd):/src z88dk/z88dk \
  zcc +zx -vn -startup=1 -clib=sdcc_iy snake.c -o snake_c -create-app
```

This produces `snake_c.tap`.

### Assembly Version

Requires [pasmo](https://pasmo.speccy.org/) assembler:

```bash
pasmo --tapbas snake.asm snake.tap
```

## 📁 Project Structure

```
├── snake.c          # C source code
├── snake.asm        # Z80 Assembly source code
├── snake_c.tap      # Compiled C version (TAP file)
├── snake.tap        # Compiled Assembly version (TAP file)
├── index.html       # Web page with embedded emulator
├── jsspeccy/        # JSSpeccy emulator files
└── README.md        # This file
```

## 🖥️ Running Locally

1. Start a local web server:
   ```bash
   python3 -m http.server 8080
   ```

2. Open http://localhost:8080 in your browser

## 📜 Technical Details

### Memory Map (Assembly version)
- Code starts at: `0x8000` (32768)
- Snake buffer: 128 bytes for X, 128 bytes for Y coordinates
- Circular buffer with head/tail pointers

### Screen Layout
- Attribute-based graphics (no pixel drawing)
- Play area: columns 1-30, rows 1-22
- Border on row 0, 23 and columns 0, 31

### Colors (ZX Spectrum attribute format)
- Head: PAPER_YELLOW + BRIGHT
- Body: PAPER_GREEN + BRIGHT  
- Food: PAPER_RED + BRIGHT
- Border: Rainbow cycle (Red, Yellow, Green, Cyan, Blue, Magenta)

## 📄 License

MIT License - see [LICENSE](LICENSE) file.

## 🙏 Credits

- **JSSpeccy** - ZX Spectrum emulator by Matt Westcott
- **z88dk** - Z80 C compiler
- **pasmo** - Z80 assembler

---

*Made with ❤️ for the ZX Spectrum community*
