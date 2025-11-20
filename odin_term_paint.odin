// OPaint - A terminal paint program written in Odin
//
// This is a terminal paint program that has the main simplified features of a
// paint program but for the terminal using the increasing terminal resolution
// provided by the unicode Braille dot character and it's sub decomposition.
// 
// You can use it even over SSH :-)
// 
// It has the following features:
// 
// - Paint brush movement with cursors, keypad, and mouse.
// - Paint  and erasure with mouse.
// - Tools:
//    1. Free line
//    2. Rectangule
//    3. Filled rectangule
//    4. Ellipse
//    5. Filled Ellipse
//    6. Text, with support for Backspace
//    7. Multiple brush sizes
//    8. Multiple colors
// - Save and Load with support for .PPM and .BMP image formats.
// - Undo and redo.
// - Help menu with keybindings.
//
// Note: In the Odin compiler dir the vendors/stb src for the
//       stb image has to be also compilled, by executing make
//       on Linux. 
//  
// License
// MIT Open Source license
// 

package main

import "core:fmt"
import "core:math"
import "core:strings"
import "core:strconv"
import "core:mem"
import "core:slice"
import "core:c"
import "core:os"

import stbi "vendor:stb/image"

//
// The inner dots resolution of a Unicode Braille Dots character.
// 

WIDTH_SCALE  :: 2
HEIGHT_SCALE :: 4

//
// Icons in Unicode
//

ICON_SAVE    :: "💾"
ICON_LOAD    :: "📂"
ICON_PEN     :: "🖌 "
ICON_ERASER  :: "🧽"
ICON_LINE    :: "📏"
ICON_ELLIPSE :: "⭕"
ICON_ELL_FILL:: "⬤"
ICON_RECT    :: "⬜"
ICON_FILL    :: "⬛"
ICON_TEXT    :: "Aa"
ICON_UNDO    :: "↩️"
ICON_REDO    :: "↪️"
ICON_CLEAR   :: "🗑 "
ICON_QUIT    :: "🚪"
ICON_COLOR   :: "🎨"

//
// Font Data ( 5x7 ASCII 32-126 )
//

FONT_WIDTH  :: 5
FONT_HEIGHT :: 7

font_data := [ 95 ][ 5 ]u8{
    { 0x00, 0x00, 0x00, 0x00, 0x00 }, // Space
    { 0x00, 0x00, 0x5f, 0x00, 0x00 }, // !
    { 0x00, 0x07, 0x00, 0x07, 0x00 }, // "
    { 0x14, 0x7f, 0x14, 0x7f, 0x14 }, // #
    { 0x24, 0x2a, 0x7f, 0x2a, 0x12 }, // $
    { 0x23, 0x13, 0x08, 0x64, 0x62 }, // %
    { 0x36, 0x49, 0x55, 0x22, 0x50 }, // &
    { 0x00, 0x05, 0x03, 0x00, 0x00 }, // '
    { 0x00, 0x1c, 0x22, 0x41, 0x00 }, // (
    { 0x00, 0x41, 0x22, 0x1c, 0x00 }, // )
    { 0x14, 0x08, 0x3e, 0x08, 0x14 }, // *
    { 0x08, 0x08, 0x3e, 0x08, 0x08 }, // +
    { 0x00, 0x50, 0x30, 0x00, 0x00 }, // ,
    { 0x08, 0x08, 0x08, 0x08, 0x08 }, // -
    { 0x00, 0x60, 0x60, 0x00, 0x00 }, // .
    { 0x20, 0x10, 0x08, 0x04, 0x02 }, // /
    { 0x3e, 0x51, 0x49, 0x45, 0x3e }, // 0
    { 0x00, 0x42, 0x7f, 0x40, 0x00 }, // 1
    { 0x42, 0x61, 0x51, 0x49, 0x46 }, // 2
    { 0x21, 0x41, 0x45, 0x4b, 0x31 }, // 3
    { 0x18, 0x14, 0x12, 0x7f, 0x10 }, // 4
    { 0x27, 0x45, 0x45, 0x45, 0x39 }, // 5
    { 0x3c, 0x4a, 0x49, 0x49, 0x30 }, // 6
    { 0x01, 0x71, 0x09, 0x05, 0x03 }, // 7
    { 0x36, 0x49, 0x49, 0x49, 0x36 }, // 8
    { 0x06, 0x49, 0x49, 0x29, 0x1e }, // 9
    { 0x00, 0x36, 0x36, 0x00, 0x00 }, // :
    { 0x00, 0x56, 0x36, 0x00, 0x00 }, // ;
    { 0x08, 0x14, 0x22, 0x41, 0x00 }, // <
    { 0x14, 0x14, 0x14, 0x14, 0x14 }, // =
    { 0x00, 0x41, 0x22, 0x14, 0x08 }, // >
    { 0x02, 0x01, 0x51, 0x09, 0x06 }, // ?
    { 0x32, 0x49, 0x79, 0x41, 0x3e }, // @
    { 0x7e, 0x11, 0x11, 0x11, 0x7e }, // A
    { 0x7f, 0x49, 0x49, 0x49, 0x36 }, // B
    { 0x3e, 0x41, 0x41, 0x41, 0x22 }, // C
    { 0x7f, 0x41, 0x41, 0x22, 0x1c }, // D
    { 0x7f, 0x49, 0x49, 0x49, 0x41 }, // E
    { 0x7f, 0x09, 0x09, 0x09, 0x01 }, // F
    { 0x3e, 0x41, 0x49, 0x49, 0x7a }, // G
    { 0x7f, 0x08, 0x08, 0x08, 0x7f }, // H
    { 0x00, 0x41, 0x7f, 0x41, 0x00 }, // I
    { 0x20, 0x40, 0x41, 0x3f, 0x01 }, // J
    { 0x7f, 0x08, 0x14, 0x22, 0x41 }, // K
    { 0x7f, 0x40, 0x40, 0x40, 0x40 }, // L
    { 0x7f, 0x02, 0x0c, 0x02, 0x7f }, // M
    { 0x7f, 0x04, 0x08, 0x10, 0x7f }, // N
    { 0x3e, 0x41, 0x41, 0x41, 0x3e }, // O
    { 0x7f, 0x09, 0x09, 0x09, 0x06 }, // P
    { 0x3e, 0x41, 0x51, 0x21, 0x5e }, // Q
    { 0x7f, 0x09, 0x19, 0x29, 0x46 }, // R
    { 0x46, 0x49, 0x49, 0x49, 0x31 }, // S
    { 0x01, 0x01, 0x7f, 0x01, 0x01 }, // T
    { 0x3f, 0x40, 0x40, 0x40, 0x3f }, // U
    { 0x1f, 0x20, 0x40, 0x20, 0x1f }, // V
    { 0x3f, 0x40, 0x38, 0x40, 0x3f }, // W
    { 0x63, 0x14, 0x08, 0x14, 0x63 }, // X
    { 0x07, 0x08, 0x70, 0x08, 0x07 }, // Y
    { 0x61, 0x51, 0x49, 0x45, 0x43 }, // Z
    { 0x00, 0x7f, 0x41, 0x41, 0x00 }, // [
    { 0x02, 0x04, 0x08, 0x10, 0x20 }, // \
    { 0x00, 0x41, 0x41, 0x7f, 0x00 }, // ]
    { 0x04, 0x02, 0x01, 0x02, 0x04 }, // ^
    { 0x40, 0x40, 0x40, 0x40, 0x40 }, // _
    { 0x00, 0x01, 0x02, 0x04, 0x00 }, // `
    { 0x20, 0x54, 0x54, 0x54, 0x78 }, // a
    { 0x7f, 0x48, 0x44, 0x44, 0x38 }, // b
    { 0x38, 0x44, 0x44, 0x44, 0x20 }, // c
    { 0x38, 0x44, 0x44, 0x48, 0x7f }, // d
    { 0x38, 0x54, 0x54, 0x54, 0x18 }, // e
    { 0x08, 0x7e, 0x09, 0x01, 0x02 }, // f
    { 0x0c, 0x52, 0x52, 0x52, 0x3e }, // g
    { 0x7f, 0x08, 0x04, 0x04, 0x78 }, // h
    { 0x00, 0x44, 0x7d, 0x40, 0x00 }, // i
    { 0x20, 0x40, 0x44, 0x3d, 0x00 }, // j
    { 0x7f, 0x10, 0x28, 0x44, 0x00 }, // k
    { 0x00, 0x41, 0x7f, 0x40, 0x00 }, // l
    { 0x7c, 0x04, 0x18, 0x04, 0x78 }, // m
    { 0x7c, 0x08, 0x04, 0x04, 0x78 }, // n
    { 0x38, 0x44, 0x44, 0x44, 0x38 }, // o
    { 0x7c, 0x14, 0x14, 0x14, 0x08 }, // p
    { 0x08, 0x14, 0x14, 0x18, 0x7c }, // q
    { 0x7c, 0x08, 0x04, 0x04, 0x08 }, // r
    { 0x48, 0x54, 0x54, 0x54, 0x20 }, // s
    { 0x04, 0x3f, 0x44, 0x40, 0x20 }, // t
    { 0x3c, 0x40, 0x40, 0x20, 0x7c }, // u
    { 0x1c, 0x20, 0x40, 0x20, 0x1c }, // v
    { 0x3c, 0x40, 0x30, 0x40, 0x3c }, // w
    { 0x44, 0x28, 0x10, 0x28, 0x44 }, // x
    { 0x0c, 0x50, 0x50, 0x50, 0x3c }, // y
    { 0x44, 0x64, 0x54, 0x4c, 0x44 }, // z
    { 0x00, 0x08, 0x36, 0x41, 0x00 }, // {
    { 0x00, 0x00, 0x7f, 0x00, 0x00 }, // |
    { 0x00, 0x41, 0x36, 0x08, 0x00 }, // }
    { 0x10, 0x08, 0x08, 0x10, 0x08 }, // ~
}

Color :: [ 3 ]u8

PixelState :: struct {
    
    active : bool,
    color  : Color,
}

Canvas :: struct {
    
    term_w : int,
    term_h : int,
    virt_w : int,
    virt_h : int,
    pixels : [ ]PixelState,
}

History :: struct {
    
    undo : [ dynamic ][ ]PixelState,
    redo : [ dynamic ][ ]PixelState,
}

ToolType :: enum {
    
    Pen,
    Line,
    Ellipse,
    FilledEllipse,
    Rect,
    FilledRect,
    Text,
}

AppState :: struct {
    
    running : bool,
    canvas  : Canvas,
    history : History,
    
    // Cursor / Input
    cursor_x : int,
    cursor_y : int,
    
    // Tools and State
    tool_type   : ToolType,
    brush_color : Color,
    brush_size  : int,
    palette_idx : int,
    
    // Mouse Interpolation
    last_mouse_x : int,
    last_mouse_y : int,
    mouse_down   : bool,
    
    // Shape Tool State
    shape_start_set : bool,
    shape_start_x   : int,
    shape_start_y   : int,

    // UI
    status_msg : string,
    show_help  : bool,
}

PALETTE_COLORS := [ 16 ]Color {
    
    { 255, 255, 255 }, // White
    { 0, 0, 0 },       // Black
    { 255, 0, 0 },     // Red
    { 0, 255, 0 },     // Green
    { 0, 0, 255 },     // Blue
    { 255, 255, 0 },   // Yellow
    { 0, 255, 255 },   // Cyan
    { 255, 0, 255 },   // Magenta
    { 255, 128, 0 },   // Orange
    { 128, 0, 255 },   // Purple
    { 128, 128, 128 }, // Gray
    { 165, 42, 42 },   // Brown
    { 255, 192, 203 }, // Pink
    { 64, 224, 208 },  // Turquoise
    { 50, 205, 50 },   // Lime
    { 75, 0, 130 },    // Indigo
}

//
// Manual POSIX Definitions
//

NCCS :: 32

Termios :: struct {
    
    c_iflag  : c.uint,
    c_oflag  : c.uint,
    c_cflag  : c.uint,
    c_lflag  : c.uint,
    c_line   : c.uchar,
    c_cc     : [ NCCS ]c.uchar,
    c_ispeed : c.uint,
    c_ospeed : c.uint,
}

Winsize :: struct {
   
   ws_row    : c.ushort,
   ws_col    : c.ushort,
   ws_xpixel : c.ushort,
   ws_ypixel : c.ushort,
}

TC_BRKINT  :: 0o000002
TC_ICRNL   :: 0o000400
TC_INPCK   :: 0o000020
TC_ISTRIP  :: 0o000040
TC_IXON    :: 0o002000
TC_OPOST   :: 0o000001
TC_CS8     :: 0o000060
TC_ECHO    :: 0o000010
TC_ICANON  :: 0o000002
TC_IEXTEN  :: 0o100000
TC_ISIG    :: 0o000001
TC_VMIN    :: 6
TC_VTIME   :: 5
TCSAFLUSH  :: 2
TIOCGWINSZ :: 0x5413

//
// C bindings
// 

foreign import libc "system:c"

foreign libc {
    
    tcgetattr  :: proc( fd        : c.int,
                        termios_p : ^Termios ) -> 
                        c.int ---
    
    tcsetattr  :: proc( fd               : c.int,
                        optional_actions : c.int,
                        termios_p        : ^Termios ) ->
                        c.int ---
                        
    ioctl      :: proc( fd      : c.int,
                        request : c.ulong,
                        arg     : rawptr ) -> 
                        c.int ---
}

//
// Terminal Control
//

original_termios : Termios

enable_raw_mode :: proc ( ) {
    
    fd := c.int( os.stdin )
    if tcgetattr( fd, & original_termios ) == -1 {
        
        return
    }
    raw := original_termios
    raw.c_iflag &= ~( c.uint( TC_BRKINT ) |
                      c.uint( TC_ICRNL )  |
                      c.uint( TC_INPCK )  |
                      c.uint( TC_ISTRIP ) |
                      c.uint( TC_IXON ) )
    
    raw.c_oflag &= ~( c.uint( TC_OPOST ) )
    raw.c_cflag |=  ( c.uint( TC_CS8 ) )
    
    raw.c_lflag &= ~( c.uint( TC_ECHO )   |
                      c.uint( TC_ICANON ) |
                      c.uint( TC_IEXTEN ) |
                      c.uint( TC_ISIG ) )
    
    raw.c_cc[ TC_VMIN ]  = 0
    raw.c_cc[ TC_VTIME ] = 1 
    tcsetattr( fd, c.int( TCSAFLUSH ), & raw )
    fmt.print( "\x1b[?1000h\x1b[?1002h\x1b[?1006h\x1b[?25l" ) 
}

disable_raw_mode :: proc ( ) {
    
    fd := c.int( os.stdin )
    tcsetattr( fd, c.int( TCSAFLUSH ), & original_termios )
    fmt.print( "\x1b[?1000l\x1b[?1002l\x1b[?1006l\x1b[?25h" ) 
}

get_term_size :: proc ( ) -> 
                      ( int, int ) {
    
    ws : Winsize
    fd := c.int( os.stdout )
    if ioctl( fd, c.ulong( TIOCGWINSZ ), & ws ) == -1 {
     
        return 80, 24
    }
    return int( ws.ws_col ), int( ws.ws_row )
}

//
// History Logic
//

clone_canvas_pixels :: proc ( c : ^Canvas ) ->
                              [ ]PixelState {
                                  
    new_p := make( [ ]PixelState, len( c.pixels ) )
    copy( new_p, c.pixels )
    return new_p
}

push_history :: proc( app : ^AppState ) {
    
    // Clear redo
    for buf in app.history.redo {
       
       delete( buf ) 
    }
    clear( & app.history.redo )

    // Save current state to undo
    append( & app.history.undo, clone_canvas_pixels( & app.canvas ) )

    // Limit history size ( 50 )
    if len( app.history.undo ) > 50 {
        
        old := app.history.undo[ 0 ]
        delete( old )
        ordered_remove( & app.history.undo, 0 )
    }
}

perform_undo :: proc ( app : ^AppState ) {
    
    if len( app.history.undo ) == 0 { 
        
        app.status_msg = "Nothing to Undo";
        return
    }

    // Save current state to redo
    append( & app.history.redo, clone_canvas_pixels( & app.canvas ) )

    // Pop from undo
    prev_state := pop( & app.history.undo )
    delete( app.canvas.pixels )
    app.canvas.pixels = prev_state
    app.status_msg    = "Undid Action"
}

perform_redo :: proc ( app : ^AppState ) {
    
    if len( app.history.redo ) == 0 { 
        
        app.status_msg = "Nothing to Redo"
        return
    }

    // Save current state to undo
    append( & app.history.undo, clone_canvas_pixels( & app.canvas ) )

    // Pop from redo
    next_state := pop( & app.history.redo )
    delete( app.canvas.pixels )
    app.canvas.pixels = next_state
    app.status_msg    = "Redid Action"
}

//
// Main program
//

init_canvas :: proc ( c : ^Canvas,
                      w : int,
                      h : int ) {
                          
    c.term_w = w
    c.term_h = h - 2 
    c.virt_w = c.term_w * WIDTH_SCALE
    c.virt_h = c.term_h * HEIGHT_SCALE
    c.pixels = make( [ ]PixelState, c.virt_w * c.virt_h )
    for i in 0 ..< len( c.pixels ) {
        
        c.pixels[ i ] = PixelState{ false, { 0, 0, 0 } }
    }
}

set_pixel_raw :: proc ( c     : ^Canvas,
                        x     : int,
                        y     : int,
                        color : Color,
                        erase : bool ) {
                            
    if x < 0 || x >= c.virt_w || y < 0 || y >= c.virt_h {
       
       return
    }
    
    idx := y * c.virt_w + x
    c.pixels[ idx ].active = !erase
    if !erase {
        
        c.pixels[ idx ].color = color
    }
}

paint_at :: proc ( app   : ^AppState,
                   cx    : int,
                   cy    : int,
                   erase : bool ) {
                       
    if app.brush_size == 0 {
        
        set_pixel_raw( & app.canvas, cx, cy, app.brush_color, erase )
        return
    }
    radius := app.brush_size
    for y := -radius; y <= radius; y += 1 {
        
        for x := -radius; x <= radius; x += 1 {
            
            if x * x + y * y <= radius * radius {
                
                set_pixel_raw( & app.canvas, cx + x, cy + y, app.brush_color, erase )
            }
        }
    }
}

draw_line :: proc ( app   : ^AppState,
                    x0    : int,
                    y0    : int,
                    x1    : int,
                    y1    : int,
                    erase : bool ) {
    
    dx  := abs( x1 - x0 )
    dy  := -abs( y1 - y0 )
    sx  := x0 < x1 ? 1 : -1
    sy  := y0 < y1 ? 1 : -1
    err := dx + dy
    cx, cy := x0, y0
    for {
        
        paint_at( app, cx, cy, erase )
        
        if cx == x1 && cy == y1 {
           
           break
        }
        
        e2 := 2 * err
        
        if e2 >= dy {
           
           err += dy
           cx += sx 
        }
        
        if e2 <= dx {
           
           err += dx
           cy += sy
        }
    }
}

draw_rect :: proc ( app    : ^AppState,
                    x0     : int,
                    y0     : int,
                    x1     : int,
                    y1     : int,
                    filled : bool,
                    erase  : bool ) {
    
    min_x := min( x0, x1 )
    max_x := max( x0, x1 )
    min_y := min( y0, y1 )
    max_y := max( y0, y1 )

    if filled {
        
        for y := min_y; y <= max_y; y += 1 {
            
            for x := min_x; x <= max_x; x += 1 {
            
                paint_at( app, x, y, erase )
            }
        }
    } else {
        
        // Horizontal
        for x := min_x; x <= max_x; x += 1 {
            
            paint_at( app, x, min_y, erase )
            paint_at( app, x, max_y, erase )
        }
        
        // Vertical
        for y := min_y; y <= max_y; y += 1 {
            
            paint_at( app, min_x, y, erase )
            paint_at( app, max_x, y, erase )
        }
    }
}

draw_ellipse :: proc ( app    : ^AppState,
                       x0     : int,
                       y0     : int,
                       x1     : int,
                       y1     : int,
                       filled : bool,
                       erase  : bool ) {
    
    min_x := min( x0, x1 )
    max_x := max( x0, x1 )
    min_y := min( y0, y1 )
    max_y := max( y0, y1 )
    a  := ( max_x - min_x ) / 2
    b  := ( max_y - min_y ) / 2
    xc := min_x + a
    yc := min_y + b
    x  := 0
    y  := b
    a2 := a * a
    b2 := b * b
    fx := 0
    fy := 2 * a2 * y
    p  := b2 - ( a2 * b ) + ( a2 / 4 )

    plot_points := proc ( app    : ^AppState, 
                          xc     : int,
                          yc     : int,
                          x      : int,
                          y      : int,
                          filled : bool,
                          erase  : bool ) {
        if filled {
            
            // Draw horizontal lines between symmetrical points
            for ix := xc - x; ix <= xc + x; ix += 1 {
                
                paint_at( app, ix, yc + y, erase )
                paint_at( app, ix, yc - y, erase )
            }
        } else {
            
            paint_at( app, xc + x, yc + y, erase )
            paint_at( app, xc - x, yc + y, erase )
            paint_at( app, xc + x, yc - y, erase )
            paint_at( app, xc - x, yc - y, erase )
        }
    }
    
    plot_points( app, xc, yc, x, y, filled, erase )
    
    for fx < fy {
        
        x  += 1
        fx += 2 * b2
        if p < 0 {
           
            p += b2 + fx
        } else {
           
           y  -= 1
           fy -= 2 * a2
           p  += b2 + fx - fy 
        }
        
        plot_points( app, xc, yc, x, y, filled, erase )
    }
    
    p = b2 * ( x * x + x ) + a2 * ( y * y - y) - a2 * b2
    
    for y > 0 {
        
        y  -= 1
        fy -= 2 * a2
        
        if p >= 0 {
           
           p += a2 - fy
        } else {
           
            x  += 1
            fx += 2 * b2
            p  += a2 - fy + fx
        }
        
        plot_points( app, xc, yc, x, y, filled, erase )
    }
}

draw_char :: proc ( app : ^AppState,
                    ch  : u8 ) {
    
    if ch < 32 || ch > 126 {
        
        return
    }
    
    idx     := int(ch - 32)
    start_x := app.cursor_x
    start_y := app.cursor_y
    for col in 0 ..< 5 {
        
        col_byte := font_data[ idx ][ col ]
        for row in 0 ..< 7 {
            
            if ( col_byte & ( 1 << u8( row ) ) ) != 0 {
                
                set_pixel_raw( & app.canvas,
                               start_x + col, start_y + row, app.brush_color,
                               false )
            }
        }
    }
    
    app.cursor_x += 6 
}

cycle_color :: proc ( app : ^AppState ) {
    
    app.palette_idx = ( app.palette_idx + 1 ) % len( PALETTE_COLORS )
    app.brush_color = PALETTE_COLORS[ app.palette_idx ]
    app.status_msg  = fmt.tprintf( "Color: R%d G%d B%d", app.brush_color.r, app.brush_color.g, app.brush_color.b )
}

//
// Render
//

get_braille_mask :: proc ( x : int,
                           y : int ) ->
                           int {
                               
    m := [ 2 ][ 4 ]int{ { 0x01, 0x02, 0x04, 0x40 },
                        { 0x08, 0x10, 0x20, 0x80 }
                      }
    return m[ x ][ y ]
}

render :: proc( app : ^AppState ) {
    
    fmt.print( "\x1b[H" )
    sb := strings.builder_make( )
    defer strings.builder_destroy( & sb )

    for ty in 0 ..< app.canvas.term_h {
        
        for tx in 0 ..< app.canvas.term_w {
            
            base_code := 0x2800
            r, g, b, count := 0, 0, 0, 0
            for py in 0 ..< 4 {
                
                for px in 0 ..< 2 {
                    
                    idx := (ty * 4 + py) * app.canvas.virt_w + (tx * 2 + px)
                    if idx < len( app.canvas.pixels ) && app.canvas.pixels[ idx ].active {
                        
                        base_code |= get_braille_mask( px, py )
                        col := app.canvas.pixels[ idx ].color
                        r += int( col.r )
                        g += int( col.g )
                        b += int( col.b )
                        count += 1
                    }
                }
            }
            if count > 0 {
                
                r /= count
                g /= count
                b /= count
                fmt.sbprintf( & sb, "\x1b[38;2;%d;%d;%dm", r, g, b )
            } else {
               
               fmt.sbprint( & sb, "\x1b[38;2;60;60;60m" )
            }

            cx, cy := app.cursor_x / 2, app.cursor_y / 4
            
            if tx == cx && ty == cy {
            
                fmt.sbprint( & sb, "\x1b[48;2;50;50;150m" )
            } else {
               
               fmt.sbprint( & sb, "\x1b[49m" )
            }
            
            fmt.sbprint( & sb, rune( base_code ) )
        }
        
        fmt.sbprint( & sb, "\x1b[0m\r\n" )
    }

    fmt.sbprint( & sb, "\x1b[48;2;30;30;30m\x1b[37m" ) 
    tool_icon := ICON_PEN
    
    if app.tool_type == .Line {
        
        tool_icon = ICON_LINE
    }
    
    if app.tool_type == .Ellipse {
       
       tool_icon = ICON_ELLIPSE
    }
    
    if app.tool_type == .FilledEllipse {
        
        tool_icon = ICON_ELL_FILL
    }
    
    if app.tool_type == .Rect {
        
        tool_icon = ICON_RECT
    }
    
    if app.tool_type == .FilledRect {
        
        tool_icon = ICON_FILL
    }
    
    if app.tool_type == .Text {
        
        tool_icon = ICON_TEXT
    }
    
    fmt.sbprintf( & sb, " %s | Sz:%d | Clr:\x1b[38;2;%d;%d;%dm█\x1b[37m | ",
                  tool_icon, app.brush_size, app.brush_color.r, app.brush_color.g, app.brush_color.b )
    
    fmt.sbprintf( & sb, "[H]elp | Pos: %d,%d ", app.cursor_x, app.cursor_y )
    
    if app.tool_type == .Text { 
        
        fmt.sbprint( & sb, "| TYPE TEXT (Esc to Exit)" )
    }
    
    fmt.sbprint( & sb, "\x1b[0m\x1b[K\r\n" ) 
    fmt.sbprintf( & sb, "\x1b[48;2;10;10;10m\x1b[33m %s\x1b[0m\x1b[K", app.status_msg )
    fmt.print( strings.to_string( sb ) )

    if app.show_help {
        
        draw_help_overlay(app.canvas.term_h, app.canvas.term_w )
    }
}

draw_help_overlay :: proc( h : int,
                           w : int ) {
                               
    r := 4
    
    fmt.printf( "\x1b[%d;5H\x1b[48;2;50;50;50m\x1b[37m┌──────────────────────────────────────┐", r ); r+=1
    fmt.printf( "\x1b[%d;5H│              HELP MENU               │", r ); r+=1
    fmt.printf( "\x1b[%d;5H├──────────────────────────────────────┤", r ); r+=1
    fmt.printf( "\x1b[%d;5H│ Mouse Left   : Paint                 │", r ); r+=1
    fmt.printf( "\x1b[%d;5H│ Mouse Right  : Erase                 │", r ); r+=1
    fmt.printf( "\x1b[%d;5H│ Arrows / WASD: Move Cursor           │", r ); r+=1
    fmt.printf( "\x1b[%d;5H│ Numpad 1-9   : Diagonal/Move         │", r ); r+=1
    fmt.printf( "\x1b[%d;5H│ Space        : Paint at Cursor       │", r ); r+=1
    fmt.printf( "\x1b[%d;5H│ v            : Line Tool             │", r ); r+=1
    fmt.printf( "\x1b[%d;5H│ o            : Ellipse Tool          │", r ); r+=1
    fmt.printf( "\x1b[%d;5H│ e            : Filled Ellipse Tool   │", r ); r+=1
    fmt.printf( "\x1b[%d;5H│ x            : Rectangle Tool        │", r ); r+=1
    fmt.printf( "\x1b[%d;5H│ f            : Filled Rect Tool      │", r ); r+=1
    fmt.printf( "\x1b[%d;5H│ t            : Text Tool (Type!)     │", r ); r+=1
    fmt.printf( "\x1b[%d;5H│ [ / ]        : Brush Size (- / +)    │", r ); r+=1
    fmt.printf( "\x1b[%d;5H│ n            : Cycle Color Palette   │", r ); r+=1
    fmt.printf( "\x1b[%d;5H│ r/g/b/w      : Quick Colors          │", r ); r+=1
    fmt.printf( "\x1b[%d;5H│ s / l        : Save / Load Image     │", r ); r+=1
    fmt.printf( "\x1b[%d;5H│ c            : Clear Canvas          │", r ); r+=1
    fmt.printf( "\x1b[%d;5H│ Ctrl+Z       : Undo                  │", r ); r+=1
    fmt.printf( "\x1b[%d;5H│ Ctrl+Y       : Redo                  │", r ); r+=1
    fmt.printf( "\x1b[%d;5H│ h            : Toggle This Menu      │", r ); r+=1
    fmt.printf( "\x1b[%d;5H│ q            : Quit                  │", r ); r+=1
    fmt.printf( "\x1b[%d;5H└──────────────────────────────────────┘\x1b[0m", r )
    
}

//
// File Input and Output
//

save_image :: proc ( app      : ^AppState,
                     filename : string ) {
                         
    f, err := os.open( filename, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0o644 )
    if err != os.ERROR_NONE {
        
        app.status_msg = fmt.tprintf( "File Open Error: %v", err )
        return 
    }
    defer os.close( f )

    w, h := i32( app.canvas.virt_w ), i32( app.canvas.virt_h )

    if strings.has_suffix( filename, ".ppm" ) {
        
        // PPM Header
        header_str := fmt.tprintf( "P6\n%d %d\n255\n", w, h )
        os.write_string( f, header_str )
        
        // Data
        buf := make( [ ]u8, w * h * 3 )
        defer delete( buf )
        for i in 0 ..< len( app.canvas.pixels ) {
            
            p   := app.canvas.pixels[ i ]
            idx := i * 3
            if p.active {
               
               buf[ idx ]     = p.color.r
               buf[ idx + 1 ] = p.color.g
               buf[ idx + 2 ] = p.color.b
            } else {
               
               buf[ idx ]     = 0
               buf[ idx + 1 ] = 0
               buf[ idx + 2 ] = 0
            }
        }
        
        _, w_err := os.write( f, buf )
        if w_err != os.ERROR_NONE {
            
             app.status_msg = "Write Error"
             return
        }
    } else if strings.has_suffix( filename, ".bmp" ) {
        
        row_size  := ( 3 * w + 3 ) & ( ~i32( 3 ) )
        file_size := u32( 54 + row_size * h )
        
        header: [ 54 ]u8
        header[ 0 ] = 'B'
        header[ 1 ] = 'M'
        mem.copy( & header[ 2 ], & file_size, 4 )
        
        offset : u32 = 54
        mem.copy( & header[ 10 ], & offset, 4 )
       
        sz : u32 = 40
        mem.copy( & header[ 14 ], & sz, 4 )
        mem.copy( & header[ 18 ], & w, 4 )
        mem.copy( & header[ 22 ], & h, 4 )
        
        pl : u16 = 1
        mem.copy( & header[ 26 ], & pl, 2 )
        
        bp : u16 = 24
        mem.copy( & header[ 28 ], & bp, 2 )
        
        os.write( f, header[ : ] )

        row := make( [ ]u8, int( row_size ) )
        defer delete( row )
        
        for y_inv in 0 ..< int( h ) {
            
            y := int( h ) - 1 - y_inv
            mem.set( raw_data( row ), 0, len( row ) )
            for x in 0 ..< int( w ) {
                
                idx := y * int( w ) + x
                p := app.canvas.pixels[ idx ]
                if p.active {
                    
                    // BMP is BGR
                    row[ x * 3 ]     = p.color.b
                    row[ x * 3 + 1 ] = p.color.g
                    row[ x * 3 + 2 ] = p.color.r
                } else {
                    
                    row[ x * 3 ]     = 0
                    row[ x * 3 + 1 ] = 0
                    row[ x * 3 + 2 ] = 0
                }
            }
            os.write( f, row )
        }
    }
    app.status_msg = fmt.tprintf( "Saved to %s", filename )
}

load_image :: proc ( app      : ^AppState,
                     filename : string ) {
                         
    c_name := strings.clone_to_cstring( filename )
    defer delete( c_name )
    
    w  : c.int
    h  : c.int
    ch : c.int
    pix := stbi.load( c_name, & w, & h, & ch, 3 )
    if pix == nil {
       
       app.status_msg = "Load Failed"
       return
    }
    defer stbi.image_free( pix )
    
    push_history( app ) // Save before overwrite
    scale_x, scale_y := f32( w ) / f32( app.canvas.virt_w ), f32( h ) / f32( app.canvas.virt_h )
    src := mem.slice_ptr( pix, int( w * h * 3 ) )
    for y in 0 ..< app.canvas.virt_h {
        
        for x in 0 ..< app.canvas.virt_w {
            
            sx, sy := int( f32( x ) * scale_x ), int( f32( y ) * scale_y )
            if sx < int( w ) && sy < int( h ) {
                
                idx := ( sy * int( w ) + sx ) * 3
                c_idx := y * app.canvas.virt_w + x
                
                r := src[ idx ]
                g := src[ idx + 1 ]
                b := src[ idx + 2 ]
                
                if r == 0 && g == 0 && b == 0 {
                    
                    app.canvas.pixels[ c_idx ] = PixelState{ false, { 0,0,0 } }
                } else {
                   
                    app.canvas.pixels[ c_idx ] = PixelState{ true, { r, g, b } }
                }
            }
        }
    }
    
    app.status_msg = "Loaded."
}

prompt_input :: proc ( app         : ^AppState,
                       prompt_text : string ) ->
                       string {
    
    disable_raw_mode( )
    fmt.printf( "\x1b[%d;1H\x1b[K%s: ", app.canvas.term_h + 2, prompt_text )
    buf : [ 256 ]u8
    n, _ := os.read( os.stdin, buf[ : ] )
    enable_raw_mode( )
    if n > 0 {
        
        return strings.trim_space(string(buf[:n]))
    }
    return ""
}

handle_movement :: proc ( app  : ^AppState,
                          data : string ) {
    dx, dy := 0, 0
    if strings.contains( data, "A" ) || data == "w" || data == "8" {
       
       dy = -1
    }
    
    if strings.contains( data, "B" ) || data == "s" || data == "2" {
       
       dy = 1
    }
    
    if strings.contains( data, "C" ) || data == "d" || data == "6" {
       
        dx = 1
    }
    
    if strings.contains( data, "D" ) || data == "a" || data == "4" {
       
       dx = -1
    }
    
    if data == "7" || data == "\x1b[H" || data == "\x1bOH" || data == "\x1b[1~" {
       
       dx = -1
       dy = -1
    }
    
    if data == "9" || data == "\x1b[5~" { 
        
        dx = 1
        dy = -1
    }
    
    if data == "1" || data == "\x1b[F" || data == "\x1bOF" || data == "\x1b[4~" {
       
        dx = -1
        dy = 1
    }
    
    if data == "3" || data == "\x1b[6~" {
       
        dx = 1
        dy = 1
    }
    
    if dx != 0 || dy != 0 {
 
        app.cursor_x = clamp( app.cursor_x + dx, 0, app.canvas.virt_w - 1 )
        app.cursor_y = clamp( app.cursor_y + dy, 0, app.canvas.virt_h - 1 )
    }
}

parse_mouse :: proc ( app  : ^AppState,
                      data : string ) {
    
    parts := strings.split( data, ";" )
    if len( parts ) < 3 {
       
       return
    }
    defer delete( parts )
    btn_str := parts[ 0 ][ 3 : ]
    x_str   := parts[ 1 ]
    y_part  := parts[ 2 ] 
    y_end   := 0
    for k in 0 ..< len( y_part ) {
       
       if y_part[ k ] < '0' || y_part[ k ] > '9' {
          
          break
       }
       y_end += 1 
    }
    btn, _ := strconv.parse_int( btn_str )
    tx, _  := strconv.parse_int( x_str )
    ty, _  := strconv.parse_int( y_part[ : y_end ] )
    cx     := clamp( ( tx - 1 ) * 2, 0, app.canvas.virt_w - 1 )
    cy     := clamp( ( ty - 1 ) * 4, 0, app.canvas.virt_h - 1 )
    is_release := strings.has_suffix( data, "m" )
    is_right   := ( btn & 2 ) != 0
    is_drag    := ( btn & 32 ) != 0 || ( btn == 34 ) || ( btn == 66 ) 
    
    if is_release {
       
       app.mouse_down = false
       return
    }
    app.cursor_x = cx
    app.cursor_y = cy

    if ( app.tool_type == .Line ||
         app.tool_type == .Ellipse ||
         app.tool_type == .FilledEllipse ||
         app.tool_type == .Rect ||
         app.tool_type == .FilledRect) &&
         !is_drag {
        
        if !app.shape_start_set {
            
            app.shape_start_x   = cx
            app.shape_start_y   = cy
            app.shape_start_set = true
            app.status_msg      = "End Point/Corner?"
        } else {
            
            // Save before shape
            push_history( app )
            
            if app.tool_type == .Line {
                
               draw_line( app, app.shape_start_x, app.shape_start_y, cx, cy, is_right )
            
            } else if app.tool_type == .Ellipse {
                
                draw_ellipse( app, app.shape_start_x, app.shape_start_y, cx, cy, false, is_right )
            
            } else if app.tool_type == .FilledEllipse {
               
               draw_ellipse( app, app.shape_start_x, app.shape_start_y, cx, cy, true, is_right )
            
            } else if app.tool_type == .Rect {
               
                draw_rect( app, app.shape_start_x, app.shape_start_y, cx, cy, false, is_right )
            
            } else if app.tool_type == .FilledRect {
                
                draw_rect( app, app.shape_start_x, app.shape_start_y, cx, cy, true, is_right )
            }
            
            app.shape_start_set = false
            app.status_msg      = "Shape Drawn"
        }
    } else if app.tool_type == .Pen {
        
        if !app.mouse_down { // Start of stroke
            
            push_history( app ) 
        }
        if is_drag && app.mouse_down {
           
            draw_line( app, app.last_mouse_x, app.last_mouse_y, cx, cy, is_right )
        
        } else {
           
           paint_at( app, cx, cy, is_right )
        }
        
        app.last_mouse_x = cx
        app.last_mouse_y = cy
        app.mouse_down   = true
        
    } else if app.tool_type == .Text {
        
        // Click to move cursor only
        app.status_msg = "Cursor moved. Type to paint."
    }
}

clamp :: proc( v     : int,
               min_v : int,
               max_v : int ) -> 
               int {
            
    if v < min_v {
        
        return min_v
    }
    if v > max_v {
       
       return max_v
    }
    return v
}

//
// Main
// 

main :: proc ( ) {
    
    app := AppState{ running     = true,
                     brush_color = { 255, 255, 255 },
                     status_msg  = "Press 'h' for Help",
                     brush_size  = 0
                   }
   
    // The therm size is only obtained at the beggining of the program,
    // so we don't support terminal resiziing.
    w, h := get_term_size( )
    init_canvas( & app.canvas, w, h )
    enable_raw_mode( )
    defer disable_raw_mode()

    buf: [ 1024 ]u8
    for app.running {
        
        render( & app )
        n, err := os.read( os.stdin, buf[ : ] )
        if err != os.ERROR_NONE || n == 0 {
           
           continue
        }
        data := string( buf[ : n ] )

        // Mouse
        if strings.contains( data, "\x1b[M" ) || strings.contains( data, "\x1b[<" ) {
            
            parse_mouse( & app, data )
            continue
        }

        // Text Tool
        if app.tool_type == .Text {
            
            if data == "\x1b" {
               
               app.tool_type = .Pen
               app.status_msg = "Pen Tool"
            } else if len( data ) == 1 {
                
                ch := data[ 0 ]
                if ch >= 32 && ch <= 126 {
                    
                    push_history( & app )
                    draw_char( & app, ch )
                } else if ch == 127 || ch == 8 { // Backspace ( DEL or BS )
                    
                    if app.cursor_x >= 6 {
                        
                        push_history( & app )
                        app.cursor_x -= 6
                        
                        // Erase 5x7 block
                        for col in 0 ..< 5 {
                            
                            for row in 0 ..< 7 {
                                
                                set_pixel_raw( & app.canvas,
                                               app.cursor_x + col, app.cursor_y + row,
                                               { 0,0,0 },
                                               true )
                            }
                        }
                    }
                }
            }
            
            // Only allow escape sequences ( arrows ) to move cursor in Text Mode
            if strings.has_prefix( data, "\x1b" ) {
                
                handle_movement( & app, data )
            }
            
            continue
        }

        // Global Shortcuts
        if data == "\x1a" {  // Ctrl + Z
            
            perform_undo( & app ) 
        
        } else if data == "\x19" { // Ctrl + Y
           
            perform_redo( & app ) 
        
        } else if data == "q" {
            
            app.running = false
        
        } else if data == "h" { 
            
            app.show_help = !app.show_help
        
        } else if data == "c" {
            
             push_history( & app )
             
             for i in 0 ..< len( app.canvas.pixels ) {
                
                 app.canvas.pixels[i].active = false
             }
             
             app.status_msg = "Cleared"
        
        } else if data == "s" {
            
            f := prompt_input( & app, "Save (.ppm/.bmp)")
            if len( f ) > 0 {
               
               save_image( & app, f )
            }
        
        } else if data == "l" {
           
            f := prompt_input( & app, "Load" )
            if len( f ) > 0 {
                
                load_image( & app, f )
            }
        
        } else if data == " " {
           
           push_history( & app )
           paint_at( & app, app.cursor_x, app.cursor_y, false )
        
        } else if data == "v" {
          
            app.tool_type        = app.tool_type == .Line ? .Pen : .Line
            app.shape_start_set = false
            app.status_msg      = app.tool_type == .Line ? "Line Tool" : "Pen Tool"
        
        } else if data == "o" {
            
            app.tool_type       = app.tool_type == .Ellipse ? .Pen : .Ellipse
            app.shape_start_set = false
            app.status_msg      = app.tool_type == .Ellipse ? "Ellipse Tool" : "Pen Tool"
        
        } else if data == "e" {
            
            app.tool_type       = app.tool_type == .FilledEllipse ? .Pen : .FilledEllipse
            app.shape_start_set = false
            app.status_msg      = app.tool_type == .FilledEllipse ? "Filled Ellipse Tool" : "Pen Tool"
        
        } else if data == "x" {
            
            app.tool_type       = app.tool_type == .Rect ? .Pen : .Rect
            app.shape_start_set = false
            app.status_msg      = app.tool_type == .Rect ? "Rect Tool" : "Pen Tool"
        
        } else if data == "f" {
            
            app.tool_type       = app.tool_type == .FilledRect ? .Pen : .FilledRect
            app.shape_start_set = false
            app.status_msg      = app.tool_type == .FilledRect ? "Filled Rect Tool" : "Pen Tool"
        
        } else if data == "t" {
            
            app.tool_type  = app.tool_type == .Text ? .Pen : .Text
            app.status_msg = app.tool_type == .Text ? "Text Tool: Type chars" : "Pen Tool"
        
        } else if data == "n" {
            
            cycle_color( & app )
        
        } else if data == "r" {
           
           app.brush_color = { 255, 0, 0 }
        
        } else if data == "g" {
            
            app.brush_color = { 0, 255, 0 }
        
        } else if data == "b" {
            
            app.brush_color = { 0, 0, 255 }
        
        } else if data == "w" { 
            
            app.brush_color = { 255, 255, 255 }
        
        } else if data == "]" {
           
           app.brush_size = min( app.brush_size + 1, 10 )
        
        } else if data == "[" { 
            
            app.brush_size = max( app.brush_size - 1, 0 )
        
        }
        
        handle_movement( & app, data )
    }
}
