module cabi.formatter;

import std.experimental.allocator : dispose, make;
import cabi.allocator : CAllocator, from, VelocittyAllocator;
import cabi.common : VelocittyResult;
import cabi.terminal : VelocittyTerminal;

struct VelocittyFormatterImpl
{
    CAllocator alloc;
    VelocittyTerminal terminal;
}

extern (C) alias VelocittyFormatter = VelocittyFormatterImpl*;

extern (C):

VelocittyResult velocitty_formatter_terminal_new(const(VelocittyAllocator)* allocator, VelocittyFormatter* result, VelocittyTerminal terminal)
{
    if (result is null || terminal is null)
        return VelocittyResult.invalidValue;

    auto alloc = from(allocator);
    auto f = alloc.make!VelocittyFormatterImpl;
    if (f is null)
        return VelocittyResult.outOfMemory;

    f.alloc = alloc;
    f.terminal = terminal;
    *result = f;
    return VelocittyResult.success;
}

VelocittyResult velocitty_formatter_format_alloc(VelocittyFormatter f, const(VelocittyAllocator)* allocator, ubyte** buf, size_t* len)
{
    if (f is null || buf is null || len is null)
        return VelocittyResult.invalidValue;

    const n = f.terminal.term.formatPlain(null);
    *buf = null;
    *len = 0;
    if (n == 0)
        return VelocittyResult.success;

    auto mem = cast(char[]) from(allocator).allocate(n);
    if (mem is null)
        return VelocittyResult.outOfMemory;

    f.terminal.term.formatPlain(mem);
    *buf = cast(ubyte*) mem.ptr;
    *len = n;
    return VelocittyResult.success;
}

void velocitty_formatter_free(VelocittyFormatter f)
{
    if (f is null)
        return;

    auto alloc = f.alloc;
    alloc.dispose(f);
}