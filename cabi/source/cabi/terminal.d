module cabi.terminal;

import std.experimental.allocator : dispose, make;
import cabi.allocator : CAllocator, from, VelocittyAllocator;
import cabi.common : VelocittyResult;
import terminal : Terminal;

struct VelocittyTerminalImpl {
    CAllocator alloc;
    Terminal term;
}

extern (C) alias VelocittyTerminal = VelocittyTerminalImpl*;

extern (C):

VelocittyResult velocitty_terminal_new(const(VelocittyAllocator)* allocator, VelocittyTerminal* result, ushort cols, ushort rows) {
    if (result is null || cols == 0 || rows == 0)
        return VelocittyResult.invalidValue;

    auto alloc = from(allocator);
    auto t = alloc.make!VelocittyTerminalImpl;
    if (t is null)
        return VelocittyResult.outOfMemory;

    t.alloc = alloc;
    if (!t.term.initialize(t.alloc, cols, rows)) {
        alloc.dispose(t);
        return VelocittyResult.outOfMemory;
    }

    *result = t;
    return VelocittyResult.success;
}

void velocitty_terminal_free(VelocittyTerminal t) {
    if (t is null)
        return;

    auto alloc = t.alloc;
    t.term.release(alloc);
    alloc.dispose(t);
}

void velocitty_terminal_vt_write(VelocittyTerminal t, const(ubyte)* data, size_t len) {
    t.term.feed(data[0 .. len]);
}

VelocittyResult velocitty_terminal_resize(VelocittyTerminal t, ushort cols, ushort rows) {
    if (cols == 0 || rows == 0)
        return VelocittyResult.invalidValue;

    return t.term.resize(t.alloc, cols, rows) ? VelocittyResult.success : VelocittyResult.outOfMemory;
}

void velocitty_terminal_get_size(VelocittyTerminal t, ushort* cols, ushort* rows) {
    *cols = t.term.cols;
    *rows = t.term.rows;
}

void velocitty_terminal_get_cursor(VelocittyTerminal t, ushort* x, ushort* y) {
    *x = t.term.cursorX;
    *y = t.term.cursorY;
}

VelocittyResult velocitty_terminal_get_codepoint(VelocittyTerminal t, ushort x, ushort y, uint* codepoint) {
    if (x >= t.term.cols || y >= t.term.rows)
        return VelocittyResult.invalidValue;

    *codepoint = t.term.cell(x, y).codepoint;
    return VelocittyResult.success;
}